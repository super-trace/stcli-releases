# Configuration

`~/.config/stcli/config.json` (`%USERPROFILE%\.config\stcli\config.json` on
Windows). Every block is optional. A malformed file, an unknown key, or a bad
value fails startup and names the entry.

The on/off settings and the theme can also be changed from inside stcli with
`/config`; see [reference.md](reference.md#settings).

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
    "tickets": {
      "url": "https://mcp.example.com/mcp",
      "headers": {"Authorization": "Bearer …"}
    }
  },
  "netbox": {
    "url": "https://netbox.example.com"
  },
  "keys": {
    "page_up": ["ctrl+b"],
    "scroll_bottom": ["ctrl+g"]
  },
  "ui": {
    "theme": "auto",
    "colors": {"accent": "#5fafff", "danger": "160"},
    "high_contrast": false,
    "reduced_motion": false,
    "ascii": false,
    "screen_reader": false,
    "mouse": true,
    "copy_on_select": true,
    "syntax": true
  }
}
```

## `auto_update`

`false` turns background updates off. `stcli update` still works.

## `hosts`

Keyed by the host as you type it or by the address dialed, case-insensitive.
`legacy_algorithms: true` enables obsolete SSH crypto (`ssh-rsa`, SHA-1 key
exchange, CBC ciphers) for that host only. An `~/.ssh/config` line that adds an
obsolete algorithm to the host's block does the same (see [Old gear](#old-gear)).
stcli never retries with weaker crypto after a failed handshake. The TUI warns
once per connection, naming the obsolete algorithms the device actually
negotiated; a host that opted in but negotiates strong crypto gets no warning.

## `commands`

Your own rules on top of the built-in classifier. Every entry is a whole-word
prefix matched against the command, case and extra whitespace ignored. No
globs. Matching is textual: `sudo cat x` is not `cat x`, and a one-word entry
such as `sudo` covers every command starting with it.

| List | Effect |
| --- | --- |
| `allow` | Read-only, runs without approval. Lifts only a command the built-in tables do not recognize, or a bare write verb narrowed by more words (`commit check`). It never beats a destructive pattern, a write pattern, or an output escape such as `> file`; an entry that could never apply is rejected at startup. |
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

## `netbox`

Your NetBox: `url` is required and must be `http` or `https`. `token` is the
API token, kept here only when you connect with `/netbox connect --save`;
otherwise stcli asks for it each time. The same `chmod 600` advice as for `mcp`
applies. `/netbox connect` and `/netbox disconnect` edit this block for you; see
[reference.md](reference.md#netbox).

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
| `prev_block` / `next_block` | `alt+up`, `ctrl+up` / `alt+down`, `ctrl+down` |
| `toggle_block` | `ctrl+e` |
| `toggle_all` | `ctrl+o` |
| `copy` | `ctrl+y` |
| `toggle_mouse` | `ctrl+t` |
| `page_up` / `page_down` | `pgup` / `pgdown` |
| `scroll_bottom` | `ctrl+l`, `ctrl+end` |
| `history_prev` / `history_next` | `up` / `down` |
| `quit` / `quit_eof` | `ctrl+c` / `ctrl+d` |

## `ui`

| Key | Description |
| --- | --- |
| `theme` | `auto` follows the terminal background (default), or is `mono` when `NO_COLOR` is set; `dark`; `light`; `mono` uses no color, bold and reverse video carry meaning. On a 16-color terminal (`TERM=xterm`, PuTTY's default) the palette uses the 16 ANSI colors. |
| `colors` | Overrides a palette role with `#rrggbb` or an ANSI 256 index. Roles: `accent`, `muted`, `faint`, `warn`, `danger`, `ok`, `ink`. |
| `high_contrast` | Lifts dim text to readable levels, thickens borders, underlines the picker cursor. |
| `reduced_motion` | Replaces the thinking spinner with a static mark. |
| `ascii` | Draws stcli's own screen in ASCII: box drawing, half-block caps, the spinner, arrows, separators and ellipses; markdown renders in the `ascii` style. Commands, device output and the agent's text are shown as they are. On by default when `TERM` is `linux` or a VT terminal (`vt100`, `vt220`), whose fonts lack those symbols; `false` turns it off there too. |
| `mouse` | `false` starts with mouse reporting off, so the terminal selects text and the wheel does not scroll the transcript. Default `true`; `ctrl+t` switches it while running. |
| `copy_on_select` | `false` makes a mouse selection only highlight; `ctrl+c` or `ctrl+y` copies it. Default `true`. |
| `syntax` | `false` turns syntax highlighting off. Default `true`. |
| `screen_reader` | Drops borders, bubbles and input chrome for text labels (`you:`, `assistant:`, `error:`). Implies `ascii` and `reduced_motion`. |

