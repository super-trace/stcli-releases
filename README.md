# stcli

stcli is a terminal UI that SSHes into network equipment and operates it in
natural language. You describe intent, "why is BGP down on this router?", "turn
up ge-0/0/2", a backend agent turns it into commands for the connected
platform, and stcli runs them over your own SSH session behind a human approval
gate. Device credentials never leave your machine; the backend sees command
output, never secrets.

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

macOS uses one universal executable for Intel and Apple Silicon. Linux, WSL, and
Windows support x86-64 and ARM64.

The installer puts the latest release at `~/.stcli/bin/stcli`
(`%USERPROFILE%\.stcli\bin\stcli.exe` on Windows), needs no administrator
rights, and adds that directory to `PATH` in your shell profile or user
environment if it is not already there. Re-run the command to upgrade. `stcli
version` prints the release version and the source commit, for example
`2026.11.04 (c5ddc1f)`.

stcli also updates itself: on launch it checks for a newer release, installs it
in the background, and the next launch runs it. `stcli version` names an update
waiting for a restart. Set `STCLI_NO_AUTO_UPDATE=1`, or `"auto_update": false`
in `config.json`, to turn that off; `stcli update` installs the latest release
on demand. Both only work for installs under `~/.stcli/bin`.

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

The first launch prints a sign-in URL with a code pre-filled, offers to open a
browser, and polls until you confirm. Over SSH or on a headless machine, paste
the URL into any browser. Tokens land in `~/.config/stcli/credentials.json`.

Use a terminal with SSH access to your device. stcli authenticates the way
`ssh` would: ssh-agent, `~/.ssh` keys, keyboard-interactive, or a password
prompt. Passwords are never stored.

Once connected, type what you want:

```
why is bgp down on this router?
show me the interfaces with errors
turn up ge-0/0/2
```

With no device connected, name one ("connect to admin@10.0.0.1") and the agent
asks to connect. The backend identifies an unknown platform automatically; the
TUI shows **Identifying platform** while it does.

## Usage

```
stcli [options] [target ...]
stcli login | logout | version | update
```

### Targets

| Target | Description |
| --- | --- |
| `user@host[:port]` | SSH. `host` can be an alias from `~/.ssh/config` or a bracketed IPv6 literal. |
| `host` | SSH as the current user, or the `User` from `~/.ssh/config`. |
| `k8s://namespace/pod` | A shell inside a pod through the Kubernetes API. Options: `?context=`, `?container=`, `?shell=`. |

Each target opens its own tab. With none, the TUI opens one unbound tab.

### Subcommands

| Command | Description |
| --- | --- |
| `stcli login` | Sign in through the browser. |
| `stcli logout` | Revoke the sign-in and clear the local store. |
| `stcli version` | Print the release version and git sha, and any update waiting for a restart. |
| `stcli update` | Install the latest release now, even with background updates off. |

### Options

| Flag | Description |
| --- | --- |
| `--resume [ID]` | Resume a session by full id or unique prefix, or pick one from a list, and reconnect to its device. Takes no target. |
| `--backend URL` | Backend base URL. Default `https://cli.supertrace.ai`. |
| `--theme NAME` | `auto`, `dark`, `light` or `mono`. |
| `--debug` | Error codes and transport detail in the TUI, plus `stcli-debug.log` in the working directory. |
| `--help` | Usage. |

### Environment

| Variable | Description |
| --- | --- |
| `STCLI_TOKEN` | Bearer token instead of the credential store. CI and lab backends. |
| `STCLI_DEBUG` | Same as `--debug`. |
| `STCLI_THEME` | Same as `--theme`. `NO_COLOR` and `GLAMOUR_STYLE` are honoured too. |
| `STCLI_NO_AUTO_UPDATE` | Set to anything to stop background updates. |
| `STCLI_SSH_PASSWORD` | Answer SSH password prompts with this value. Lab use only; passphrases still prompt. |
| `STCLI_SKIP_SSH_CONFIG` | Set to anything to ignore `~/.ssh/config`. |
| `XDG_CONFIG_HOME` | Moves `~/.config/stcli` when set to an absolute path. |

## Inside the TUI

`/help` shows this at any time.

### Commands

