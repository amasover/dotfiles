# rEFInd `also_scan_dirs +,@/dir` scans a literal `@` directory, not the rEFInd volume

**Seen:** 2026-09-11, workstation. `refind-config adopt` generated
`also_scan_dirs +,@/arch`, the next reboot showed no Arch entry in rEFInd, and
the machine had to be recovered from a rescue stick.

## Symptom

rEFInd boots, shows other volumes (Ubuntu's grub, a rescue USB), but the Arch
kernel that lives in a subdirectory of a non-ESP boot partition is missing
from the menu. No error is shown; rEFInd silently ignores scan directories
that do not exist.

## Cause

rEFInd's default `also_scan_dirs` is `boot,@/boot`. The `@` is not a token for
"the volume rEFInd launched from". It is the literal name of the Btrfs root
subvolume Ubuntu uses, added in rEFInd 0.11.x so kernels under `/@/boot` on
Btrfs volumes are found (NEWS.txt: "Added '@/boot' to default also_scan_dirs
setting. This makes kernels show up on Btrfs volumes under Ubuntu"). Every
`also_scan_dirs` entry is a directory path relative to each scanned volume's
root, optionally prefixed with `volname:`. So `@/arch` looks for a directory
named `@` containing `arch`, which exists nowhere.

## Fix

Emit the directory relative to the volume root with no prefix:
`also_scan_dirs +,arch`. rEFInd scans it on every volume it can read (the
ext4 driver covers the boot partition) and reads options from the
`refind_linux.conf` next to the kernel. `refind-config` renders it that way
since PR for #230's follow-up; `tests/test_refind_config.py` asserts no `@`
appears.

## Lessons

- A generated boot-menu change is not validated until the reboot in the
  runbook's attended-adoption step has happened. `--check` converging only
  proves the files match the generator.
- Keep a rescue stick that rEFInd can boot; its `/boot` is found by the
  default `boot` scan, which is what made recovery possible.
- Sibling OS kernels on the same boot partition (Ubuntu here) need a manual
  stanza: auto-scan cannot know their root device. `refind-config` generates
  one from the machine-local `dual_boot` input and derives the volume from the
  `/boot` mount.
