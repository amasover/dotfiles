# Global instructions (all projects on this machine)

## Root actions: pkexec, never bare sudo

The agent shell has no TTY. Bare `sudo` cannot prompt — and worse, each attempt logs
`pam_unix(sudo:auth): conversation failed`, which **pam_faillock counts as a failed
password attempt**. Three strikes (default `deny=3`) locks Aaron's account for 10
minutes; then even his correct password fails everywhere (sudo, polkit, systemctl)
until `faillock --user aaron --reset`. Proven 2026-07-30.

Rules:

- Never run bare `sudo` from the agent shell. Not even `sudo -n` or `sudo -v` as a
  probe — they still strike faillock.
- **Trap:** `.zshrc` has `alias pacman="sudo pacman"` — plain read-only `pacman -Q`
  from the agent shell becomes a sudo call and strikes faillock. Use
  `command pacman -Q ...` or `/usr/bin/pacman` for queries.
- For an approved root action, use `pkexec /usr/bin/<cmd> ...` — polkit GUI dialog
  pops on Aaron's desktop; his password never transits the agent shell.
- The polkit agent is `lxqt-policykit-agent`; it may not be running. Check with
  `ps -ef | grep lxqt` (pgrep -f self-matches the pgrep wrapper shell — don't trust
  it). Start it with:
  `DISPLAY=:0 XAUTHORITY=/home/aaron/.Xauthority setsid nohup lxqt-policykit-agent >/dev/null 2>&1 &`
  (XAUTHORITY is required; without it the agent dies silently.)
- Warn Aaron a dialog is coming before the pkexec call, use a generous timeout
  (~120–180s), and add non-interactive flags (stdin is still a pipe).
- A failed pkexec dialog auth also strikes faillock — one deliberate attempt, not
  retry loops. If auth fails with the correct password, suspect an active faillock
  lock: check `faillock --user aaron`.
- Root-action approval requirements still apply (see per-project instructions).

## Screenshot token discipline

- `screenshot` without flags captures the full screen. For a specific UI region,
  crop the saved image before `read` so the model receives only that region.
- Use `screenshot -s` only when interactive rectangle selection is possible.
  Otherwise use `magick <full.png> -crop <width>x<height>+<x>+<y> <crop.png>`.
- Read a full-screen image only when whole-screen layout is the question.