| Command | Alias | Description |
| --- | --- | --- |
| `/connect [target]` | `/c` | Redial this tab, or pick which session a new target joins. |
| `/add <target>` | | Add a device to this session, no dialog. |
| `/new [target]` | `/n` | Start a fresh session, or open a new tab on target. |
| `/disconnect [label]` | | Close one device. |
| `/sessions [--new] <n\|id>` | | List past sessions; resume one here or in a new tab. |
| `/switch [n\|device]` | `/s` | Pick a tab, or jump to one. |
| `/close` | | Close this tab; on the last tab, quit. |
| `/usage` | | Account token and command accounting. |
| `/help` | `/h`, `/?` | Commands and keys. |
| `/quit` | `/q`, `/exit` | Leave. |

### Running commands yourself

```
!show interfaces terse
!edge1 show bgp summary
```

`!` runs the rest of the line verbatim on the device, with no agent turn.
Typing it is the approval, but a destructive command still asks for the typed
confirmation, and a `deny` rule still refuses it. With several devices in the
session, name one: `!<label> cmd`. The command and its output go into the
session transcript, so the agent sees what you did on its next turn.

### Keys

| Key | Action |
| --- | --- |
| `enter` | Send. During a turn, queue the message for when the turn ends. |
| `alt+enter`, `ctrl+j` | Newline. |
| `ctrl+enter` | Interrupt the running turn and send now. |
| `esc` | Interrupt the turn; cancel a dialog. |
| `up` / `down` | Input history, from the input's first or last line. `up` on an empty input pulls back the last queued message. |
| `ctrl+up` / `ctrl+down` | Select the previous / next command block. |
| `ctrl+e` | Expand or collapse the selected block. |
| `pgup` / `pgdown` | Scroll. |
| `ctrl+left` / `ctrl+right` | Previous / next tab. |
| `alt+1` … `alt+9` | Jump to tab. |
| `ctrl+c` twice | Quit. |
| `ctrl+d` twice | Close this tab, or quit on the last one. |

### Tabs and devices

Each tab is one backend session holding up to 8 devices. Keys reach the active
tab only; background tabs keep streaming and park approval prompts until you
switch. The tab strip marks `!` for a waiting prompt, `…` for a turn in flight,
and `✗` for a disconnected device.

When the agent asks to connect, or you type `/connect <target>`, a dialog asks
where the device goes: this session, a new session, or another open tab. `Esc`
declines. `/add` and `/new` skip the dialog.

When a single-tab session exits, stcli prints the command that resumes it:

```
Resume this session with:
  stcli --resume 7f3a9c2e
```

## Approvals

Every command the agent proposes is classified locally, from rule tables built
into the binary, before anything reaches the device. The agent's own opinion is
shown but never decides.

| Class | What happens |
| --- | --- |
| read-only | Runs immediately. |
| needs approval | Dialog: `y` or `enter` runs once, `n` or `esc` denies. |
| unknown | Same dialog, plus `r` to remember it as read-only (see **Command rules**). |
| destructive | Type the confirmation phrase shown, then `enter`. `esc` denies. |

There is no "always allow" for writes. An unanswered prompt times out after
five minutes, or sooner when the agent's own deadline lands first, and the
agent is told the command did not run. A denial goes back to the agent too, so
it can propose something else.

The agent can also ask to work on your machine: read a file, list a directory,
edit a file, or run a local command. Each opens its own dialog, `y` allows, `n`
or `esc` declines, and nothing touches the filesystem before `y`. Edits show the
replaced and new text side by side.

## Config file

`~/.config/stcli/config.json` (`%USERPROFILE%\.config\stcli\config.json` on
Windows). Every block is optional. A malformed file, an unknown key, or a bad
value fails startup and names the entry.

```json
{
  "auto_update": true,
  "hosts": {
    "edge-01": {"legacy_algorithms": true}
  },
  "commands": {
    "allow": ["nv show", "show tech-support"],
    "ask":   ["dmesg"],
    "deny":  ["show running-config | include password"]
  },
  "keys": {
    "prev_tab": ["ctrl+h"],
    "next_tab": ["ctrl+l"],
    "jump_tab": ["ctrl+1", "ctrl+2", "ctrl+3"]
  },
  "ui": {
    "theme": "auto",
    "colors": {"accent": "#5fafff", "danger": "160"},
    "high_contrast": false,
    "reduced_motion": false,
    "ascii": false,
    "screen_reader": false
  }
}
```

