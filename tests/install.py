"""Runs install.sh on macOS and Linux, install.ps1 on Windows; a local HTTP server stands in for GitHub."""
import hashlib
import http.server
import io
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import tarfile
import tempfile
import threading
import zipfile

root_dir = Path(__file__).resolve().parent.parent
repo = 'super-trace/stcli-releases'
windows = platform.system() == 'Windows'
payload = b'installer-fixture' if windows else b'#!/bin/sh\necho installer-fixture\n'


def fixture_target():
    if windows:
        return 'windows_' + ('arm64' if platform.machine().upper() == 'ARM64' else 'amd64')
    system = subprocess.check_output(['uname', '-s'], text=True).strip()
    machine = subprocess.check_output(['uname', '-m'], text=True).strip()
    return 'darwin_universal' if system == 'Darwin' else 'linux_' + ('arm64' if machine in ['arm64', 'aarch64'] else 'amd64')


def write_archive(archive):
    if windows:
        with zipfile.ZipFile(archive, 'w') as bundle:
            bundle.writestr('stcli.exe', payload)
        return
    with tarfile.open(archive, 'w:gz') as bundle:
        info = tarfile.TarInfo('stcli')
        info.size, info.mode = len(payload), 0o755
        bundle.addfile(info, io.BytesIO(payload))


def user_path():
    out = subprocess.check_output(['reg', 'query', r'HKCU\Environment', '/v', 'Path'], text=True)
    _, kind, value = out.split()[-3:] if 'REG_' in out else (None, 'REG_EXPAND_SZ', '')
    return kind, value


def restore_user_path(kind, value):
    subprocess.run(['reg', 'add', r'HKCU\Environment', '/v', 'Path', '/t', kind, '/d', value, '/f'], check=True, capture_output=True)


with tempfile.TemporaryDirectory(prefix='stcli-install-') as directory:
    root = Path(directory)
    site = root / 'site'
    assets = site / repo / 'releases' / 'download' / 'vtest'
    api = site / 'repos' / repo / 'releases'
    assets.mkdir(parents=True)
    api.mkdir(parents=True)
    (api / 'latest').write_text(json.dumps({'tag_name': 'vtest'}))
    archive = assets / f"stcli_test_{fixture_target()}.{'zip' if windows else 'tar.gz'}"
    write_archive(archive)
    (assets / 'checksums.txt').write_text(f'{hashlib.sha256(archive.read_bytes()).hexdigest()}  {archive.name}\n')

    class Handler(http.server.SimpleHTTPRequestHandler):
        def __init__(self, *args): super().__init__(*args, directory=str(site))
        def log_message(self, *args): pass
    server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    url = f'http://127.0.0.1:{server.server_port}'

    home = root / 'home'
    home.mkdir()
    bin_dir = root / 'bin with spaces'
    env = dict(os.environ, HOME=str(home), SHELL='/bin/zsh', GITHUB_API_URL=url, GITHUB_SERVER_URL=url, STCLI_INSTALL_DIR=str(bin_dir))
    if windows:
        shells = [[s, '-NoProfile', '-File', str(root_dir / 'install.ps1')] for s in ['powershell', 'pwsh'] if shutil.which(s)]
        assert shells, 'no PowerShell found'
        original = user_path()
    else:
        env['PATH'] = '/usr/bin:/bin'
        shells = [['sh', str(root_dir / 'install.sh')]]
    try:
        for shell in shells:
            for _ in range(2): subprocess.run(shell, env=env, check=True)
            executable = bin_dir / ('stcli.exe' if windows else 'stcli')
            if windows:
                assert executable.read_bytes() == payload
                assert user_path()[1].split(';').count(str(bin_dir)) == 1
            else:
                assert subprocess.check_output([str(executable)], text=True).strip() == 'installer-fixture'
                assert (home / '.zshrc').read_text().count(f'export PATH="{bin_dir}:$PATH"') == 1
            before = executable.read_bytes()
            archive.write_bytes(b'corrupt')
            rejected = subprocess.run(shell, env=env, capture_output=True, text=True)
            assert rejected.returncode and 'hecksum verification failed' in rejected.stdout + rejected.stderr, rejected
            assert executable.read_bytes() == before
            write_archive(archive)
            executable.unlink()
    finally:
        if windows: restore_user_path(*original)
    server.shutdown()
    print(f'{len(shells)} shell(s): install, reinstall, spaces, PATH setup, and checksum rejection passed')
