# 4K split layout: virtual monitors carved with xrandr --setmonitor

Captured 2026-08-22, when the untracked pre-5.5 autorandr hooks were archived
so the laptop could converge to main (the 5.5 postswitch). The history below
records how the 4K docking setups were built, for the [Story 3.17](../../docs/epic-3-shell-editor-desktop-cleanup.md#story-317-migrate-monitor-names-after-the-modesetting-driver-switch-)
([#129](https://github.com/amasover/dotfiles/issues/129)) rebuild. That story
closed 2026-11-02 when the laptop retired. Since then the home split lives on
as the work VM's layout ([Story 5.8](../../docs/epic-5-guest-daily-driver.md#story-58-the-mac-work-vm-is-the-daily-driver)):
see "Current mechanism" first.

## Current mechanism (Story 5.8)

One 3840x2160 canvas is cut into the home areas: left 1920x2160 main, right
1920x1080 top, right 1920x1080 bottom. Workspaces: 1 → main, 2 → bottom,
3 and 5 → top, then `workspace number 3; workspace number 1`.

- **The one definition:** `.config/monitor-split/home.layout` (`canvas`,
  `area NAME WxH+X+Y ROLE`, `workspaces AREA N...`, `focus N...`).
- **The one helper:** `.local/bin/tools/monitor-split`. `apply LAYOUT
  OUTPUT...` carves the layout across outputs whose bounding box is the
  canvas. An area that exactly covers an output stays that output. Every
  other area becomes `OUTPUT~N`, numbered per output in layout order; the
  first carved monitor owns the output, the rest take `none`. Stale `~`
  monitors are deleted first, as `preswitch.d/10-clear-virtual-monitors`
  does. An identical split already in place is a no-op, so the workspace
  map only replays when the monitors are (re)created.
- **Work VM (one cable):** Fusion's "Use All Displays in Full Screen"
  presents the 4K as one `Virtual-1` at 3840x2160 next to the Mac panel
  `Virtual-2`. `tools/vm-autofit` places the outputs from vmwgfx's
  `suggested X/Y`, then runs `monitor-split auto`. That splits the first
  output matched by `~/.config/monitor-split/policy` whose size equals the
  canvas, into `Virtual-1~1` (main), `~2` (top) and `~3` (bottom). Any other
  topology (windowed, undocked) clears the split. The split names are part
  of vm-autofit's topology key, so polybar relaunches when the split appears
  or goes away.
- **Opt-in:** the policy is the yadm alternate
  `.config/monitor-split/policy##class.work-vm`, so only class `work-vm`
  gets `~/.config/monitor-split/policy`. Without that file, `auto` and
  `roles` exit before querying anything, and every other machine behaves as
  before. Another machine opts in by adding its own
  `policy##class.<name>` (lines are `LAYOUT OUTPUT-GLOB`).
- **Polybar:** `monitor-roles resolve` takes `monitor-split roles` as pinned
  roles (MAIN, SPLIT_TOP, SPLIT_BOTTOM from the layout's role column, only
  while the split is in place). The heuristic fills the remaining roles
  around the pinned MAIN, so the panel left of the 4K becomes LEFT and a
  later second 4K becomes EXTRA. No autorandr profile or `.env` is involved.
- **Two-cable home (future personal laptop):**
  `.config/autorandr/home/postswitch.d/10-split-monitor` runs
  `monitor-split apply home DP-1-2 DP-1-1`. DP-1-2 stays whole as main;
  DP-1-1 becomes `DP-1-1~1`/`~2`. Polybar roles still come from
  `layouts/home.env`.
- **Physical size:** a carved area gets the output's millimetres in
  proportion (600x340mm per 1920x2160 input gives the historical
  `1920/600x1080/170`). VMware outputs report 0mm x 0mm, so their areas get
  96-DPI sizes (`px * 25.4 / 96`, e.g. `1920/508x1080/286`). That is what
  Xorg lists for the unsplit 0mm output, so anything deriving DPI from the
  monitor size sees no change. Polybar and i3 do not read it.

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

## Current-name recipe (pre-5.8, two cables)

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

1. Re-save each autorandr profile under dashed names while its physical monitors
   are connected. Never synthesize a new fingerprint by renaming stale setup
   keys.
2. Cleanup is global and generic: `preswitch.d/10-clear-virtual-monitors`
   deletes every `xrandr --listmonitors` name containing `~`, never a hardcoded
   connector list.
3. Recreate splits and place i3 workspaces from a profile-specific
   `postswitch.d` script. A uniquely named `.d` hook runs before the global
   `postswitch`; a profile-level `postswitch` would shadow the global Polybar
   relaunch.
4. Polybar roles for splits come from `layouts/<profile>.env`
   (`MONITOR_SPLIT_TOP/BOTTOM`), not hook-managed bar commands.
5. Do not restore the old `udev.sh` detection recursion or either `sleep 2`.
   The packaged DRM hotplug rule runs `autorandr --batch --change`, i3 runs
   `autorandr --change --force` at session start, and the launcher flock
   serializes concurrent relaunches.
