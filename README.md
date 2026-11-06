# stcli

stcli is a terminal UI that SSHes into network equipment and operates it in
natural language. You describe intent, "why is BGP down on this router?", "turn
up ge-0/0/2", a backend agent turns it into commands for the connected
platform, and stcli runs them over your own SSH session behind a human approval
gate. Device credentials never leave your machine.

This repository holds the prebuilt packages and installers for macOS, Linux,
WSL, and Windows. No Go installation or GitHub login required.

> **Public launch:** This repository and `super-trace/ac6-workshop-lab` will both
> become public. These installation instructions are written for that public state;
> anonymous downloads will work once visibility changes. At launch, update both
> READMEs, replace the workshop's authenticated `gh api` installer download with
> the public `curl` command below, remove private-repository access requirements,
> and test installation without GitHub login.

## Install

macOS, Linux, or WSL:

```sh
curl -fsSL https://raw.githubusercontent.com/super-trace/stcli-releases/main/install.sh | sh
```

Windows, in PowerShell:

```powershell
irm https://raw.githubusercontent.com/super-trace/stcli-releases/main/install.ps1 | iex
```

The installer puts the latest release at `~/.stcli/bin/stcli`
(`%USERPROFILE%\.stcli\bin\stcli.exe` on Windows), needs no administrator
rights, and adds that directory to `PATH`. Re-run it to upgrade. `stcli version`
prints the release version and source commit, for example `2026.11.04 (c5ddc1f)`.

stcli also updates itself: on launch it checks for a newer release, installs it
in the background, and the next launch runs it. Set `STCLI_NO_AUTO_UPDATE=1`, or
`"auto_update": false` in `config.json`, to turn that off; `stcli update`
installs the latest release on demand.

To choose a version or installation directory:

```sh
STCLI_VERSION=2026.10.09 sh -c "$(curl -fsSL https://raw.githubusercontent.com/super-trace/stcli-releases/main/install.sh)"
STCLI_INSTALL_DIR="$HOME/bin" sh -c "$(curl -fsSL https://raw.githubusercontent.com/super-trace/stcli-releases/main/install.sh)"
```

```powershell
$env:STCLI_VERSION = "2026.10.09"; irm https://raw.githubusercontent.com/super-trace/stcli-releases/main/install.ps1 | iex
```

Set `GITHUB_TOKEN` to raise the GitHub API rate limit, for example in CI.

## First run

```sh
stcli                 # sign in, open the TUI with no device
stcli admin@10.0.0.1  # sign in, then SSH to the device
```

The first launch prints a sign-in URL, offers to open a browser, and polls
until you confirm. Over SSH or on a headless machine, paste the URL into any
browser. stcli authenticates to devices the way `ssh` would: ssh-agent,
`~/.ssh` keys, keyboard-interactive, or a password prompt. Passwords are never
stored.

Then type what you want:

```
why is bgp down on this router?
show me the interfaces with errors
turn up ge-0/0/2
```

With no device connected, name one ("connect to admin@10.0.0.1") and the agent
asks to connect.

## Usage

```
stcli [options] [target ...]
stcli login | logout | version | update
```

| Target | Description |
| --- | --- |
| `user@host[:port]` | SSH. `host` can be an alias from `~/.ssh/config`. |
| `k8s://namespace/pod` | A shell inside a pod through the Kubernetes API. Options: `?context=`, `?container=`, `?shell=`. |

Each target opens its own tab. With none, the TUI opens one unbound tab.

| Command / flag | Description |
| --- | --- |
| `login` / `logout` | Sign in through the browser; revoke and clear the local store. |
| `version` | Release version, git sha, and any update waiting for a restart. |
| `update` | Install the latest release now. |
| `--resume [ID]` | Resume a session by id or unique prefix, or pick from a list, and reconnect to its device. Takes no target. |
| `--backend URL` | Backend base URL. Default `https://cli.supertrace.ai`. |
| `--theme NAME` | `auto`, `dark`, `light` or `mono`. |
| `--debug` | Error detail in the TUI, plus `stcli-debug.log` in the working directory. |

| Variable | Description |
| --- | --- |
| `STCLI_TOKEN` | Bearer token instead of the credential store. CI and lab backends. |
| `STCLI_DEBUG` / `STCLI_THEME` | Same as the flags. `NO_COLOR` is honoured too. |
| `STCLI_NO_AUTO_UPDATE` | Set to anything to stop background updates. |
| `STCLI_SSH_PASSWORD` | Answer SSH password prompts with this value. Lab use only. |
| `STCLI_SKIP_SSH_CONFIG` | Set to anything to ignore `~/.ssh/config`. |

