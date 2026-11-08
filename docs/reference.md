# Reference

`stcli --help` and `/help` inside the TUI show the same.

## Command line

```
stcli [options] [target ...]
stcli login | logout | version | update
```

| Target | Description |
| --- | --- |
| `user@host[:port]` | SSH. `host` can be an alias from `~/.ssh/config` or a bracketed IPv6 literal. |
| `k8s://namespace/pod` | A shell inside a pod through the Kubernetes API. Options: `?context=`, `?container=`, `?shell=`. |

Each target opens its own tab. With none, the TUI opens one unbound tab. A new tab's
session is created when its first device connects or its first message is sent, so a
tab closed untouched leaves no session behind.

| Command / flag | Description |
| --- | --- |
| `login` / `logout` | Sign in through the browser; revoke and clear the local store. |
| `version` | Release version, git sha, and any update waiting for a restart. |
| `update` | Install the latest release now. |
| `--resume [ID]` | Resume a session by id or unique prefix, or pick from a list, and reconnect to its device. Takes no target. |
| `--backend URL` | Backend base URL. Default `https://cli.supertrace.ai`. |
| `--theme NAME` | `auto`, `dark`, `light` or `mono`. |
| `--debug` | Error detail in the TUI, plus `stcli-debug.log` in the working directory. |

## Environment

| Variable | Description |
| --- | --- |
| `STCLI_TOKEN` | Bearer token instead of the credential store. CI and lab backends. |
| `STCLI_DEBUG` / `STCLI_THEME` | Same as the flags. `NO_COLOR` and `GLAMOUR_STYLE` are honoured too. |
| `STCLI_NO_AUTO_UPDATE` | Set to anything to stop background updates. |
| `STCLI_SSH_PASSWORD` | Answer SSH password prompts with this value. Lab use only; passphrases still prompt. |
| `STCLI_SKIP_SSH_CONFIG` | Set to anything to ignore `~/.ssh/config`. |
| `XDG_CONFIG_HOME` | Moves `~/.config/stcli` when set to an absolute path. |

## Slash commands

| Command | Alias | Description |
| --- | --- | --- |
| `/connect [target]` | `/c` | Redial this tab, or pick which session a new target joins. |
| `/add <target>` | | Add a device to this session, no dialog. Up to 8 per session. |
| `/new [target]` | `/n` | Start a fresh session, or open a new tab on target. |
| `/disconnect [label]` | | Close one device. |
| `/sessions [--new] <n\|id>` | | List past sessions; resume one here or in a new tab. |
| `/switch [n\|device]` | `/s` | Pick a tab, or jump to one. |
| `/close` | | Close this tab; on the last tab, quit. |
| `/usage` | | Account token and command accounting. |
| `/help` | `/h`, `/?` | Commands and keys. |
| `/quit` | `/q`, `/exit` | Leave. |

`!cmd` runs the rest of the line verbatim on the device, with no agent turn.
With several devices in the session, name one: `!<label> cmd`. The command and
its output join the transcript. A `!` typed while the agent's own command is
running is refused; `esc` the turn first.

## Keys

Defaults; every name is rebindable in `config.json`, see
[configuration.md](configuration.md).

| Key | Action |
| --- | --- |
| `enter` | Send. During a turn, queue the message for when it ends. |
| `alt+enter`, `ctrl+j` | Newline. |
| `ctrl+enter` | Interrupt the running turn and send now. Needs a terminal that reports modified keys (kitty, Ghostty, WezTerm, iTerm2); elsewhere it acts like `enter`. |
| `esc` | Interrupt the turn; cancel a dialog. |
| `up` / `down` | Input history, from the input's first or last line. `up` on an empty input pulls back the last queued message. |
| `ctrl+up` / `ctrl+down` | Select the previous / next command block. |
| `ctrl+e` | Expand or collapse the selected block. |
| `pgup` / `pgdown` | Scroll. |
| `ctrl+left` / `ctrl+right` | Previous / next tab. |
| `alt+1` … `alt+9` | Jump to tab. |
| `ctrl+c` twice | Quit. |
| `ctrl+d` twice | Close this tab, or quit on the last one. |

Keys reach the active tab only; background tabs keep streaming and park their
approval prompts until you switch. The tab strip marks `!` for a waiting
prompt, `…` for a turn in flight, and `✗` for a disconnected device.
