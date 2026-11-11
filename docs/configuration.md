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

## `auto_update`

`false` turns background updates off. `stcli update` still works.

## `hosts`

Keyed by the host as you type it or by the address dialled, case-insensitive.
`legacy_algorithms: true` enables obsolete SSH crypto (`ssh-rsa`, SHA-1 key
exchange, CBC ciphers) for that host only. An `~/.ssh/config` line that adds an
obsolete algorithm to the host's block does the same (see **Old gear** below).
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
| `allow` | Read-only, runs without approval. Lifts only a command the built-in tables do not recognise, or a bare write verb narrowed by more words (`commit check`). It never beats a destructive pattern, a write pattern, or an output escape such as `> file`; an entry that could never apply is rejected at startup. |
| `ask` | Needs approval even though the built-in tables call it read-only. |
| `deny` | Never runs, from the agent or from `!`, and opens no dialog. |

Precedence: `deny`, then the built-in destructive and write rules, then `ask`,
then `allow`, then the built-in read-only rules. Rules also apply inside
chains, pipe targets, and the payloads of `find -exec` and `env`.

Pressing `r` in the approval dialog prefills the command up to its first pipe
or redirect, lets you shorten it to no fewer than two words, and saves it to
`allow` before running the command.

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
| `page_up` / `page_down` | `pgup` / `pgdown` |
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
| `screen_reader` | Drops borders, bubbles and input chrome for text labels (`you:`, `assistant:`, `error:`). Implies `ascii` and `reduced_motion`. |

Command badges and block states are always spelled out in words, so no meaning
rests on colour alone.

## SSH configuration

`~/.ssh/config` is honoured for: `Host` (with `*`, `?` and `!` negation),
`HostName`, `Port`, `User`, `IdentityFile`, `IdentityAgent`, `ProxyJump`
(chained), `UserKnownHostsFile`, `HashKnownHosts`, `StrictHostKeyChecking`,
`Include`, `PubkeyAuthentication`, `PasswordAuthentication`,
`KbdInteractiveAuthentication`, and the algorithm lists `KexAlgorithms`,
`Ciphers`, `MACs`, `HostKeyAlgorithms` and `PubkeyAcceptedAlgorithms`.
Resolution follows OpenSSH: first value wins, `IdentityFile` and
`UserKnownHostsFile` accumulate. `ProxyJump` also takes `ssh://user@host:port`.

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
fails with a short error: what the device offered, one line saying how to fix
it, and a `Host` block you can paste into `~/.ssh/config` as is. `--debug` adds
the underlying SSH error.

Without that opt-in, an RSA login key signs with SHA-2 only. A device that
accepts only `ssh-rsa` signatures (most older Cisco IOS) fails the same way,
with `PubkeyAcceptedAlgorithms +ssh-rsa` in the block, and no login attempt is
spent on it.

Some things no setting reaches: DSA keys (`ssh-dss`) as host or login keys,
RC4 and MD5, `aes192-cbc` and `aes256-cbc`, RSA keys under 1024 bits, and SSH
protocol 1. A device that offers only these fails with an error naming what it
offered and the fix on the device, such as `crypto key generate rsa modulus
2048` or `ip ssh version 2`. An `IdentityFile` stcli cannot use (DSA, a small
RSA key, a PuTTY `.ppk`, a `.pub`) is named with the reason.

### Host keys

Host keys are always verified against `~/.ssh/known_hosts`. An unknown key
shows its fingerprint in the TUI and asks before trusting it. A changed key is
a hard failure, and `StrictHostKeyChecking no` cannot switch verification off.

