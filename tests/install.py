"""Run on macOS and Linux; fixture downloads exercise the authenticated path."""
import hashlib
import io
import os
from pathlib import Path
import subprocess
import tarfile
import tempfile

installer = Path(__file__).resolve().parent.parent / 'install.sh'
with tempfile.TemporaryDirectory(prefix='stcli-install-') as directory:
    root = Path(directory)
    assets = root / 'assets'
    assets.mkdir()
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
    env = dict(os.environ, STCLI_VERSION='test', STCLI_ASSET_DIR=str(assets), STCLI_INSTALL_DIR=str(root / 'bin with spaces'))
    for _ in range(2): subprocess.run(['bash', str(installer)], env=env, check=True)
    executable = root / 'bin with spaces' / 'stcli'
    assert subprocess.check_output([str(executable)], text=True).strip() == 'installer-fixture'
    before = executable.read_bytes()
    archive.write_bytes(b'corrupt')
    rejected = subprocess.run(['bash', str(installer)], env=env, capture_output=True, text=True)
    assert rejected.returncode and 'Checksum mismatch' in rejected.stderr
    assert executable.read_bytes() == before
    print('Install, reinstall, spaces, executable mode, and checksum rejection passed')
