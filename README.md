# stcli

Operate network equipment in plain English, from your terminal, over your own
SSH session. Ask a question, approve the commands, read the answer.

```
❯ why is bgp down on this router?

  show bgp summary                                        read-only
  show interfaces ge-0/0/2                                read-only

  Peer 10.0.0.2 has been Idle for 4h12m. Its interface,
  ge-0/0/2, is administratively down.

❯ bring it up

  ┌ Approval needed ──────────────────────────────────────────┐
  │ ❯ configure; set interfaces ge-0/0/2 enable; commit       │
  │   re-enable ge-0/0/2 so the BGP peer can reconnect        │
  │   state-changing · 4m58s left                             │
  │                                                           │
  │   y  run once      n  deny                                │
  └───────────────────────────────────────────────────────────┘
```

A backend agent turns intent into commands for the connected platform. stcli
runs them locally, shows every one, and stops for a human before anything
changes.

## Safety

- **Every write the agent proposes asks.** Commands are classified on your machine from rule
  tables built into the binary. Read-only runs; anything else waits for `y`.
  Destructive commands need a typed confirmation. There is no "always allow".
- **The model never decides.** The agent's own opinion of a command is shown
  but does not reach the gate. Unknown commands are treated as writes.
- **Credentials stay local.** SSH keys, agents and passwords never leave your
  machine. The backend sees command output, not secrets.

Platforms with their own rule tables: Junos, Cisco IOS-XE, Cisco NX-OS, Arista
EOS, Nokia SR Linux, Ciena SAOS 10, and Linux. Anything else runs under the
strictest table.

## Install

macOS, Linux, or WSL:

```sh
curl -fsSL https://raw.githubusercontent.com/super-trace/stcli-releases/main/install.sh | sh
```

Windows, in PowerShell:

```powershell
irm https://raw.githubusercontent.com/super-trace/stcli-releases/main/install.ps1 | iex
```

Installs to `~/.stcli/bin` (`%USERPROFILE%\.stcli\bin` on Windows) without
administrator rights and adds it to `PATH`. Re-run to upgrade; stcli also
updates itself in the background unless `STCLI_NO_AUTO_UPDATE=1` is set.
`stcli version` prints what you have.

Or with Homebrew, on macOS or Linux:

```sh
brew install super-trace/tap/stcli
```

`brew upgrade stcli` picks up new releases; a Homebrew install does not update
itself.

Before opening, stcli checks the backend's protocol version. When the backend
has moved to a newer major version, stcli installs the matching release first
and asks you to run the command again. If it cannot update itself (installed
with Homebrew, or auto-update is off through `STCLI_NO_AUTO_UPDATE` or
`auto_update: false`), it says how to update and exits. Minor differences never
need an update.

Needs a real terminal, SSH reach to your devices, and HTTPS to
`cli.supertrace.ai`. stcli draws in a window of any size. An approval or other
dialog needs at least 70 columns by 13 rows: in a smaller window it is replaced
by a notice, and only `esc`, which declines it, or `ctrl+c` works until the
window grows, so no key can approve something you cannot see. Pinning a version or directory, and offline verification,
are in [docs/install.md](docs/install.md).

## First run

```sh
stcli                 # sign in, open the TUI with no device
stcli admin@10.0.0.1  # sign in, then SSH to the device
```

The first launch prints a sign-in URL, offers to open a browser, and polls
until you confirm. Over SSH or on a headless machine, paste the URL into any
browser. Device authentication works the way `ssh` does: ssh-agent, `~/.ssh`
keys, keyboard-interactive, or a password prompt. Passwords are never stored.

