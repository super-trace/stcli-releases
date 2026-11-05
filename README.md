# Install stcli

Prebuilt stcli packages for macOS, Linux, WSL, and Windows. No Go installation
or GitHub login required.

> **Public launch:** This repository and `super-trace/ac6-workshop-lab` will both
> become public. These installation instructions are written for that public state;
> anonymous downloads will work once visibility changes. At launch, update both
> READMEs, replace the workshop's authenticated `gh api` installer download with
> the public `curl` command below, remove private-repository access requirements,
> and test installation without GitHub login.

## Install

Run in your macOS, Linux, or WSL terminal:

```sh
curl -fsSL https://raw.githubusercontent.com/super-trace/stcli-releases/main/install.sh | sh
```

Or in PowerShell on Windows:

```powershell
irm https://raw.githubusercontent.com/super-trace/stcli-releases/main/install.ps1 | iex
```

macOS uses one universal executable for Intel and Apple Silicon. Linux, WSL, and
Windows support x86-64 and ARM64.

Installs the latest release to `~/.stcli/bin/stcli` (`%USERPROFILE%\.stcli\bin\stcli.exe`
on Windows), without administrator rights, and adds that directory to `PATH` in
your shell profile or user environment if it is not already there. Re-run the
command to upgrade, and check what you have with `stcli version`, which prints
the release version and the source commit, for example `2026.11.04 (c5ddc1f)`.

To choose a version or installation directory:

```sh
STCLI_VERSION=2026.10.09 sh -c "$(curl -fsSL https://raw.githubusercontent.com/super-trace/stcli-releases/main/install.sh)"
STCLI_INSTALL_DIR="$HOME/bin" sh -c "$(curl -fsSL https://raw.githubusercontent.com/super-trace/stcli-releases/main/install.sh)"
```

```powershell
$env:STCLI_VERSION = "2026.10.09"; irm https://raw.githubusercontent.com/super-trace/stcli-releases/main/install.ps1 | iex
```

Set `GITHUB_TOKEN` to raise the GitHub API rate limit, for example in CI.

## Login and connect

```sh
stcli login
stcli user@device
```

Use a terminal with SSH access to your device. Login opens a browser; Linux uses
`xdg-open`, and WSL needs a browser bridge. Headless authentication is not
implemented yet.

## Releases and verification

A maintainer cuts a release from the Release workflow in
[stcli](https://github.com/super-trace/stcli). It builds five packages, macOS
universal, Linux amd64/arm64, and Windows amd64/arm64, with the version stamped
into every executable. Verified archives, `checksums.txt`, and `provenance.json`
are uploaded to a draft release here, published once every upload succeeds, and
the built commit is tagged in stcli with the same version.

Versions use the UTC date: `vYYYY.MM.DD`, with `.2`, `.3`, etc. for additional
releases that day; the workflow picks the next free one. Installers accept the
version without `v`. Build provenance records the commit and toolchain. The
Homebrew formula is maintained separately.

The installer checks the archive's SHA-256 before replacing an installation.
Checksums detect corrupt downloads; they are not independent publisher
signatures. macOS executables are ad-hoc signed, not Developer ID signed or
notarized; Windows executables are unsigned, so SmartScreen may warn on first run.

## Uninstall

```sh
rm "$HOME/.stcli/bin/stcli"
```

```powershell
Remove-Item "$env:USERPROFILE\.stcli\bin\stcli.exe"
```

If you selected a different installation directory, remove `stcli` there instead,
and drop the `PATH` entry the installer added to your shell profile or user
environment. Credentials and SSH configuration are kept separately and are not
removed.
