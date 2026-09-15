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
| 7 | rEFInd layout | rEFInd lives at `EFI/BOOT` on portable installs, installed with `refind-install --usedefault` per the [ArchWiki removable-medium guide](https://wiki.archlinux.org/title/Install_Arch_Linux_on_a_removable_medium). Dual placement was considered and rejected on that evidence: rEFInd reads its configuration from its own directory, so a managed `EFI/refind/refind.conf` would sit inert while `refind-config` reported convergence — silent divergence between what is managed and what boots. |
| 8 | Boot-menu ownership | `refind-config` learns the portable layout rather than skipping portable installs: ESP discovery by `EFI/BOOT/BOOTX64.EFI`, relocated `STOCK_ICONS` and `refind_dir`, adjusted `BACKUP_PATHS`. The portable install keeps the Nord theme and boot policy instead of becoming the one machine that permanently drifts. Standardising *every* metal install on `EFI/BOOT` was rejected: `refind-config` manages this workstation's live menu, so adopting it would drag a boot-loader migration of the daily driver along with it. |
| 9 | ESP-to-boot safety check | For portable installs, `verify_active_refind_esp`'s firmware-entry binding is replaced by a same-disk binding — the ESP must sit on the disk the running root is on. The original check fails both ways on removable media: booted on a foreign machine the loader path is `\EFI\Boot\BootX64.efi`, and booted here through the internal rEFInd the partition GUID is the internal ESP's. The safety property is preserved in a machine-independent form, not deleted. |
| 10 | NVRAM | Never written by a portable install: `refind-install --no-nvram`. This matches the repo's existing stance recorded in `.config/dotfiles/refind/refind.conf` — "firmware entries stay outside this file; `refind-config` never edits NVRAM". That file's `scanfor internal,external,optical,manual` plus `scan_all_linux_kernels true` already make a portable disk appear in this workstation's existing menu unaided, so no entry is needed for local use either. |
| 11 | Hibernation | Enabled, with a 64 GiB resume ceiling rather than the installing host's RAM. `hibernate-storage` derives the routine swapfile from live `/proc/meminfo` at run time, so only the reserved volume is fixed at install. Two consequences: the recipe's RAM equality check becomes a ceiling check for portable installs, and `hibernate-storage`'s fatal "dedicated resume swap is smaller than physical memory" must degrade to reporting hibernation unavailable rather than failing bootstrap on a machine above the ceiling. |
| 12 | initramfs | `autodetect` is dropped for portable installs, written into `mkinitcpio.conf` before the first image is built rather than repaired afterwards. The ArchWiki's lighter prescription — `block` and `keyboard` moved before `autodetect` — is subsumed by dropping it, and was not adopted separately. `keyboard` in early userspace is not optional on this recipe: without it the LUKS passphrase cannot be typed on an unfamiliar machine. |
| 13 | Volume group name | Derived from `--hostname` for every metal install, fixed and portable alike. The name is a constant today, so plugging a portable disk into any machine this recipe built produces two identically named volume groups; early boot activates the root pool by name, and the internal system may fail to boot. That makes it a latent bug in the fixed path too, not a portable-only concern. |
| 14 | Verification | `metal-rehearsal` gains a portable mode: install under one machine profile, then boot the same disk under a different emulated storage controller with a freshly created OVMF vars file carrying no boot entries. One run proves both load-bearing claims — the `EFI/BOOT` fallback path works with no firmware bookmark, and the initramfs carries drivers for a controller it never saw at install. A different emulated controller is genuinely different hardware, so this is automation that is actually available rather than a proxy for a live check. Story 3 additionally byte-compares the guest's OVMF vars file across an install to prove zero writes outside the target device. |

## Stories

1. **Story 2.56 — metal installer moves to `pacstrap`** ([#253](https://github.com/amasover/dotfiles/issues/253)).
   Engine replacement plus the two fixes that affect every metal install: private
   mountpoint and hostname-derived volume group. Behaviour-preserving for the fixed
   shape. Gate: the existing `metal-rehearsal run` passes unchanged.
2. **Story 2.57 — portable install shape** ([#254](https://github.com/amasover/dotfiles/issues/254)).
   Built by booting the Story 2.55 medium ([#252](https://github.com/amasover/dotfiles/issues/252))
   with the target attached, so no destructive installer runs on a live workstation
   yet. Removable rEFInd layout, no `autodetect`, resume ceiling, `refind-config`
   portable mode, no NVRAM writes. Gate: the two-profile rehearsal.
3. **Story 2.58 — install from a booted workstation** ([#255](https://github.com/amasover/dotfiles/issues/255)).
   The convenience that lets a portable disk be built without rebooting. Gate: OVMF
   vars byte-compare proving zero writes outside the target device.

## Unverified

- `refind-install`'s exact flag spelling for `--usedefault` and `--no-nvram` against
  the installed `refind` package. Cheap to confirm; confirm before building.
- Whether anything outside `finalize_metal` depends on the Archinstall JSON dialect
  for the metal target specifically.
