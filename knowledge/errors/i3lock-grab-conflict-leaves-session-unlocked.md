# i3lock: a busy keyboard grab leaves the session blanked but unlocked

**Seen:** 2026-09-16, Story 3.7 follow-up, i3lock 2.x + xidlehook 0.10.0 on the
laptop.

## Symptom

Return to the laptop and the panel is black, but the session is not locked and
never hibernated. The journal records the failure only when systemd ran the
helper:

```
Sep 15 18:42:19 systemd-lock-handler[1617]: main.go:76: Starting sleep.target
Sep 15 18:42:22 lock[685236]: i3lock: Cannot grab pointer/keyboard
Sep 15 18:42:22 systemd[1598]: locker.service: Main process exited, code=exited, status=1/FAILURE
```

That suspend happened unlocked. The idle path is worse: `xidlehook` runs its
timers from the i3 session, whose stderr is `/dev/tty1`, so the same failure
leaves no trace at all.

## Why

`i3lock` exits non-zero at startup if any other X client already holds the
keyboard/pointer grab — an open rofi, an active i3 binding mode (`$mod`+mode
bindings grab the keyboard), a still-running `i3lock`, a screenshot tool. It
does not wait for the grab.

`tools/lock` fired it exactly once. A single conflict therefore forfeited the
entire idle period: `xidlehook` had already consumed the 5-minute timer and
advanced to the 15-minute DPMS power-off, so the display went dark while the
session stayed unauthenticated — until the 90-minute hard worker hibernated it,
or the user came back to a black, open desktop.

Note what this is *not*: `--not-when-fullscreen` was the first suspect and is
innocent. A live probe with a focused fullscreen window on ws6 fired both an
inhibited and an uninhibited `xidlehook` timer — xidlehook 0.10.0's fullscreen
check did not suppress the callback. The X blank at 3 minutes is also innocent:
`XScreenSaverQueryInfo` shows the idle counter climbing straight through the
blank (184s → 224s, `state=1`), so blanking never resets the idle clock.

## What to do instead

Retry the grab rather than treating one failure as final, and make an exhausted
window audible:

```bash
for _ in $(seq "${LOCK_RETRIES:-12}"); do
    i3lock "${i3lock_args[@]}" -i "$image" && exit 0
    i3-msg -q mode default 2>/dev/null || true   # drop our own likely holder
    sleep "${LOCK_RETRY_DELAY:-10}"
done
logger -t lock "i3lock never got the keyboard grab; session left unlocked"
exit 1
```

Both the idle path (`tools/idle-lock` → `tools/lock`) and the logind path
(`locker.service` → `tools/lock --no-fork`) go through the one helper, so the
retry covers the sleep case as well.

Reproduce it without touching the live session: hold a real grab with
`XGrabKeyboard`/`XGrabPointer` on a nested `Xephyr :9`, then run the helper
against `DISPLAY=:9`. The old helper returns 1 immediately; the retrying one
blocks until the holder releases and then locks.

Related: [epic-3 Story 3.7](../../docs/epic-3-shell-editor-desktop-cleanup.md),
`tests/idle-lock.clitest.txt` (stubbed grab-conflict cases).
