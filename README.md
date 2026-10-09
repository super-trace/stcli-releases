# Install stcli

Prebuilt stcli packages for macOS, Linux, and WSL. No Go installation or GitHub
login required.

## Install

Run in your macOS, Linux, or WSL terminal:

```sh
curl -fsSL https://raw.githubusercontent.com/super-trace/stcli-releases/main/install.sh | bash
```

macOS uses one universal executable for Intel and Apple Silicon. Linux and WSL
support x86-64 and ARM64. Native Windows packages are paused; use WSL for now.

Installs the latest release to `~/.local/bin/stcli`, without sudo. The installer
prints PATH instructions if needed; it does not edit shell configuration.
Re-run the command to upgrade.

To choose a version or installation directory:

```sh
curl -fsSL https://raw.githubusercontent.com/super-trace/stcli-releases/main/install.sh -o /tmp/stcli-install.sh
STCLI_VERSION=2026.10.09 bash /tmp/stcli-install.sh
# Optional: STCLI_INSTALL_DIR="$HOME/bin" bash /tmp/stcli-install.sh
```

## Login and connect

```sh
stcli login
stcli user@device
```

Use a terminal with SSH access to your device. Login opens a browser; Linux uses
`xdg-open`, and WSL needs a browser bridge. Headless authentication is not
implemented yet.

## Releases and verification

CI builds three packages: macOS universal and Linux amd64/arm64. Verified
archives, `checksums.txt`, and `provenance.json` are uploaded to a draft release,
then published once every upload succeeds.

Versions use the UTC date: `vYYYY.MM.DD`, with `.2`, `.3`, etc. for additional
releases that day. Installers accept the version without `v`. Build provenance
records the commit and toolchain. The Homebrew formula is maintained separately.

The installer checks the archive's SHA-256 before replacing an installation.
Checksums detect corrupt downloads; they are not independent publisher
signatures. macOS executables are ad-hoc signed, not Developer ID signed or
notarized.

For offline installation, download the matching archive and `checksums.txt`
from [Releases](https://github.com/super-trace/stcli-releases/releases) into one
directory, then run:

```sh
STCLI_ASSET_DIR=/path/to/packages STCLI_VERSION=2026.10.09 bash /tmp/stcli-install.sh
```

## Uninstall

```sh
rm "$HOME/.local/bin/stcli"
```

If you selected a different installation directory, remove `stcli` there instead.
Credentials and SSH configuration are kept separately and are not removed.