### `auto_update`

`false` turns background updates off. `stcli update` still works.

### `hosts`

Keyed by the host as you type it or by the address dialled, case-insensitive.
`legacy_algorithms: true` enables obsolete SSH crypto (`ssh-rsa`, SHA-1 key
exchange, CBC ciphers) for that host only. stcli never retries with weaker
crypto after a failed handshake, and the TUI warns once per connection when
this is on.

### `commands`

Your own rules on top of the built-in classifier. Every entry is a whole-word
prefix matched against the command, case and extra whitespace ignored. No
globs. Matching is textual: `sudo cat x` is not `cat x`, and a one-word entry
such as `sudo` covers every command starting with it.

| List | Effect |
| --- | --- |
| `allow` | Read-only, runs without approval. Lifts only a command the built-in tables do not recognise, or a bare write verb narrowed by more words (`commit check`). It never beats a destructive pattern, a write pattern, or an output escape such as `> file`; an entry that could never apply is rejected at startup. |
| `ask` | Needs approval even though the built-in tables call it read-only. |
| `deny` | Never runs, from the agent or from `!`, and opens no dialog. |

Precedence: `deny`, then the built-in destructive and write rules, then `ask`,
then `allow`, then the built-in read-only rules. Rules also apply inside
chains, pipe targets, and the payloads of `find -exec` and `env`.

Pressing `r` in the approval dialog prefills the command up to its first pipe
or redirect, lets you shorten it to no fewer than two words, and saves it to
`allow` before running the command.

### `keys`

Rebinds any key by name. A name you set replaces that binding's whole list;
names you leave out keep their defaults. Key strings are `ctrl`, `alt`,
`shift`, `super` modifiers plus a character or a name such as `enter`, `esc`,
`tab`, `up`, `left`, `pgup`, `f5`. Approval and host-key dialog keys are not
configurable.

| Name | Default |
| --- | --- |
| `submit` | `enter` |
| `newline` | `alt+enter`, `ctrl+j` |
| `send_now` | `ctrl+enter` |
| `interrupt` | `esc` |
| `prev_block` / `next_block` | `ctrl+up` / `ctrl+down` |
| `toggle_block` | `ctrl+e` |
| `page_up` / `page_down` | `pgup` / `pgdown` |
| `history_prev` / `history_next` | `up` / `down` |
| `quit` / `quit_eof` | `ctrl+c` / `ctrl+d` |
| `prev_tab` / `next_tab` | `ctrl+left` / `ctrl+right` |
| `jump_tab` | `alt+1` … `alt+9`; list position is the tab number |

### `ui`

| Key | Description |
| --- | --- |
| `theme` | `auto` follows the terminal background (default); `dark`; `light`; `mono` uses no colour, bold and reverse video carry meaning. |
| `colors` | Overrides a palette role with `#rrggbb` or an ANSI 256 index. Roles: `accent`, `muted`, `faint`, `warn`, `danger`, `ok`, `ink`. |
| `high_contrast` | Lifts dim text to readable levels, thickens borders, underlines the active tab. |
| `reduced_motion` | Replaces the thinking spinner with a static mark. |
| `ascii` | Replaces box drawing, half-block caps and the spinner with ASCII; markdown renders in the `ascii` style. |
| `screen_reader` | Drops borders, bubbles and input chrome for text labels (`you:`, `assistant:`, `error:`). Implies `ascii` and `reduced_motion`. |

Command badges and block states are always spelled out in words, so no meaning
rests on colour alone.

## SSH configuration

`~/.ssh/config` is honoured for: `Host` (with `*`, `?` and `!` negation),
`HostName`, `Port`, `User`, `IdentityFile`, `IdentityAgent`, `ProxyJump`
(chained), `UserKnownHostsFile`, `HashKnownHosts`, `StrictHostKeyChecking`,
`Include`, `PubkeyAuthentication`, `PasswordAuthentication`,
`KbdInteractiveAuthentication`. Resolution follows OpenSSH: first value wins,
`IdentityFile` and `UserKnownHostsFile` accumulate.

