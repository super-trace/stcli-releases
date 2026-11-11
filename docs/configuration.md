# Configuration

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
  "mcp": {
    "netbox": {
      "url": "https://netbox.example.com/mcp",
      "headers": {"Authorization": "Token …"}
    }
  },
  "keys": {
    "prev_tab": ["ctrl+pgup"],
    "next_tab": ["ctrl+pgdown"],
    "jump_tab": ["ctrl+1", "ctrl+2", "ctrl+3"]
  },
  "ui": {
    "theme": "auto",
    "colors": {"accent": "#5fafff", "danger": "160"},
    "high_contrast": false,
    "reduced_motion": false,
    "ascii": false,
    "screen_reader": false,
    "mouse": true,
    "copy_on_select": true
  }
}
```

## `auto_update`

`false` turns background updates off. `stcli update` still works.

## `hosts`

Keyed by the host as you type it or by the address dialled, case-insensitive.
`legacy_algorithms: true` enables obsolete SSH crypto (`ssh-rsa`, SHA-1 key
exchange, CBC ciphers) for that host only. stcli never retries with weaker
crypto after a failed handshake, and the TUI warns once per connection when
this is on.

## `commands`

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

## `mcp`

MCP servers, keyed by name. `url` is required and must be `http` or `https`;
`headers` is optional. stcli writes the file readable only by you (mode 0600),
since headers often carry credentials. If you create or edit the file by hand,
restrict it yourself before adding a header: `chmod 600 ~/.config/stcli/config.json`
on macOS and Linux, or remove other users from the file's permissions in its
Properties dialog on Windows. `/mcp add` and `/mcp remove` edit this block for
you; see [reference.md](reference.md#mcp-servers).

## `keys`

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
| `copy` | `ctrl+y` |
| `toggle_mouse` | `ctrl+o` |
| `page_up` / `page_down` | `pgup` / `pgdown` |
| `scroll_bottom` | `ctrl+l`, `ctrl+end` |
| `history_prev` / `history_next` | `up` / `down` |
| `quit` / `quit_eof` | `ctrl+c` / `ctrl+d` |
| `prev_tab` / `next_tab` | `ctrl+left` / `ctrl+right` |
| `jump_tab` | `alt+1` … `alt+9`; list position is the tab number |

## `ui`

| Key | Description |
| --- | --- |
| `theme` | `auto` follows the terminal background (default); `dark`; `light`; `mono` uses no colour, bold and reverse video carry meaning. |
| `colors` | Overrides a palette role with `#rrggbb` or an ANSI 256 index. Roles: `accent`, `muted`, `faint`, `warn`, `danger`, `ok`, `ink`. |
| `high_contrast` | Lifts dim text to readable levels, thickens borders, underlines the active tab. |
| `reduced_motion` | Replaces the thinking spinner with a static mark. |
| `ascii` | Replaces box drawing, half-block caps and the spinner with ASCII; markdown renders in the `ascii` style. |
| `mouse` | `false` starts with mouse reporting off, so the terminal selects text and the wheel does not scroll the transcript. Default `true`; `ctrl+o` switches it while running. |
| `copy_on_select` | `false` makes a mouse selection only highlight; `ctrl+c` or `ctrl+y` copies it. Default `true`. |
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

