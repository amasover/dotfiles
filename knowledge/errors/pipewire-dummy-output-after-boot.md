# Error pattern: no sound after reboot — PipeWire shows only "Dummy Output"

**Observed:** 2026-07-06, on the daily workstation (Dell Precision 3580, built-in
HDA Intel PCH / ALC3204) after a reboot whose previous boot had no clean-shutdown
record in `last -x`. One occurrence so far; if it recurs, ticket a story.

## Symptom

- GUI mixer shows only **Dummy Output**, no input devices.
- `pactl info` → `Default Sink: auto_null`.
- `wpctl status` → the built-in card appears under Devices, but Sinks lists only
  Dummy Output.
- `pipewire-pulse` journal spams `card NN port N profiles inconsistent (0 < 14)`.

## Mechanism

WirePlumber's boot-time probe of the ALSA card failed once: the live device object
ended up with `EnumProfile: []` and active profile `off`, so no sinks/sources were
created and PipeWire fell back to the `auto_null` dummy sink. The card itself was
healthy the whole time — kernel detected it normally and a direct re-probe found all
profiles. Looks like a one-off boot-time race, not persistent breakage.

## Fast triage (read-only, in order)

```bash
pactl info | grep 'Default Sink'          # auto_null = this pattern
wpctl status                               # device present but no sinks?
aplay -l                                   # kernel/ALSA side: card + PCMs listed?
journalctl -b -k | grep -iE 'snd|sof|hda'  # firmware/codec errors?
spa-acp-tool -c 0 info | head -3           # direct probe: "profiles:29" = card fine
pw-dump <device-id> | grep -A2 EnumProfile # live device: [] = bad probe result
```

If `aplay -l` shows the card and `spa-acp-tool` finds profiles while the live device
has `EnumProfile: []`, the card is fine and WirePlumber just holds a bad probe.

Rule out the other suspects fast: `/var/log/pacman.log` for audio-stack changes
(pipewire/wireplumber/alsa-*/sof-firmware), `fuser -v /dev/snd/*` for a process
hogging the device, `getfacl /dev/snd/pcmC0D0p` for missing logind ACLs, and
`busctl --user list | grep -i reserve` for a stray DBus device reservation (e.g. a
QEMU VM with audio). In the observed case all of these were clean.

## Fix

```bash
systemctl --user restart wireplumber pipewire pipewire-pulse
```

Re-probes the card; sinks/sources reappear within seconds. Running apps (Firefox
tabs etc.) need a refresh/replay to reattach their streams. Restart needs approval
per Hard rule 3.

## Notes

- The usual default device here is a USB headset; when it's unplugged the GUI looks
  extra-empty, but the built-in card should still provide a sink — its absence is
  the actual signal.
- `pacman` is aliased through sudo in the interactive shell; use `/usr/bin/pacman`
  for read-only queries from non-interactive sessions.
