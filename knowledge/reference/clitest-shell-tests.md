# Shell-level tests with clitest

`tests/*.clitest.txt` hold shell-level regression tests, run with
[clitest](https://github.com/aureliojargas/clitest) (installed 2026-07-10,
Aaron's pick) from the repo root:

```bash
clitest tests/vm-harness.clitest.txt
```

When to use: shell seams that pytest can't reach naturally — sed/awk filters,
CLI flag handling, pass-through/pipeline guarantees, pty behavior (via
`script(1)` inside a test). Python-internal logic belongs in pytest instead.

Format gotchas (verified against clitest 0.5.0):

- `$ ` lines are commands; **everything** until the next `$` line is expected
  output — free prose placed after a command block WILL be compared and fail
  the test. End every block with a lone `$` line, then prose is safe.
- `#=> text` inline expectation works for one-liners.
- All commands in a file share one shell session — variables (e.g. a `mktemp
  -d` dir) persist across tests, which later tests may rely on.
- Tests must not depend on host state (no libvirt/network); keep them
  CI-runnable — they are a candidate for the Story 4.7 minimal CI (#94).

Seams added for testability: `vm-harness scrub` (stdin → scrubbed stdout, the
state-log filter); `setsid` detaches the controlling tty to force
vm-harness-display's no-tty degradation path.

First consumer: Story 2.21 ([#73](https://github.com/amasover/dotfiles/issues/73),
PR #102) — scrub frame filter, display-tool pass-through, flag rejections.
