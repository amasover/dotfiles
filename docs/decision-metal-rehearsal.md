# Decision: metal rehearsal harness, `install-on-metal`, `provision-seed`

Story: [2.53](./epic-2-bootstrap-and-package-modernization.md#story-253-metal-rehearsal-harness-install-on-metal-front-door-provision-seed-rename)
([#247](https://github.com/amasover/dotfiles/issues/247)). Grilled 2026-09-12;
[#240](https://github.com/amasover/dotfiles/pull/240) merged 2026-09-13.

## Why

The first VM run of Story 2.29's metal recipe (PR #240) installed, booted, and
logged in, then failed the runbook's first-bootstrap handoff four separate ways:
`genfstab -f /mnt` never persisted the resume LV, Archinstall's HOOKS carried no
`resume` hook, `refind-theme-nord`'s install hook mounted the ESP a second time,
and the theme it copied onto the ESP carried no ownership marker. The unit suites
were green throughout. Proving the fixes took about 40 minutes of manual console
driving. That proof needs to be one command with an exit code.

## Decisions

| # | Question | Decision |
| --- | --- | --- |
| 1 | Attended prompts (`WIPE <device>`, user password, LUKS password) | Answered host-side by driving the guest's serial pty (expect-style). The guest-side `run-install.sh` and `provision-seed` stay byte-identical to what runs on the laptop. No `--yes` flag, no environment bypass, anywhere: a confirmation bypass that exists is one that eventually reaches real hardware. |
| 2 | VM plumbing | Raw user-owned `qemu-system-x86_64`: q35, KVM, OVMF pflash, virtio qcow2, SLIRP with a localhost SSH forward, serial on a pty, QEMU monitor for `screendump` and `sendkey`. No sudo, no libvirt. `vm-harness` stays the unattended cloud-init harness; its libvirt shape does not fit an attended install. |
| 3 | Pass criterion | Install and finalize; first boot through rEFInd, LUKS unlock, login; in-guest prerequisites; `refind-config audit`, `apply`, `--check`; `hibernate-storage apply`, `--check`; second `refind-config apply`; reboot; both checks converged; `CanHibernate` returns `yes`; then a real `systemctl hibernate`, QEMU relaunch, unlock, and resume assertion. This is exactly the sequence that caught the four bugs, plus the one proof the initramfs fix otherwise lacks. |
| 4 | Code under test | The host working tree (tracked files at HEAD plus uncommitted edits), transferred into the ISO tmpfs and later into the installed guest. Rehearsal must gate a commit before it is pushed. |
| 5 | Guest prerequisites | The rehearsal script owns them over SSH as a labelled stand-in for bootstrap step 9: `pacman -Syu intel-ucode python polkit`, AUR `makepkg` of `refind-theme-nord`, then the runbook sequence. Full bootstrap is rejected: every class carries the same 15 common purpose groups, an hour or more per run. |
| 6 | Generator name | `vm-harness-seed` becomes `provision-seed`. It is a recipe printer for four targets (`qemu`, `vmware`, `daily-vm`, `metal`) with no hypervisor code, and the copy it embeds in the metal recipe is already called `provision-seed`. `--target` stays: it is the only thing selecting the recipe. |
| 7 | Metal front door | New `install-on-metal <device> --hostname <name> [--user aaron]`. Derives disk GiB and rounded RAM from live hardware, echoes them, calls `provision-seed create --target metal`, runs `run-install.sh`. The runbook's USB section becomes clone plus one command. |
| 8 | Rehearsal command | `.local/bin/setup/metal-rehearsal`, Python. Subcommands `run` and `destroy`. Python for pty/select expect, monitor control, and a prompt matcher unit-tested through `conftest.load_tool`. |
| 9 | Artifacts | `~/.cache/bootstrap-harness/metal-rehearsal/<timestamp>/`: qcow2, OVMF vars, serial logs, screendumps. Deleted on pass; kept on failure with the stage name and path printed; `--keep` overrides. Never under `/tmp` (tmpfs). |
| 10 | CI | Local integration test, not a GitHub job: 15 minutes, a 1.2 GB ISO, package and AUR downloads, nested KVM on hosted runners. Exit 0 pass, nonzero with the failing stage. Run before pushing changes to `provision-seed`, `refind-config`, or `hibernate-storage`. A `workflow_dispatch` job may come later; never in Validate. |
| 11 | Packaging | One PR branched from `main` after #240 merges, targeting `main`: three new files, generator/caller renames, runbook edits, and the rehearsal evidence. |

## Files

New: `.local/bin/setup/metal-rehearsal`, `.local/bin/setup/install-on-metal`
(runs on the Arch ISO, so only ISO-available tools), `tests/test_metal_rehearsal.py`
(prompt matcher, stage sequencing, artifact policy; no QEMU).

Generator callers now use `provision-seed`: `vm-harness` (`SEED_TOOL`),
`vm-harness-vmware.ps1` (`$SeedTool`), `runbook-fresh-machine-bootstrap.md`,
`runbook-vm-validation.md`, `tests/vm-harness.clitest.txt`,
`tests/test_provision_seed.py` (`load_tool`), `.gitattributes`, and argparse `prog`.

Runbook edits: the USB section shrinks to clone plus `install-on-metal`; a new
"Rehearse the metal path in a VM" subsection states what pass means, where
artifacts land, and when to run it.

## Rehearsal stages

Each stage is a named failure point with its own timeout. On failure: stage name,
last 40 serial lines, artifact path.

1. **host-preflight**: `qemu-system-x86_64`, `qemu-img`, `bsdtar`, writable
   `/dev/kvm`, OVMF code and vars, 10 GiB free under the artifact root, cached ISO
   with a verified sha256 (reuse `vm-harness fetch`'s cache; run it if missing).
2. **prepare**: artifact directory, 63 GiB qcow2 (the generator's minimum for an
   8 GiB guest), fresh OVMF vars copy, ISO kernel and initrd extracted, ISO uuid
   read from `boot/*.uuid`, host tree tarred, localhost-only HTTP server the guest
   reaches at `10.0.2.2`.
3. **installer-boot**: direct kernel boot with `console=ttyS0`; expect `login:`;
   send `root`.
4. **install**: `unsetopt correct`; fetch the tree to `/run/dotfiles`;
   `install-on-metal /dev/vda --hostname metal-test`; answer the `WIPE /dev/vda`
   prompt and the four password prompts with per-run random throwaway values;
   expect `install complete` (fail on `archinstall failed rc=`); `systemctl
   poweroff`; wait for QEMU exit.
5. **first-boot**: relaunch without the ISO (`-display none`, monitor on stdio,
   serial to file, SSH hostfwd); after the rEFInd timeout plus a grace period send
   the LUKS passphrase with `sendkey`; poll the SSH port; save a menu screendump.
6. **handoff**: SSH as the user through the same expect machinery, `sudo -i`,
   prerequisites, tree to `/root/dotfiles`, the runbook sequence with `RC=`
   markers; assert converged, the swap layout, and `resume=` in
   `refind_linux.conf`.
7. **reboot-proof**: `systemctl reboot`, relaunch, unlock, SSH; assert
   `/proc/cmdline` carries `resume=UUID=`, both checks converged, `CanHibernate`
   is `yes`; save the Nord menu screendump.
8. **hibernate-proof**: write a marker under `/dev/shm`, `systemctl hibernate`,
   wait for QEMU exit, relaunch, unlock, SSH; assert the marker survived and the
   journal shows the hibernation exit.
9. **teardown**: poweroff; delete artifacts on pass unless `--keep`.

## Implementation details

- Throwaway credentials are random per run; retained runs store them mode 0600
  in the mode-0700 artifact directory so the disk can still be unlocked.
- `install-on-metal` uses ISO-available Python and standard-library code. It
  prints floor disk GiB and ceiling RAM GiB, creates the recipe under `/run`,
  and execs the unchanged attended driver.
- The prompt matcher handles fragmented ANSI/OSC terminal controls as well as
  fragmented prompts. A real PTY credential exchange tests the generator's
  attended protocol without a VM or confirmation bypass.
- A lock prevents `destroy` from removing a live run. QEMU inherits that lock
  so an interrupted host parent cannot make its active disk look disposable.
