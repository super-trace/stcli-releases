"""Runs install.sh on macOS and Linux, install.ps1 on Windows; a local HTTP server stands in for GitHub."""
import hashlib
import http.server
import io
import json
import os
from pathlib import Path
import platform
import re
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


def write_fixture(archive):
    if windows:
        with zipfile.ZipFile(archive, 'w') as bundle:
            bundle.writestr('stcli.exe', payload)
    else:
        with tarfile.open(archive, 'w:gz') as bundle:
            info = tarfile.TarInfo('stcli')
            info.size, info.mode = len(payload), 0o755
            bundle.addfile(info, io.BytesIO(payload))
    (archive.parent / 'checksums.txt').write_text(f'{hashlib.sha256(archive.read_bytes()).hexdigest()}  {archive.name}\n')


def user_path():
    out = subprocess.run(['reg', 'query', r'HKCU\Environment', '/v', 'Path'], capture_output=True, text=True).stdout
    match = re.search(r'^\s*Path\s+(REG_\w+)\s+(.*?)\s*$', out, re.MULTILINE | re.IGNORECASE)
    return match.groups() if match else None


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
    write_fixture(archive)

    fail_archive = [0]  # how many archive requests answer 503 before succeeding

    class Handler(http.server.SimpleHTTPRequestHandler):
        def __init__(self, *args): super().__init__(*args, directory=str(site))
        def log_message(self, *args): pass
        def do_GET(self):
            if fail_archive[0] and self.path.endswith(archive.name):
                fail_archive[0] -= 1
                self.send_error(503)
                return
            super().do_GET()
    server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    url = f'http://127.0.0.1:{server.server_port}'

    home = root / 'home'
    home.mkdir()
    bin_dir = root / 'bin with spaces'
    env = dict(os.environ, HOME=str(home), SHELL='/bin/zsh', GITHUB_API_URL=url, GITHUB_SERVER_URL=url, STCLI_INSTALL_DIR=str(bin_dir))
    if windows:
        # A PowerShell 7 parent hides Windows PowerShell's own modules (Get-FileHash, Expand-Archive).
        env5 = dict(env, PSModulePath=os.path.expandvars(r'%ProgramFiles%\WindowsPowerShell\Modules;%SystemRoot%\System32\WindowsPowerShell\v1.0\Modules'))
        shells = [([s, '-NoProfile', '-File', str(root_dir / 'install.ps1')], env5 if s == 'powershell' else env)
                  for s in ['powershell', 'pwsh'] if shutil.which(s)]
        assert shells, 'no PowerShell found'
        original = user_path()
    else:
        env['PATH'] = '/usr/bin:/bin'
        shells = [(['sh', str(root_dir / 'install.sh')], env)]
    try:
        for shell, env in shells:
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
            write_fixture(archive)
            if not windows:
                # A transient failure on the binary download is retried, not fatal.
                fail_archive[0] = 1
                retried = subprocess.run(shell, env=env, capture_output=True, text=True)
                assert retried.returncode == 0 and fail_archive[0] == 0, retried
            executable.unlink()
            if not windows:
                fish = dict(env, SHELL='/usr/bin/fish', STCLI_VERSION='test')
                (api / 'latest').unlink()
                subprocess.run(shell, env=fish, check=True)
                assert (home / '.config/fish/config.fish').read_text().count(f'set -gx PATH "{bin_dir}" $PATH') == 1
    finally:
        if windows and original: restore_user_path(*original)
    server.shutdown()
    print(f'{len(shells)} shell(s): install, reinstall, spaces, PATH setup, checksum rejection, download retry, and pinned version passed')
