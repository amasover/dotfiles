# vm-harness observability — grill decisions (Story 2.19 design input)

Working decisions from the 2026-07-04 grill session. This becomes the design
input for Story 2.19 (logging + all-in-one command); the story spec in
[epic 2](./epic-2-bootstrap-and-package-modernization.md) will link here.
Vocabulary: [CONTEXT.md](./CONTEXT.md).

## Where output goes today (current state, for reference)

- `install`: guest serial console → `$WORKDIR/install.log` (root-owned once
  qemu writes it; `sudo tail -f` to watch). Nothing on the terminal.
- `bootstrap` / `check`: ssh with a terminal → the invoking terminal only.
  Nothing persists on the host; a closed terminal kills the run.
- archinstall TUI errors: virt-manager console only.

## Decisions

**D1 — Own story.** This is Story 2.19, its own issue and branch off `main`
after PR #61 merges. Not added to the reviewed #61.

**D2 — Logs live in the XDG state dir on the host:**
`~/.local/state/bootstrap-harness/logs/`. They survive `vm-harness destroy`
(the post-mortem of a failed run is the log's main job). `$WORKDIR` stays
fully disposable; `destroy` behavior is unchanged.

**D3 — Quiet is both a flag and an env var.** `--quiet` /
`VM_HARNESS_QUIET=1`, flag wins. Default is tee: stdout and file together.
The dispatch gains a small pre-`case` flag loop (which `--detach` also uses).

**D4 — Keep the terminal colorful; strip the file copy.** Attached runs keep
`ssh -t` (colors, progress bars). The file branch of the tee goes through a
sed filter that strips ANSI escapes and converts carriage returns to newlines
(progress bars appear in the log as repeated plain lines).

**D5 — One log file per phase, timestamped:**
`logs/<YYYYMMDD-HHMMSS>-<phase>.log`. Phases triggered by one all-in-one run
share the run's timestamp prefix so they sort together. A `latest-<phase>.log`
symlink is updated at phase start (gives `tail` a stable target).

**D6 — `vm-harness tail`, three parts:** bare `tail` follows the newest log
via the `latest` symlink; `tail install` sudo-follows the serial log in the
workdir (qemu writes it there; can't move it); `cmd_install` copies the serial
log into the run's state logs on completion so a finished run's output all
sits together under one prefix.

**D7 — Attached vs detached is a flag (`--detach`), not tied to which command
you ran.** Aaron may run the all-in-one attached (watching) or detached
(background, check logs later). Default attached = colors; `--detach` =
survivable, plain output.

**D7a — `--detach` detaches the host-side process.** The harness command
itself keeps running in the background on the host (systemd user manager /
setsid), logging to the state dir; no systemd-run wrapper inside the VM.
Reasoning: the guest-side unit only ever protected against host-side process
death (closed terminal) — a detached host driver fixes that directly, works
identically for `bootstrap`, `check`, and the all-in-one, and if the host
actually dies the VM dies with it, so guest-side survivability buys nothing
extra. Detached mode implies no TTY (plain output), consistent with nobody
watching.

**D8 — Detached-run completion, three parts.** (1) Every phase log ends with
a result line (`=== <phase> done rc=N`) — unconditional, attached or not.
(2) Detached runs fire a desktop notification (`notify-send`) on completion,
success or failure. (3) A thin `vm-harness status` wraps the systemd user
unit's state (`--detach` runs under `systemd-run --user` with a predictable
`vm-harness-*` unit name) plus the last few log lines. No pidfiles or
hand-rolled state.

**D9 — The all-in-one command is `vm-harness up`.** Sequence:
fetch-if-missing → create → install → boot → wait-for-ssh → bootstrap →
check. `fetch` inside `up` only downloads when no ISO is cached (explicit
`vm-harness fetch` stays the force-refresh). If a domain already exists, `up`
dies pointing at `destroy` — it never auto-destroys ("everything but
destroy"; a `--fresh` opt-in can come later if wanted). Composes with the
other decisions: `vm-harness --detach up` is the walk-away form, `--quiet`
works, phases share one run timestamp (D5). "Gold run" stays a separate
term: an `up` executed on a clean committed tree, used as merge evidence.

**D10 — `wait_ssh` closes the boot→bootstrap race.** A helper polls
`ssh -o ConnectTimeout=2 … true` until an authenticated shell succeeds,
bounded at ~2 minutes, then dies clearly. Called at the top of
`cmd_bootstrap` (not just inside `up`) so the manual flow is robust too.
Polling real ssh, not port 22 or the guest agent, because an authenticated
shell is the exact thing the next phase needs.

**D11 — `up` stays dumb on failure.** Stop at the first failing phase
(`set -e`); result line + notification + nonzero exit report it (D8). The VM
is left exactly as it died — inspection matters more than tidiness; cleanup
stays a human `destroy`. No resume logic: bootstrap is re-runnable by design,
so resume-by-hand already works, and acceptance evidence wants the fresh path
anyway. The failure message names the phase, the rc, and the options
(inspect / resume manually / destroy and re-run).

## Implementation deltas (2026-07-05, found while building/first live run)

- **D4 refined:** the raw/scrubbed split happens only when stdout is a
  terminal — a raw tee into a redirected file re-opens the target, truncating
  it and writing at an independent offset (reproduced in a scratch test).
  Pipes and files get the scrubbed stream; colors only render on terminals
  anyway.
- **D6 upgraded (Aaron's ask, first live `up`):** `install` streams the serial
  console to the terminal and into the install phase log, instead of leaving
  the phase dark and copying at the end. The serial file is root:0600
  (virtlogd re-creates it; a 0666 pre-create does not survive — verified
  live), so the stream is `sudo -n tail --pid`, with a `sudo -v` refresh at
  phase start when attended. The `-install-serial.log` copy is now only the
  fallback when sudo wasn't available (e.g. detached without cached
  credentials).

## Parked

- Log retention: none initially; revisit if the directory ever annoys.
- `--fresh` (auto-destroy before `up`): only if typing `destroy` first gets
  old.

*Grill closed 2026-07-04 — all questions resolved (D1–D11). Story 2.19 owns
implementation.*
