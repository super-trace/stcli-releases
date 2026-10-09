# Install stcli

Prebuilt stcli packages and installers. Source is maintained separately; no Go
installation is required. This repository is currently private.

## macOS, Linux, and WSL

macOS packages include Intel and Apple Silicon in one universal executable.
Linux and WSL packages support x86-64 and ARM64. WSL uses this shell installer,
not the Windows executable.

While this repository is private, authenticate with `gh auth login`, then:

```sh
gh api repos/super-trace/stcli-releases/contents/install.sh \
  --jq .content | base64 --decode > /tmp/stcli-install.sh
bash /tmp/stcli-install.sh
```

To install a specific date version:

```sh
STCLI_VERSION=2026.10.09 bash /tmp/stcli-install.sh
```

Installs to `~/.local/bin/stcli`, without sudo. If needed, the installer prints
PATH instructions; it does not edit shell configuration. Set `STCLI_INSTALL_DIR`
to choose another directory. Re-run to upgrade or select another version.

Once this repository and release assets become public, anonymous installation
will work with:

```sh
curl -fsSL https://raw.githubusercontent.com/super-trace/stcli-releases/main/install.sh | bash
```

That anonymous command does not work while the repository is private.

## Native Windows PowerShell

Supports Windows PowerShell 5.1 and PowerShell 7, x86-64 and ARM64. Authenticate
with `gh auth login` while this repository is private:

```powershell
gh api repos/super-trace/stcli-releases/contents/install.ps1 --jq .content |
  ForEach-Object { [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($_)) } |
  Set-Content -Encoding UTF8 "$env:TEMP\stcli-install.ps1"
& "$env:TEMP\stcli-install.ps1"
```

Installs under `%LOCALAPPDATA%\Supertrace\stcli\bin` and adds that directory to
your user and current-terminal PATH. No administrator privileges needed.
Use `-InstallDirectory` to choose another directory, or `-NoPathUpdate` to
manage PATH yourself.

Once public, download the script with:

```powershell
Invoke-WebRequest -UseBasicParsing https://raw.githubusercontent.com/super-trace/stcli-releases/main/install.ps1 -OutFile "$env:TEMP\stcli-install.ps1"
& "$env:TEMP\stcli-install.ps1"
```

## How releases work

This repository contains installers and downloadable release assets. CI builds
five packages: macOS universal, Linux amd64/arm64, and Windows amd64/arm64.
After verification, the archives, `checksums.txt`, and `provenance.json` are
uploaded to a draft release, which is published once every upload succeeds.

Versions use the UTC date: `vYYYY.MM.DD`, with `.2`, `.3`, etc. for additional
releases that day. Installers accept the version without `v` and select the
latest published release by default. Published assets are immutable; a changed
build gets a new version. `provenance.json` records the build's commit and toolchain.
The Homebrew formula is maintained separately.

## Login and connect

```sh
stcli login
stcli user@device
```

Use a terminal with SSH access to your device. Browser-based login requires a
working browser opener; Linux uses `xdg-open`, and WSL needs a browser bridge.
Headless authentication is not implemented yet.

## Verification and offline installation

Installers verify the downloaded archive's SHA-256 against `checksums.txt`
before replacing an existing installation. Hashes detect corrupt downloads;
they are not independent publisher signatures. macOS executables are ad-hoc
signed, not Developer ID signed or notarized. Windows executables are not
Authenticode-signed.

For offline installation, place the matching release archive and `checksums.txt`
in a directory. Set `STCLI_ASSET_DIR` and `STCLI_VERSION` for the shell script,
or pass `-AssetDirectory` and `-Version` to the PowerShell script.

Remove only the installed executable to uninstall. On Windows, also remove the
installation directory from your user PATH if the installer added it.
Credentials and SSH configuration are kept separately and are not removed.

Homebrew installation uses a separate tap; its formula must be updated for each release.