stcli highlights code in the `dark` and `light` themes: code blocks in the
agent's replies, and command output or files whose format it can tell, such as
JSON, YAML, XML and scripts. Diffs show added and removed lines in the `ok` and
`danger` colors. `"syntax": false`, `mono` and `ascii` turn highlighting off.

Command badges and block states are always spelled out in words, so no meaning
rests on color alone.

## SSH configuration

`~/.ssh/config` is honored for: `Host` (with `*`, `?` and `!` negation),
`HostName`, `Port`, `User`, `IdentityFile`, `IdentityAgent`, `ProxyJump`
(chained), `UserKnownHostsFile`, `HashKnownHosts`, `StrictHostKeyChecking`,
`Include`, `PubkeyAuthentication`, `PasswordAuthentication`,
`KbdInteractiveAuthentication`, `IdentitiesOnly`, and the algorithm lists
`KexAlgorithms`, `Ciphers`, `MACs`, `HostKeyAlgorithms` and
`PubkeyAcceptedAlgorithms`. Resolution follows OpenSSH: first value wins,
`IdentityFile` and `UserKnownHostsFile` accumulate. With `IdentitiesOnly yes`,
an ssh-agent key is offered only when it matches an `IdentityFile`.
`ProxyJump` also takes `ssh://user@host:port`.

Any other keyword that could change which host is reached or how it
authenticates fails the connection and names the keyword, file and line.
Cosmetic keywords such as `Compression`, `ConnectTimeout` and `LogLevel` are
ignored. `ProxyCommand` is not supported; use `ProxyJump`.

### Old gear

The lines you already have for old switches work:

```
Host old-switch
  KexAlgorithms +diffie-hellman-group1-sha1
  HostKeyAlgorithms +ssh-rsa
  PubkeyAcceptedAlgorithms +ssh-rsa
```

Any obsolete name in a host's algorithm lists turns on the whole obsolete set
for that host only, the same as `legacy_algorithms`. stcli still offers strong
algorithms first. A `-` list is refused, and so is a name stcli cannot speak,
naming it.

When a device needs the opt-in and the host doesn't have it, the connection
fails with what the device offered, one line saying how to fix it, and a `Host`
block you can paste into `~/.ssh/config` as is. `--debug` adds the underlying
SSH error.

Without that opt-in, an RSA login key signs with SHA-2 only. A device that
accepts only `ssh-rsa` signatures (most older Cisco IOS) fails the same way,
with `PubkeyAcceptedAlgorithms +ssh-rsa` in the block, and no login attempt is
spent on it.

No setting reaches DSA keys (`ssh-dss`), RC4 and MD5, `aes192-cbc` and
`aes256-cbc`, RSA keys under 1024 bits, or SSH protocol 1. A device that offers
only these fails with an error naming what it offered and the fix on the
device, such as `crypto key generate rsa modulus 2048` or `ip ssh version 2`.
An `IdentityFile` stcli cannot use (DSA, a small RSA key, a PuTTY `.ppk`, a
`.pub`) is named with the reason.

### Host keys

Host keys are always verified against `~/.ssh/known_hosts`. An unknown key
shows its fingerprint in the TUI and asks before trusting it. A changed key is
a hard failure, and `StrictHostKeyChecking no` cannot switch verification off.

