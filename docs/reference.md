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

Every target dials into one session; with none, it opens unbound. The session is
created when its first device connects or its first message is sent, so stcli closed
untouched leaves no session behind. For a second session, run another stcli.

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
| `/connect [target]` | `/c` | Dial target into this session, or redial. |
| `/add <target>` | | Add a device to this session. Up to 8 per session. |
| `/new [target]` | `/n` | Start a fresh session with no devices, then dial target. |
| `/clear` | | Start a fresh conversation, keeping this session's devices. |
| `/disconnect [label]` | | Close one device. |
| `/sessions [n\|id]` | | List past sessions; resume one. |
| `/mcp [list\|add\|remove]` | | Manage MCP servers. See [MCP servers](#mcp-servers). |
| `/usage` | | Account token and command accounting. |
| `/copy` | | Copy the agent's last reply as markdown. |
| `/config [key=value]` | | Open the settings dialog, or change one setting. See [Settings](#settings). |
| `/help` | `/h`, `/?` | Commands and keys. |
| `/quit` | `/q`, `/exit` | Leave. |

`!cmd` runs the rest of the line verbatim on the device, with no agent turn.
With several devices in the session, name one: `!<label> cmd`. The command and
its output join the transcript. A `!` typed while the agent's own command is
running is refused; `esc` the turn first.

## Settings

`/config` opens a dialog of the settings that take one of a few values. `up` /
`down` move, `space` or `enter` steps the highlighted setting to its next value
and saves it at once, and `esc` closes the dialog and says what changed.

`/config key=value` changes one setting without the dialog, for example
`/config ui.copy_on_select=off`. The `ui.` prefix may be left off, and `true` /
`false` stand for `on` / `off`.

| Setting | Values | Takes effect |
| --- | --- | --- |
| `ui.mouse` | `on`, `off` | At once, in every tab |
| `ui.copy_on_select` | `on`, `off` | At once, in every tab |
| `ui.theme` | `auto`, `dark`, `light`, `mono` | At once, in every tab |
| `ui.syntax` | `on`, `off` | At once, in every tab |
| `ui.high_contrast`, `ui.reduced_motion` | `off`, `on` | At once, in every tab |
| `ui.ascii`, `ui.screen_reader` | `off`, `on` | When stcli restarts |
| `auto_update` | `on`, `off` | When stcli restarts |

Changes are saved to `config.json`, next to whatever else it holds. Key
bindings, colours, hosts, command rules and MCP servers are not in `/config`;
edit them in the file as [configuration.md](configuration.md) describes. A
change you make to the file by hand takes effect when stcli restarts.

A theme set this way replaces `--theme` and `STCLI_THEME` until stcli exits.
`auto` goes back to the light or dark background stcli started with: the
terminal is only asked at startup.

### Asking the agent

You can also ask the agent, for example "how do I stop a selection from
copying?" or "turn copy on select off". It has two tools for this:

- **Help** describes the stcli you are running: its commands, its keys as you
  have bound them, and the settings above with their values. It runs without
  asking you and reads nothing else from your settings file.
- **Set a setting** changes one of the settings above. It opens the usual
  approval dialog every time, and it cannot change anything `/config` does not
  list.

## MCP servers

Connect your own MCP servers and the agent can call their tools.

| Command | Description |
| --- | --- |
| `/mcp` | Print the three forms. |
| `/mcp list` | Each server with its URL, status and tool count. Status is `connected (N tools)`, `needs auth` or `failed: <reason>`. |
| `/mcp add <name> <url> [--header <Key>[: <value>]]…` | Save the server to `config.json` and connect. |
| `/mcp remove <name>` | Disconnect and forget the server. |

A header named without a value is asked for with a masked prompt, so the value
never appears on screen or in history. A value given inline works too.

Names are lowercase letters, digits and hyphens, up to 32 characters; `stcli`
is taken by stcli's own tools. Servers
must be reachable over HTTP(S) (the MCP streamable HTTP transport). OAuth
sign-in and stdio servers are not supported yet.

Each tool reaches the agent as `mcp__<server>__<tool>`. Every call opens an
approval dialog with the server, the tool, its description and the arguments;
nothing runs until you press `y` or `enter`. At most 92 tools in total are
advertised to the agent.

Changes take effect in idle tabs at once, and in a busy tab when its current
turn ends.

## Keys

Defaults; every name is rebindable in `config.json`, see
[configuration.md](configuration.md).

| Key | Action |
| --- | --- |
| `enter` | Send. During a turn, queue the message for when it ends. |
| `alt+enter`, `ctrl+j` | Newline. On Windows use `ctrl+j`: Windows Terminal and the classic console take `alt+enter` for fullscreen. |
| `ctrl+enter` | Interrupt the running turn and send now. Needs a terminal that reports modified keys (kitty, Ghostty, WezTerm, iTerm2); elsewhere it acts like `enter`. |
| `esc` | Interrupt the turn; cancel a dialog. |
| `tab` | In a configuration-block dialog, switch between the Config and Diff tabs; `up` / `down` and `pgup` / `pgdown` scroll it. |
| `up` / `down` | Input history, from the input's first or last line. `up` on an empty input pulls back the last queued message. |
| `ctrl+up` / `ctrl+down` | Select the previous / next command block. |
| `ctrl+e` | Expand or collapse the selected block. |
| `ctrl+y` | Copy the mouse selection while one is on screen; otherwise the selected block, or the most recent one: the command and its full output. |
| `ctrl+o` | Turn mouse reporting off or on, so the terminal can select text itself. |
| `pgup` / `pgdown` | Scroll. |
| `ctrl+l` / `ctrl+end` | Jump to the latest output. While you are scrolled back, the line above the input says so, and with the mouse on, clicking it jumps too. Sending a message also jumps. |
| `ctrl+c` twice | Quit. While a mouse selection is on screen, `ctrl+c` copies it instead. |
| `ctrl+d` twice | Quit, on an empty input. |

Dragging over the transcript selects text and copies it on release; a double
click takes a word and a triple click a row. `ctrl+c` copies the selection
again and releases it, and so does `cmd+c` in a terminal that passes it on;
your terminal's own copy shortcut does not see the selection. To select
without copying, set [`copy_on_select`](configuration.md) to `false`: the line
above the input then says `ctrl+c to copy`. Over SSH the copy relies on your
terminal accepting OSC 52. Under tmux, stcli hands the text to tmux, which keeps
it as a paste buffer and passes it on to your terminal with its default
settings. Any other tmux between stcli and your terminal, such as one on your
own machine with stcli over SSH inside it, needs `set-clipboard on`, which lets
any program in tmux set your clipboard. Where the copy is not
accepted, press `ctrl+o` and select with the terminal or with tmux.

A GitHub Codespace opened in the browser does not accept the copy. There the
line above the input reads `copy may fail in codespace · ctrl+o for native
select`: press `ctrl+o`, select with the terminal and copy with its own
shortcut. A Codespace opened in desktop VS Code shows the same line and may
copy anyway.

Keys reach the active tab only; background tabs keep streaming and park their
approval prompts until you switch. The tab strip marks `!` for a waiting
prompt, `…` for a turn in flight, and `✗` for a disconnected device.