Any other keyword that could change which host is reached or how it
authenticates fails the connection and names the keyword, file and line.
Cosmetic keywords such as `Compression`, `ConnectTimeout` and `LogLevel` are
ignored. `ProxyCommand` is not supported; use `ProxyJump`.

Host keys are always verified against `~/.ssh/known_hosts`. An unknown key
shows its fingerprint in the TUI and asks before trusting it. A changed key is
a hard failure, and `StrictHostKeyChecking no` cannot switch verification off.

## Tricks

- **Several devices, one conversation.** `stcli core1 core2 edge1` opens three
  tabs; `/add edge2` joins a device to the current session instead so the agent
  can compare across them. Up to 8 per session.
- **Pick where a device goes.** Say it in the request: "connect to edge2 in a
  new tab" turns the destination dialog into a one-key confirm.
- **Queue while the agent works.** Keep typing during a turn; each `enter`
  queues a message for when the turn ends. `ctrl+enter` jumps the queue and
  interrupts.
- **Resume anywhere.** `stcli --resume` lists past sessions with their titles;
  `stcli --resume 7f3a` takes a unique prefix. `/sessions` does the same inside
  the TUI, and `/sessions --new 3` resumes into a fresh tab.
- **Teach it your platform.** Unknown commands land in the approval dialog with
  `r`; after a few of those `config.json` carries an `allow` list tuned to
  your gear.
- **Deny the dangerous.** A `deny` entry refuses a command from the agent and
  from `!` alike, with no dialog. Put credential-leaking reads there.
- **Pods too.** `stcli k8s://prod/router-0?container=frr&shell=/bin/bash`
  opens a shell through the Kubernetes API; the cluster CA certificate is the
  identity, and the Linux rule table applies.
- **Headless sign-in.** `stcli login` always prints the URL; open it from any
  browser and the terminal picks up the result.
- **Read the log.** `--debug` writes `stcli-debug.log` in the working
  directory; the TUI owns stdout, so that is where errors and transport detail
  go.

## Gotchas

- **Needs a real TTY.** stcli refuses to start when stdout is redirected or
  inside a non-interactive session. Flags are still validated first, so a usage
  mistake reports itself.
- **`--resume` takes no target.** It redials the device the session was on. To
  change device, resume then `/connect`.
- **`!` during an agent command.** The agent and `!` share one SSH session, so a
  `!` typed while the agent's command runs is refused. `esc` the turn first.
- **`!` with several devices.** A bare `!cmd` is refused and lists the labels;
  use `!<label> cmd`.
- **`ctrl+enter` needs a modern terminal.** kitty, Ghostty, WezTerm and iTerm2
  report it; elsewhere it behaves like `enter`.
- **Session full.** The ninth device is refused with `session full (8
  devices)`; open it with `/new` instead.
- **Unsupported `ssh_config` keyword.** The connection fails rather than
  guessing. Move the host to a minimal `Host` block, or set
  `STCLI_SKIP_SSH_CONFIG=1` for that run.
- **Changed host key.** Hard failure, no override. Fix `known_hosts` by hand if
  the change is legitimate.
- **Legacy crypto.** An old box that fails the handshake needs
  `legacy_algorithms` in `config.json` for that host. stcli never downgrades on
  its own.
- **Config typos fail startup.** An unknown key or an impossible `allow` entry
  stops stcli and names the entry, so an opt-in is never silently dropped.
- **Command deadline.** An agent command runs at most 600 s, `!` commands 120 s.
  A running command is aborted at the deadline and reported as a timeout.
- **Output cap.** Command output is truncated at 64 KiB before it reaches the
  agent; the block is flagged as truncated.
- **Windows.** SmartScreen may warn on first run: the executable is unsigned.
  ssh-agent is the OpenSSH named pipe unless `SSH_AUTH_SOCK` says otherwise.
- **macOS.** Executables are ad-hoc signed, not notarized.
- **Auto-update only for script installs.** A binary outside `~/.stcli/bin`
  never updates itself and `stcli update` refuses.

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
removed; `rm -r ~/.config/stcli` drops the credentials and config file.
