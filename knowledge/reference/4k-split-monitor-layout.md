# 4K docked setup: virtual-monitor split layout (historical reference)

Captured 2026-08-22, when the untracked pre-5.5 autorandr hooks were archived
so the laptop could converge to main (the 5.5 postswitch). This is the record
of how the 4K docking setups were built, for the [Story 3.17](../../docs/epic-3-shell-editor-desktop-cleanup.md#story-317-migrate-monitor-names-after-the-modesetting-driver-switch)
([#129](https://github.com/amasover/dotfiles/issues/129)) rebuild. Do not
extend these hooks as-is — see "Rebuild guidance" below.

## The idea

The 4K monitors run at a **1920x2160 mode** (half horizontal resolution), and
one of them is split into **two stacked 1080p virtual monitors** with
`xrandr --setmonitor`, so i3 and polybar treat the halves as independent
screens. Geometry syntax: `1920/600x1080/170+3840+0` = 1920x1080 px
(600x170 mm physical) at framebuffer offset +3840+0.

Two profiles used it:

- **`4k` (work dock)**: eDP-1 laptop panel at 0x0, DP-1-1 primary 1920x2160
  at 1920x0 (unsplit), DP-1-2 1920x2160 at 3840x0 split into `DP-1-2~1`
  (top) / `DP-1-2~2` (bottom).
- **`home`**: same shape mirrored — DP1-1 was the split one (`DP1-1~1`/`~2`),
  main on DP1-2. (Old pre-3.16 names; this profile predates the rename.)

## Current-name recipe (already dashed, post-3.16)

`~/.screenlayout/4k.sh` — the one asset that already survived the rename:

```sh
xrandr --output eDP-1 --mode 1920x1080 --pos 0x0 \
  --output DP-1-1 --primary --mode 1920x2160 --pos 1920x0 --rotate normal \
  --output DP-1-2 --mode 1920x2160 --pos 3840x0 --rotate normal \
  --output HDMI-1 --off --output HDMI-2 --off --output DP-3 --off --output HDMI-3 --off
xrandr --setmonitor 'DP-1-2~1' 1920/600x1080/170+3840+0 DP-1-2
xrandr --setmonitor 'DP-1-2~2' 1920/600x1080/170+3840+1080 DP-1-2
```

## Historical autorandr hooks (pre-3.16 names — dead since the rename)

Live copies remain untracked on the laptop under `~/.config/autorandr/`
(`4k/`, `home/`, `udev.sh`, and the archived global hook
`postswitch.pre-3.16`). autorandr runs a profile-dir hook *instead of* the
global one, which is the load-bearing trick:

**Global `postswitch`** (ran for every *non-split* profile): deleted all four
possible virtual monitors (`DP1-1~1/2`, `DP1-2~1/2` — they persist across
profile switches and would otherwise be stranded), `sleep 2`, launched
polybar, then re-invoked `autorandr 4k`/`autorandr home` if detected (a
detection recursion hack).

**`4k/postswitch`** (profile hook, replaces the global one):

```bash
xrandr --delmonitor 'DP1-2~1'; xrandr --delmonitor 'DP1-2~2'
xrandr --setmonitor 'DP1-2~1' 1920/600x1080/170+3840+0 DP1-2
xrandr --setmonitor 'DP1-2~2' 1920/600x1080/170+3840+1080 DP1-2
sleep 2
~/.config/polybar/launch.sh &>/dev/null & disown
i3-msg '[workspace="1: <glyph>"]' move workspace to output "DP1-1"
i3-msg '[workspace="2: <glyph>"]' move workspace to output "DP1-2~2"
i3-msg '[workspace="5: <glyph>"]' move workspace to output "DP1-2~1"
i3-msg '[workspace="3: <glyph>"]' move workspace to output "DP1-2~1"
i3-msg workspace "3: <glyph>"; i3-msg workspace "1: <glyph>"
```

**`home/postswitch`**: identical shape with DP1-1 split
(`DP1-1~1` top / `DP1-1~2` bottom at +3840+0/+3840+1080), workspaces:
1 → DP1-2 (main), 2 → DP1-1~2, 3+5 → DP1-1~1.

**`udev.sh`**: `autorandr --detected | grep 4k → autorandr 4k`, else
`autorandr --change` — the detection entry point.

## Rebuild guidance (3.17)

1. `setmonitor` stays in per-profile hooks; the split geometry above is the
   spec. Re-save the autorandr profiles under dashed names first.
2. Cleanup should be generic — delete every `xrandr --listmonitors` entry
   whose name contains `~` — never a hardcoded name list (that is exactly
   what the 3.16 rename killed).
3. Polybar roles for splits go through the 5.5 launcher's
   `layouts/<profile>.env` override files (`MONITOR_SPLIT_TOP/BOTTOM`), not
   hook-managed polybar launches; the i3 workspace placement stays
   per-profile.
4. No auto-apply recursion in postswitch — detection belongs to `udev.sh`
   (`autorandr --change`). The `sleep 2`s predate the 5.5 flock and go away.
