# Install options

The one-line installers in the [README](../README.md) install the latest
release. This page covers everything else.

## Pin a version or directory

```sh
STCLI_VERSION=2026.11.05 sh -c "$(curl -fsSL https://raw.githubusercontent.com/super-trace/stcli-releases/main/install.sh)"
STCLI_INSTALL_DIR="$HOME/bin" sh -c "$(curl -fsSL https://raw.githubusercontent.com/super-trace/stcli-releases/main/install.sh)"
```

```powershell
$env:STCLI_VERSION = "2026.11.05"; irm https://raw.githubusercontent.com/super-trace/stcli-releases/main/install.ps1 | iex
```

The PowerShell pin stays set for the session; `Remove-Item Env:STCLI_VERSION`
before running the installer again for the latest release.

The pin applies to that installation only: auto-update replaces it on a later
launch unless turned off, see below.

Versions are accepted with or without the leading `v`. Set `GITHUB_TOKEN` to
raise the GitHub API rate limit, for example in CI.

## Auto-update

On launch stcli checks for a newer release, installs it in the background, and
the next launch runs it. `stcli version` names an update waiting for a restart.

| Switch | Effect |
| --- | --- |
| `STCLI_NO_AUTO_UPDATE=1` | No background updates for that run. |
| `"auto_update": false` in `config.json` | No background updates. |
| `stcli update` | Install the latest release now, regardless of the above. |

Both apply only to installs under `~/.stcli/bin`. A binary anywhere else never
updates itself; a Homebrew install upgrades with `brew upgrade stcli`. Auto-update shipped in v2026.11.06; a v2026.11.05 install
re-runs the installer once to pick it up.

## Manual install

Download the archive for your platform and `checksums.txt` from the releases
page, verify, extract, and put `stcli` on your `PATH`:

```sh
grep stcli_2026.11.06_linux_amd64.tar.gz checksums.txt | shasum -a 256 -c &&
  tar -xzf stcli_2026.11.06_linux_amd64.tar.gz
```

```powershell
$expected = (Select-String stcli_2026.11.06_windows_amd64.zip checksums.txt).Line.Split(" ")[0]
if ((Get-FileHash stcli_2026.11.06_windows_amd64.zip).Hash -ieq $expected) {
  Expand-Archive stcli_2026.11.06_windows_amd64.zip -DestinationPath "$env:USERPROFILE\.stcli\bin"
}
```

| Package | Contents |
| --- | --- |
| `stcli_<version>_darwin_universal.tar.gz` | Intel + Apple Silicon executable |
| `stcli_<version>_linux_amd64.tar.gz` | Linux/WSL x86-64 executable |
| `stcli_<version>_linux_arm64.tar.gz` | Linux/WSL ARM64 executable |
| `stcli_<version>_windows_amd64.zip` | Windows x86-64 `stcli.exe` |
| `stcli_<version>_windows_arm64.zip` | Windows ARM64 `stcli.exe` |

`provenance.json` records the source commit and toolchain of every package.
