# Decision: metal installer engine and portable install shape

Stories: [2.56](https://github.com/amasover/dotfiles/issues/253),
[2.57](https://github.com/amasover/dotfiles/issues/254),
[2.58](https://github.com/amasover/dotfiles/issues/255); install medium
[2.55](https://github.com/amasover/dotfiles/issues/252). Grilled 2026-09-15 against
the working tree; no PR yet.

## Why

`install-on-metal` serves exactly one shape today: an attended install onto a blank
laptop's internal disk, run from the Arch ISO booted on that same machine. Two cases
now need serving — a persistent Arch system on an external USB SSD, bootable on any
UEFI machine, and the existing internal-disk install from the Story 2.55 medium. The
second already works unchanged. The first collides with assumptions spread across
`provision-seed`, `refind-config`, and `hibernate-storage` that were all correct
while every install was fixed to one machine.

Grilling the portable shape surfaced a second, larger finding: nearly every decision
below was awkward to express through Archinstall and direct to express without it.
`finalize_metal` already exists only to repair Archinstall's output — the unpersisted
resume swap, the missing `resume` hook, the unmarked theme copy — and each new
portable requirement lengthened that repair list. The engine change is therefore
recorded here, and sequenced first.

## Decisions

| # | Question | Decision |
| --- | --- | --- |
| 1 | Scope of "portable" | Install-time portability only: the target reaches a login prompt on any UEFI x86_64 machine. Fitting the chassis it happens to run on — graphics, microcode, power — stays the machine class's job (Story 2.30) and earns its own story. The metal recipe installs only `lvm2` plus `linux-firmware`, so the installer's reach stops well short of runtime hardware regardless. |
| 2 | Installer engine | The metal path moves from Archinstall to `pacstrap`. Archinstall keeps the disposable QEMU/VMware/daily-VM targets, where unattended throwaway installs are what it is good at. The metal recipe had already diverged: its own layout builder, its own driver template, its own preflight, its own repair pass, and `--files-only` bypassing the seed machinery entirely. What remained shared was the Archinstall JSON dialect and its version skew. No escape hatch is lost: `archinstall 4.4-1` ships on the stock Arch ISO, so the Story 2.55 medium still carries it for ad-hoc manual use. |
| 3 | Sequencing | Three stories, ordered by blast radius — see [Stories](#stories). Doing the engine change and the new shape together would leave a failed rehearsal with two candidate causes, the situation Story 2.53 exists to prevent. Installing from a booted workstation is separable from the portable shape and is the riskiest capability here, so it lands last and alone, against a baseline already known good. |
| 4 | Tool structure | `install-on-metal` absorbs the installer and the `metal-preflight`, `metal-credentials`, and `metal-finalize` subcommands, which are already metal-namespaced and used by nothing else. `provision-seed` returns to being a pure Archinstall recipe printer for the three VM targets — the role Story 2.53 defined for it, which a destructive block-device installer inside it would contradict. The driver embeds `install-on-metal` rather than `provision-seed`; metal tests move with the code. |
| 5 | Selecting portable | A flag on `install-on-metal`, not a `provision-seed --target`. The target registry is an Archinstall construct; once metal leaves that tool, there is no registry for it to be a member of. |
| 6 | Target mountpoint | The installer mounts the target at a private path it chooses, never `/mnt`. On a booted workstation `/mnt` may already carry the machine's own boot filesystem, its ESP, and an autofs automount root, so it is not available to an installer running from a live host. With `pacstrap` this is a direct choice rather than a flag threaded through three layers. |
| 7 | rEFInd layout | rEFInd lives at `EFI/BOOT` on portable installs, installed with `refind-install --usedefault <esp-device>` per the [ArchWiki removable-medium guide](https://wiki.archlinux.org/title/Install_Arch_Linux_on_a_removable_medium). Dual placement was considered and rejected on that evidence: rEFInd reads its configuration from its own directory, so a managed `EFI/refind/refind.conf` would sit inert while `refind-config` reported convergence — silent divergence between what is managed and what boots. Verified against `refind` 0.14.2-3: `--usedefault` takes the ESP *device* and mounts it itself, and is mutually exclusive with `--root` (`refind-install:190-193`), so the installer must not reach for a chroot-style invocation. `--alldrivers` is available only under `--usedefault` and is deliberately not used: the recipe mounts the ESP at `/boot`, so rEFInd reads the kernel from FAT with no filesystem driver. |
| 8 | Boot-menu ownership | `refind-config` learns the portable layout rather than skipping portable installs: ESP discovery by `EFI/BOOT/BOOTX64.EFI`, relocated `STOCK_ICONS` and `refind_dir`, adjusted `BACKUP_PATHS`. The portable install keeps the Nord theme and boot policy instead of becoming the one machine that permanently drifts. Standardising *every* metal install on `EFI/BOOT` was rejected: `refind-config` manages this workstation's live menu, so adopting it would drag a boot-loader migration of the daily driver along with it. |
| 9 | ESP-to-boot safety check | For portable installs, `verify_active_refind_esp`'s firmware-entry binding is replaced by a same-disk binding — the ESP must sit on the disk the running root is on. The original check fails both ways on removable media: booted on a foreign machine the loader path is `\EFI\Boot\BootX64.efi`, and booted here through the internal rEFInd the partition GUID is the internal ESP's. The safety property is preserved in a machine-independent form, not deleted. |
| 10 | NVRAM | Never written by a portable install. There is no `--no-nvram` flag and none is needed: `refind-install` calls `AddBootEntry` only when the target directory is neither `EFI/BOOT` nor `EFI/Microsoft/Boot` (`refind-install:1476-1479`), so `--usedefault` abstains structurally rather than by opt-in. The same branch also suppresses `GenerateRefindLinuxConf`, so the installer must write `refind_linux.conf` itself — `finalize_metal` requires that file to exist and raises "metal handoff destination is missing" without it. This matches the repo's existing stance recorded in `.config/dotfiles/refind/refind.conf` — "firmware entries stay outside this file; `refind-config` never edits NVRAM". That file's `scanfor internal,external,optical,manual` plus `scan_all_linux_kernels true` already make a portable disk appear in this workstation's existing menu unaided, so no entry is needed for local use either. |
| 11 | Hibernation | Enabled, with a 64 GiB resume ceiling rather than the installing host's RAM. `hibernate-storage` derives the routine swapfile from live `/proc/meminfo` at run time, so only the reserved volume is fixed at install. Two consequences: the recipe's RAM equality check becomes a ceiling check for portable installs, and `hibernate-storage`'s fatal "dedicated resume swap is smaller than physical memory" must degrade to reporting hibernation unavailable rather than failing bootstrap on a machine above the ceiling. |
| 12 | initramfs | `autodetect` is dropped for portable installs, written into `mkinitcpio.conf` before the first image is built rather than repaired afterwards. The ArchWiki's lighter prescription — `block` and `keyboard` moved before `autodetect` — is subsumed by dropping it, and was not adopted separately. `keyboard` in early userspace is not optional on this recipe: without it the LUKS passphrase cannot be typed on an unfamiliar machine. |
| 13 | Volume group name | Derived from `--hostname` for every metal install, fixed and portable alike. The name is a constant today, so plugging a portable disk into any machine this recipe built produces two identically named volume groups; early boot activates the root pool by name, and the internal system may fail to boot. That makes it a latent bug in the fixed path too, not a portable-only concern. |
| 14 | Verification | `metal-rehearsal` gains a portable mode: install under one machine profile, then boot the same disk under a different emulated storage controller with a freshly created OVMF vars file carrying no boot entries. One run proves both load-bearing claims — the `EFI/BOOT` fallback path works with no firmware bookmark, and the initramfs carries drivers for a controller it never saw at install. A different emulated controller is genuinely different hardware, so this is automation that is actually available rather than a proxy for a live check. Story 3 additionally byte-compares the guest's OVMF vars file across an install to prove zero writes outside the target device. |

## Amendment: systemd initramfs (2026-09-15)

Decision 12 above chose the udev chain, and Story 2.56 hardened that into a guard
refusing a systemd array. Reviewing the ArchWiki hook list afterwards reversed the
call: the repository adopts the initramfs Arch actually ships rather than pinning
against it. Recorded as [Story 2.59](./epic-2-bootstrap-and-package-modernization.md#story-259-systemd-initramfs-and-a-tracked-hooks-policy),
sequenced after 2.56 and before 2.57, because the portable shape's hook decisions
rest on which chain it is built from.

| # | Question | Decision |
| --- | --- | --- |
| 15 | Initramfs flavour | systemd, on every machine this repository provisions and on the existing workstation. Arch's packaged default has been systemd-based since `mkinitcpio` 40-1 (2025-11-04). Upstream's build-time default is still udev, but `mkinitcpio` is an Arch project — the meson option exists for other distributions, so it is weak evidence of direction and the packaging flip is the stronger signal. The concrete payoff is that TPM2/FIDO2 unlock and UKIs (Story 2.44) stop requiring a second boot-chain migration later. |
| 16 | Hook translation | `udev` becomes `systemd`; `encrypt` becomes `sd-encrypt`; `keymap` and `consolefont` become `sd-vconsole`; `resume` is dropped outright. `mkinitcpio -H systemd` states the hook replaces `base`, `usr`, `udev` and `resume`, and a systemd initramfs runs no runtime hooks at all — so a retained `resume` hook would be inert rather than harmless. `lvm2` stays: it installs no runtime script and works through the udev rules systemd runs. |
| 17 | Rescue shell | Kept deliberately, not inherited away. `base` stays ahead of `systemd`, and `SYSTEMD_SULOGIN_FORCE=1` goes on the kernel command line; without it sulogin refuses because the root account is locked, which is verbatim what Story 2.56's failed boot printed. The parameter appears in no manpage — it is read from the command line by `/usr/lib/systemd/systemd-sulogin-shell`, which is its only authority. |
| 18 | Kernel command line | `cryptdevice=UUID=<uuid>:<name>` becomes `rd.luks.name=<uuid>=<name>`, which `systemd-cryptsetup-generator(8)` documents as implying `rd.luks.uuid=`. `resume=UUID=` is unchanged: `systemd-hibernate-resume-generator(8)` consumes the same parameter. No change is needed in `refind-config` — its `IDENTITY_KEYS` already whitelists `rd.luks.uuid`, `rd.luks.name`, and `rd.lvm.lv`, and its audit already reports `crypt=yes` for them. |
| 19 | Migration ordering | The `refind_linux.conf` rewrite, the initramfs rebuild, and the reboot are one step. `refind-config` derives identity from the *running* kernel and writes it back, so an `apply` between the rewrite and the reboot silently reverts the new command line to the old one. A known-good initramfs and a rEFInd entry that boots it exist before the reboot, and the sequence passes in `metal-rehearsal` before any live machine is touched. |
| 20 | HOOKS ownership | Tracked policy, as a drop-in under `/etc/mkinitcpio.conf.d/` rather than the file itself. `mkinitcpio` concatenates the main configuration and appends drop-ins in version-sorted order before sourcing once, so the drop-in's `HOOKS` wins and pacman keeps owning the base file — no `.pacnew` merge is ever required for boot policy. Tracking the whole file was rejected on that basis, and because it would drag hardware-specific `MODULES` into shared policy. The bootstrap seam already exists for autofs maps, the reflector policy, and the pacman gate hook: tracked file, symlinked into `/etc`, with a `--check` dry-run. |
| 21 | What stays machine-local | `MODULES`. Hardware modules belong to the machine class and its hardware adapter (Story 2.30). This workstation is the argument: it has carried `MODULES=(amdgpu radeon)` on Intel hardware, plus a duplicate `modconf`, since 2022 — drift that went unnoticed precisely because nothing owned the file. |

Checked rather than assumed, after Story 2.56 shipped a `--no-nvram` flag into this
document that does not exist: the drop-in concatenation order and its `_optconfd`
opt-out (`/usr/bin/mkinitcpio:1120-1134`); that this machine's preset leaves
`ALL_config` commented out, so drop-ins do load; `rd.luks.name=` syntax and
`resume=` handling in the systemd generator manpages; and `SYSTEMD_SULOGIN_FORCE`
in the `systemd-sulogin-shell` binary.

## Stories

1. **Story 2.56 — metal installer moves to `pacstrap`** ([#253](https://github.com/amasover/dotfiles/issues/253)).
   Engine replacement plus the two fixes that affect every metal install: private
   mountpoint and hostname-derived volume group. Behaviour-preserving for the fixed
   shape. Gate: `metal-rehearsal run` passes with no change beyond its installer
   sentinel — the harness greps the driver's own echo strings, so the new driver
   keeps emitting `metal-provision: install complete` and an equivalent failure line
   to hold that diff to one pattern pair.
2. **Story 2.57 — portable install shape** ([#254](https://github.com/amasover/dotfiles/issues/254)).
   Built by booting the Story 2.55 medium ([#252](https://github.com/amasover/dotfiles/issues/252))
   with the target attached, so no destructive installer runs on a live workstation
   yet. Removable rEFInd layout, no `autodetect`, resume ceiling, `refind-config`
   portable mode, no NVRAM writes. Gate: the two-profile rehearsal.
3. **Story 2.58 — install from a booted workstation** ([#255](https://github.com/amasover/dotfiles/issues/255)).
   The convenience that lets a portable disk be built without rebooting. Gate: OVMF
   vars byte-compare proving zero writes outside the target device.

## Archinstall coupling outside `finalize_metal`

Surveyed 2026-09-15. Three places, and the weight sits in the second:

- `metal-rehearsal:390-396` greps `archinstall failed rc=\d+` as its failure
  sentinel. The coupling is to the driver's echo strings, not to Archinstall itself,
  so it is one pattern pair — see the Story 2.56 gate above.
- `tests/test_provision_seed.py` asserts the Archinstall JSON dialect directly:
  `bootloader_config.bootloader == "Refind"`, `encryption_type == "lvm_on_luks"`,
  the partition structures, and `swap.enabled`. These pin the shape of a config file
  the metal path will no longer produce, so they are deleted and replaced with
  assertions about the layout the installer actually creates — not ported. This is
  the bulk of Story 2.56.
- `tests/vm-harness.clitest.txt` drives `provision-seed create --target metal` and
  stubs `provision-seed` subcommands by name in two cases; both move to a metal
  clitest keyed on `install-on-metal`.

Dialect-independent and portable as-is: `validate_metal_facts`,
`write_metal_credentials`, `require_wipe_confirmation`, and `metal_layout_gib`.