## Inside the TUI

| Command | Description |
| --- | --- |
| `/connect [target]`, `/c` | Redial this tab, or pick which session a new target joins. |
| `/add <target>` | Add a device to this session. Up to 8 per session. |
| `/new [target]`, `/n` | Start a fresh session, or open a new tab on target. |
| `/disconnect [label]` | Close one device. |
| `/sessions [--new] <n\|id>` | List past sessions; resume one here or in a new tab. |
| `/switch [n\|device]`, `/s` | Pick a tab, or jump to one. |
| `/close`, `/quit` | Close this tab; leave. |
| `/usage`, `/help` | Token and command accounting; commands and keys. |

`!show interfaces terse` runs the rest of the line verbatim on the device, with
no agent turn. With several devices, name one: `!edge1 show bgp summary`. The
command and its output join the transcript, so the agent sees what you did.

| Key | Action |
| --- | --- |
| `enter` | Send. During a turn, queue the message for when it ends. |
| `alt+enter` | Newline. |
| `ctrl+enter` | Interrupt the running turn and send now. |
| `esc` | Interrupt the turn; cancel a dialog. |
| `ctrl+up` / `ctrl+down`, `ctrl+e` | Select a command block; expand or collapse it. |
| `ctrl+left` / `ctrl+right`, `alt+1..9` | Switch tab; jump to tab. |
| `ctrl+c` twice | Quit. |

Keys reach the active tab only; background tabs keep streaming and park their
approval prompts until you switch. When a single-tab session exits, stcli
prints the `stcli --resume` command that brings it back.

## Approvals

Every command the agent proposes is classified locally, from rule tables built
into the binary. The agent's own opinion is shown but never decides.

| Class | What happens |
| --- | --- |
| read-only | Runs immediately. |
| needs approval | `y` runs once, `n` denies. |
| unknown | Same, plus `r` to remember it as read-only in `config.json`. |
| destructive | Type the confirmation phrase shown, then `enter`. |

There is no "always allow" for writes. A `!` command skips the dialog, but a
destructive one still asks for the phrase. An unanswered prompt times out after
five minutes and the agent is told the command did not run. Reading, listing or
editing a file on your machine, or running a local command, opens its own
dialog.

## Configuration

`~/.config/stcli/config.json` holds per-host SSH opt-ins, your own
allow/ask/deny command rules, key bindings, theme and accessibility settings,
and the auto-update switch. `~/.ssh/config` is honoured for a documented
subset. Both are in [docs/configuration.md](docs/configuration.md).

## Tricks

- **Several devices, one conversation.** `stcli core1 core2` opens two tabs;
  `/add edge1` joins a device to the current session so the agent can compare
  across them.
- **Say where it goes.** "connect to edge2 in a new tab" turns the destination
  dialog into a one-key confirm.
- **Keep typing.** Messages sent during a turn queue up; `ctrl+enter` jumps the
  queue.
- **Resume by prefix.** `stcli --resume 7f3a` is enough when the prefix is
  unique; `/sessions --new 3` resumes into a fresh tab.
- **Teach it your platform.** Press `r` on unknown commands; `config.json`
  accumulates an `allow` list tuned to your gear.
- **Deny the dangerous.** A `deny` rule refuses a command from the agent and
  from `!` alike, with no dialog.
- **Pods too.** `stcli k8s://prod/router-0?container=frr` opens a shell
  through the Kubernetes API.

## Releases and verification

A maintainer cuts a release from the Release workflow in
[stcli](https://github.com/super-trace/stcli). It builds five packages, macOS
universal, Linux amd64/arm64, and Windows amd64/arm64, with the version stamped
into every executable. Verified archives, `checksums.txt`, and `provenance.json`
are uploaded to a draft release here, published once every upload succeeds, and
the built commit is tagged in stcli with the same version.

Versions use the UTC date: `vYYYY.MM.DD`, with `.2`, `.3`, etc. for additional
releases that day. Installers accept the version without `v`.

The installer checks the archive's SHA-256 before replacing an installation.
Checksums detect corrupt downloads; they are not independent publisher
signatures. macOS executables are ad-hoc signed, not notarized; Windows
executables are unsigned, so SmartScreen may warn on first run.

## Uninstall

```sh
rm "$HOME/.stcli/bin/stcli"
```

```powershell
Remove-Item "$env:USERPROFILE\.stcli\bin\stcli.exe"
```

If you selected a different installation directory, remove `stcli` there instead,
and drop the `PATH` entry the installer added. `rm -r ~/.config/stcli` drops the
credentials and config file.
