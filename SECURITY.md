# Security

Report security issues privately through
[GitHub private vulnerability reporting](https://github.com/super-trace/stcli-releases/security/advisories/new),
not as a public issue.

## In scope

- A state-changing command that runs without approval, or with a weaker
  confirmation than its classification requires.
- SSH keys, passwords, or agent material leaving your machine.
- A way for the backend or the model to bypass the approval gate.
- Tampered or unverifiable release artifacts, or installer flaws.

## Out of scope

- Commands you approved yourself.
- Device-side vulnerabilities in the equipment stcli connects to.

## Supported versions

Only the latest release. stcli updates itself unless `STCLI_NO_AUTO_UPDATE=1`
is set.