Then type what you want. With no device connected, name one ("connect to
admin@10.0.0.1") and the agent asks to connect.

## Usage

```
stcli [options] [target ...]
stcli login | logout | version | update
```

| Target | Description |
| --- | --- |
| `user@host[:port]` | SSH. `host` can be an alias from `~/.ssh/config`. |
| `k8s://namespace/pod` | A shell inside a pod through the Kubernetes API. |

Every target dials into one session; run another stcli for a second session.
`--resume` brings back a past session on the device it was on. Flags, environment variables, every slash command and every
key are in [docs/reference.md](docs/reference.md); `/help` inside the TUI
shows the same.

| In the TUI | Description |
| --- | --- |
| `/connect <target>` | Dial a device into this session. |
| `/new`, `/clear` | `/new` starts a fresh session with no devices; `/clear` starts a fresh conversation and keeps them. |
| `/sessions` | List past sessions and resume one. |
| `!show bgp summary` | Run a command yourself, no agent turn. `!edge1 cmd` with several devices. |
| `esc` | Interrupt the turn. `ctrl+c` twice quits. |

## Approvals

| Class | What happens |
| --- | --- |
| read-only | Runs immediately. |
| needs approval | `y` runs once, `n` denies. |
| unknown | Same, plus `r` to remember it as read-only in `config.json`. |
| destructive | Type the confirmation phrase shown, then `enter`. |

An unanswered prompt times out after five minutes and the agent is told the
command did not run. A `!` command skips the dialog, but a destructive one
still asks for the phrase. Reading, listing or editing a file on your machine,
or running a local command, opens its own dialog. On Windows a local command
runs in PowerShell, and destructive cmdlets such as `Remove-Item -Recurse` or
`Format-Volume` ask for the phrase too.

A configuration change of more than one line arrives as one block, not one
command at a time. stcli stages it in the device's own configuration session,
then opens a dialog with the block on a Config tab and the device's diff on a
Diff tab: `tab` switches, `y` commits, `n` aborts the session so nothing lands.
A block holds configuration statements only; a line that would commit, save or
run a command on its own is refused before anything is sent. On Arista EOS,
Junos and Nokia SR Linux; other platforms keep the one-command dialog.

## Configuration

`~/.config/stcli/config.json` holds per-host SSH opt-ins, your own
allow/ask/deny command rules, MCP servers, key bindings, theme and
accessibility settings, and the auto-update switch. `~/.ssh/config` is honoured
for a documented subset. Both are in [docs/configuration.md](docs/configuration.md).

## Tricks

- **Several devices, one conversation.** `stcli core1 core2` dials both into
  one session; `/add edge1` joins another so the agent can compare across them.
  Up to 8 per session. When the session already holds a device, the agent asks
  before it connects another: `enter` connects, `esc` declines.
- **Keep typing.** Messages sent during a turn queue up; `ctrl+enter` jumps the
  queue.
- **Resume by prefix.** `stcli --resume 7f3a` is enough when the prefix is
  unique; `/sessions 3` resumes the third in the list.
- **Teach it your platform.** Press `r` on unknown commands; `config.json`
  accumulates an `allow` list tuned to your gear.
- **Deny the dangerous.** A `deny` rule refuses a command from the agent and
  from `!` alike, with no dialog.

## Releases and verification

Releases are tagged by UTC date, `vYYYY.MM.DD`, with `.2`, `.3` for further
releases that day. Each ships five archives, `checksums.txt` and
`provenance.json`, which records the source commit and toolchain. The releases
page is the changelog.

| Platform | Package | Signing |
| --- | --- | --- |
| macOS | universal, Intel and Apple Silicon | ad-hoc signed, not notarized |
| Linux, WSL | amd64, arm64 | unsigned |
| Windows | amd64, arm64 | unsigned; SmartScreen may warn on first run |

The installer verifies the SHA-256 before replacing anything. Checksums catch
corrupt downloads; they are not a publisher signature. To verify by hand:

```sh
shasum -a 256 -c --ignore-missing checksums.txt
```

## Uninstall

```sh
rm "$HOME/.stcli/bin/stcli"
```

```powershell
Remove-Item "$env:USERPROFILE\.stcli\bin\stcli.exe"
```

If you chose a different directory with `STCLI_INSTALL_DIR`, remove `stcli`
there instead. Drop the `PATH` entry the installer added. A Homebrew install
goes with `brew uninstall stcli`. `rm -r
~/.config/stcli` (`$XDG_CONFIG_HOME/stcli` when that variable is set) removes
credentials and the config file.

## Support

Problems with installation, packages, or the tool itself: open an issue in
this repository. Run with `--debug` and attach `stcli-debug.log` from the
working directory.
