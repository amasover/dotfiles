# `MESA_LOADER_DRIVER_OVERRIDE=i965` forces the whole desktop onto software rendering

**Symptom.** Any OpenGL/EGL app either falls back to llvmpipe or refuses to start. Seen
2026-08-12 via `gsr-ui`:

```
libEGL warning: egl: failed to create dri2 screen
gsr error: your opengl environment is not properly setup. It's using llvmpipe (software
rendering) for opengl instead of your graphics card.
```

and system-wide in `glxinfo -B`:

```
glx: failed to create dri3 screen
failed to load driver: i965
Device: llvmpipe (LLVM 22.1.8, 256 bits)
Accelerated: no
```

**Cause.** `~/.profile` exported `MESA_LOADER_DRIVER_OVERRIDE=i965`. Mesa deleted the classic
i965 driver years ago — `/usr/lib/dri/` has `iris_dri.so` (→ `libdril_dri.so`) and no
`i965_dri.so` at all. The override names a driver that cannot be loaded, so mesa falls back to
llvmpipe on Raptor Lake Iris Xe. The line was presumably added for much older Intel hardware and
outlived it.

Because X is started with `startx` from a login shell, the override was also in the X server's
own environment, which is why `Xorg.0.log` shows:

```
(EE) AIGLX error: dlopen of /usr/lib/dri/i965_dri.so failed
(EE) AIGLX error: unable to load driver i965
```

**Confirming it without changing anything.** Compare the renderer with and without the variable:

```bash
glxinfo -B | grep -E 'Device|Accelerated'                      # llvmpipe / no
env -u MESA_LOADER_DRIVER_OVERRIDE glxinfo -B | grep -E 'Device|Accelerated'
# → Mesa Intel(R) Iris(R) Xe Graphics (RPL-P) / yes
```

**Fix.** Delete the export from `~/.profile`; nothing on this machine needs it. Mesa picks
`iris` correctly on its own. Takes effect for new login shells, so log out of X (or re-`startx`)
to clear it out of the X server's environment too.

**Second, separate problem in the same area.** `xf86-video-intel` (the legacy DDX, last real
release 2.99.917) is installed, and Xorg auto-selects it over the built-in `modesetting` driver
when present. It does not recognise this chipset and gives up on acceleration:

```
(WW) intel(0): Unknown chipset
(EE) intel(0): Failed to submit rendering commands (Invalid argument), disabling acceleration
```

Arch recommends `modesetting` for Gen4+ Intel. Removing `xf86-video-intel` (no xorg.conf.d entry
pins it here) should let Xorg fall back to `modesetting`. That is a root action plus an X
restart — keep it as its own gated step, separate from the `.profile` one-liner.

**Downstream.** This is the real reason screen recording looked broken on this machine, and the
likely origin of the "recording libs broken pending reboot" note in Story 3.10's spec — it was
never about a reboot. With the override out of the way, `gpu-screen-recorder --info` reports
`vendor|intel`, `/dev/dri/card1`, and hardware h264/hevc/vp9. See
[screencast-portal-missing-on-i3-x11.md](./screencast-portal-missing-on-i3-x11.md) for the
separate reason kooha still cannot work here.
