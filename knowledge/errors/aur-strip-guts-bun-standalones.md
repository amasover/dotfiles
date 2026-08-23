# AUR/makepkg `strip` guts bun-compiled standalone binaries

**Seen:** 2026-08-23, meridian 1.62.6-1 (AUR) — its bundled
`node_modules/@anthropic-ai/claude-code/bin/claude.exe`.

## Symptom

A bun-compiled standalone (a ~250MB ELF that should run the embedded app)
behaves as the **bare bun runtime** instead:

```
$ claude.exe --version
1.4.0                            # bun's version, not the app's
$ claude.exe --model X -p "hi"
error: Script not found "X"      # bun treating app flags as a script path
```

Downstream this surfaced as: omp → meridian → SDK spawns claude.exe → exit 1
→ meridian reports "authentication_error: Claude Code process exited (code
1)". Auth was never involved — the loop that cracked it was running the
bundled binary directly in a `systemd-run --user` shell vs interactively
(same bare-bun behavior everywhere → not an environment problem).

## Cause

bun standalone executables carry the embedded app bundle in a trailer the
ELF tooling doesn't understand. makepkg's default `strip` option rewrites
the binary and discards it — leaving a functional bun runtime with no app.
(Same class of breakage hits deno/pkg self-contained binaries.)

## Fixes

- Consumer-side (what we did): point the consumer at a working binary —
  meridian honors `MERIDIAN_CLAUDE_PATH`; the unit sets it to
  `/usr/bin/claude` (the `claude-code` package's own entry point).
- Packaging-side (for our vendored PKGBUILDs, Story 2.46): any package that
  ships a bun/deno/pkg standalone needs `options=(!strip)` (or an explicit
  `strip` exclusion for those files). Worth checking before vendoring one.
- Upstream: the meridian AUR package could carry the same fix — flag it if
  the bundled-binary path ever needs to work.

Related: [epic-3 Story 3.24](../../docs/epic-3-shell-editor-desktop-cleanup.md#story-324-meridian-harness--claude-subscription-proxy-as-a-user-service-omp-wired-through-it).
