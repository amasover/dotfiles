# ScreenCast portal missing on i3/X11 (kooha can't record)

**Symptom.** Kooha fails immediately on "Start Recording":

```
Failed to start recording
Caused by:
    0: Failed to create session
    1: Failed to call `CreateSession` ...
    2: GDBus.Error:org.freedesktop.DBus.Error.UnknownMethod: No such interface
       “org.freedesktop.portal.ScreenCast” on object at path /org/freedesktop/portal/desktop
```

**Cause.** Not a kooha bug, not a missing PipeWire, not a stale service needing a reboot.
`xdg-desktop-portal` only exposes the interfaces its *selected backend* implements. On this
workstation the only backend running is `xdg-desktop-portal-gtk`, and
`/usr/share/xdg-desktop-portal/portals/gtk.portal` lists no `ScreenCast` — so the interface
does not exist on the bus at all. Verify with:

```bash
busctl --user introspect org.freedesktop.portal.Desktop /org/freedesktop/portal/desktop \
  | grep -E '^org\.freedesktop\.portal'
```

(Observed 2026-08-12: Account, Camera, FileChooser, Settings, … — no ScreenCast, no RemoteDesktop.)

**Why no backend implements it here.** ScreenCast is always compositor-specific. The backends
that implement it talk to a particular compositor's private API:

| Backend | Talks to | Works under i3/X11? |
| --- | --- | --- |
| `xdg-desktop-portal-gnome` | `org.gnome.Mutter.ScreenCast` | No — mutter isn't running |
| `xdg-desktop-portal-kde` | KWin | No |
| `xdg-desktop-portal-wlr` / `-hyprland` / `-cosmic` | wlroots / Hyprland / cosmic-comp | No — Wayland only |
| `xdg-desktop-portal-gtk` | nothing (no ScreenCast at all) | n/a |

There is no generic X11 ScreenCast backend. `xdg-desktop-portal-gnome` *is* installed here (a
`lutris` dependency) but is not selected — its `.portal` file says `UseIn=gnome` while
`XDG_CURRENT_DESKTOP` is empty under i3.

**Do not "fix" it by forcing the gnome backend.** Writing
`~/.config/xdg-desktop-portal/portals.conf` to select `gnome` would make the ScreenCast
interface appear, but every `CreateSession` would then fail against a mutter that isn't
running — and it would simultaneously hijack FileChooser/Settings/Notification for every GTK
app. Trades a clear error for a confusing one.

**Consequence for this repo.** Kooha is unusable on the current i3/X11 session and was dropped
from the metapac `media` group (Story 3.10, [#42](https://github.com/amasover/dotfiles/issues/42)).
The keeper is `gpu-screen-recorder` + `gpu-screen-recorder-ui`, which capture the display
directly and never touch the portal. That grab path is confirmed healthy — plain X11 capture
works fine here, so nothing about the display or PipeWire is broken:

```bash
ffmpeg -f x11grab -video_size 640x480 -i :0.0+0,0 -t 1 -y /tmp/x11grab-test.mp4
```

(2026-08-12: produced a 1.0 s, 54 KB clip.)

**Revisit if the desktop moves to Wayland.** Under sway/Hyprland/COSMIC (Story 3.x window-manager
work, if it ever happens) the matching `xdg-desktop-portal-*` backend supplies ScreenCast and
kooha becomes a real option again — it is a genuinely nicer recorder than SSR. At that point:
re-add `kooha` + the compositor's portal backend to
[`.config/metapac/groups/media.toml`](../../.config/metapac/groups/media.toml), and re-check the
`xdg-desktop-portal-impl` provider pin recorded in that file's header.
