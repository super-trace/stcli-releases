"""Run on macOS and Linux; a local HTTP server stands in for GitHub."""
import hashlib
import http.server
import io
import json
import os
from pathlib import Path
import subprocess
import tarfile
import tempfile
import threading

installer = Path(__file__).resolve().parent.parent / 'install.sh'
repo = 'super-trace/stcli-releases'
with tempfile.TemporaryDirectory(prefix='stcli-install-') as directory:
    root = Path(directory)
    site = root / 'site'
    assets = site / repo / 'releases' / 'download' / 'vtest'
    api = site / 'repos' / repo / 'releases'
    assets.mkdir(parents=True)
    api.mkdir(parents=True)
    (api / 'latest').write_text(json.dumps({'tag_name': 'vtest'}))
    system = subprocess.check_output(['uname', '-s'], text=True).strip()
    machine = subprocess.check_output(['uname', '-m'], text=True).strip()
    target = 'darwin_universal' if system == 'Darwin' else 'linux_' + ('arm64' if machine in ['arm64', 'aarch64'] else 'amd64')
    archive = assets / f'stcli_test_{target}.tar.gz'
    with tarfile.open(archive, 'w:gz') as bundle:
        data = b'#!/bin/sh\necho installer-fixture\n'
        info = tarfile.TarInfo('stcli')
        info.size, info.mode = len(data), 0o755
        bundle.addfile(info, io.BytesIO(data))
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
    env = dict(os.environ, HOME=str(home), SHELL='/bin/zsh', GITHUB_API_URL=url, GITHUB_SERVER_URL=url,
               STCLI_INSTALL_DIR=str(bin_dir), PATH='/usr/bin:/bin')
    for _ in range(2): subprocess.run(['sh', str(installer)], env=env, check=True)
    executable = bin_dir / 'stcli'
    assert subprocess.check_output([str(executable)], text=True).strip() == 'installer-fixture'
    profile = (home / '.zshrc').read_text()
    assert profile.count(f'export PATH="{bin_dir}:$PATH"') == 1
    before = executable.read_bytes()
    archive.write_bytes(b'corrupt')
    rejected = subprocess.run(['sh', str(installer)], env=env, capture_output=True, text=True)
    assert rejected.returncode and 'checksum verification failed' in rejected.stderr
    assert executable.read_bytes() == before
    server.shutdown()
    print('Install, reinstall, spaces, executable mode, PATH setup, and checksum rejection passed')
