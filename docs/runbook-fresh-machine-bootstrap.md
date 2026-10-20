# Runbook: fresh-machine bootstrap

Evidence artifact for Story 2.3 ([#25](https://github.com/amasover/dotfiles/issues/25)).
Design: [decision-bootstrap-architecture.md](./decision-bootstrap-architecture.md).
Script: [`.local/bin/setup/bootstrap`](../.local/bin/setup/bootstrap) (replaces the
retired 2019 `setup/install` — see [bootstrap-inventory.md](./bootstrap-inventory.md)
for its autopsy; history via `git log -- .local/bin/setup/install`).

> **DAILY-VM FIRST:** Story 2.29's primary evidence remains a real encrypted
> daily-driver creation run under VMware Workstation. The shared generator now
> exposes that LUKS recipe as `--target daily-vm`; the attended metal path below
> is the later hardware revalidation, not a replacement for the VM evidence.

> **METAL SCOPE:** Story 2.29 erases one explicitly named whole disk on a
> different, blank laptop. The current workstation is never its target. The generated
> metal recipe does not start automatically and cannot proceed without matching disk,
> RAM, mount-state, console, and typed-wipe checks.

## Provision the different laptop from the Arch ISO

Boot the official Arch ISO in UEFI mode, bring up networking, then work from its root
shell. Identify the target from live hardware; never copy the current workstation's
device name or partition sizes:

```bash
device=/dev/nvme0n1                 # replace after inspecting lsblk
lsblk -d -o PATH,SIZE,MODEL,SERIAL
```

Fetch this repository into the ISO's tmpfs, then run the attended front door. It
prints disk GiB and rounded RAM derived from live hardware; no second seed medium
or `pycdlib` is needed:

```bash
pacman -Sy --needed git
git clone https://github.com/amasover/dotfiles.git /run/dotfiles
/run/dotfiles/.local/bin/setup/install-on-metal "$device" --hostname new-laptop
```

The installer requires UEFI mode and root, then rechecks that the path is a whole,
unmounted, unheld disk, and that every binary the destructive phase needs is present
before any of it runs. Size and rounded RAM come from live hardware on this path; the
`metal-preflight` subcommand is the one that compares them against figures you supply.
It requires exact `WIPE <device>` input before prompting twice for the user password
and LUKS password.
Neither secret is written to disk at any point: the LUKS passphrase reaches
`cryptsetup` on a pipe and the user password reaches `chpasswd` inside the target
root, so there is no credentials file to leak or to clean up. Root gets no password
and stays locked; administer through `sudo` (`sudo -i` for a root shell).

`pacstrap` installs the base system into a private mount point under `/run`, never
`/mnt`. The recipe creates the 1 GiB ESP, the LUKS container, the LVM root and resume
volumes, NetworkManager, the user, sshd, and rEFInd. The volume group is named after
`--hostname`, so two disks built by this recipe can coexist in one machine without an
ambiguous activation by name.

The default user is `aaron`; pass `--user <name>` to choose another. Since Story 2.56
the metal path has no generated driver and no cloud-init seed: `install-on-metal`
performs the install itself. `provision-seed` remains the Archinstall recipe printer
for the disposable VM targets only.

### Rehearse the metal path in a VM

Before pushing changes to `install-on-metal`, `refind-config`, or `hibernate-storage`,
run the attended path against the host working tree, including uncommitted edits
and non-ignored new files:

```bash
.local/bin/setup/metal-rehearsal run
# Keep the successful disk, credentials, logs, and menu images for inspection:
.local/bin/setup/metal-rehearsal run --keep
# Remove one retained run after inspection (refuses an active or unrelated path):
.local/bin/setup/metal-rehearsal destroy ~/.cache/bootstrap-harness/metal-rehearsal/<timestamp>
```

Host prerequisites: `qemu-system-x86_64`, `qemu-img`, `bsdtar`, `ssh`, `git`,
read/write access to `/dev/kvm`, and the `edk2-ovmf` 4 MiB firmware under
`/usr/share/edk2/x64`. The guest uses 8 GiB RAM, four vCPUs, and a 63 GiB sparse
qcow2. Preflight requires at least 10 GiB free under the artifact root; the
installed system and its 12 GiB routine swapfile consume more as the run proceeds.
The ISO is SHA-256 checked against `vm-harness fetch`'s cache on every run; fetch
runs if either the ISO or checksum file is missing.

This is raw, user-owned QEMU/OVMF, not libvirt. HTTP transfer and the SSH forward
bind only to localhost. The harness answers `WIPE /dev/vda`, user passwords, and
LUKS passwords over the guest's serial PTY; the installed recipe has no bypass
flag or environment override. No host root authorization is used.

**Pass means exit 0 after all of these checks:**

1. Install from the working tree through `install-on-metal` and the unchanged
   attended driver; finalize, power off, boot through rEFInd, unlock, and log in.
2. As a labelled stand-in for bootstrap step 9, install `intel-ucode`, `python`,
   `polkit`, and an AUR `makepkg` build of `refind-theme-nord`. Run `refind-config`
   audit/apply/check, `hibernate-storage` apply/check, and a second rEFInd apply.
   Require the separate routine/resume swap layout and generated `resume=UUID=`.
3. Reboot, require a new boot ID, the live `resume=UUID=` kernel option, both
   checks converged, and `CanHibernate` equal to `yes`.
4. Hibernate, wait for QEMU to exit, relaunch, unlock, and require the same boot ID,
   a surviving `/dev/shm` marker, and the kernel journal's hibernation-exit record.
5. Power off and delete the run artifacts unless `--keep` was supplied.

Every stage has a deadline. A failure exits nonzero, names the stage, prints the
last 40 serial and SSH lines — a channel that captured nothing is named as empty,
so a pre-launch failure never reads as silence — and retains its directory under
`~/.cache/bootstrap-harness/metal-rehearsal/<timestamp>/`, never `/tmp`.
Retained runs include mode-0600 throwaway credentials for unlocking the disk.
Do not publish that file or raw guest logs; use the host-side stage/RC transcript
with local paths redacted for issue evidence.

This is a **local integration gate**, not a GitHub Validate step. It downloads an
ISO and packages, builds an AUR package, and exercises KVM and real hibernation;
it deliberately does not run the full workstation bootstrap.

### Portable drive

`--portable` builds the same encrypted recipe on removable media that boots any
UEFI x86_64 machine (Story 2.57, [#254](https://github.com/amasover/dotfiles/issues/254)).
It runs from the Arch ISO like the fixed recipe, or, since Story 2.58
([#255](https://github.com/amasover/dotfiles/issues/255)), straight from a booted
Arch workstation with the drive plugged in:

```bash
lsblk -d -o PATH,SIZE,TRAN,MODEL,SERIAL     # pick the external drive; never guess
sudo ~/.local/bin/setup/install-on-metal /dev/sdX --hostname <name> --portable
```

From a booted system the installer writes nothing outside the drive. It accepts
only `--portable`, because a fixed install would add a firmware entry to the
machine running it. It refuses a disk that is mounted (the machine's own root disk
always is) and a `--hostname` whose volume group the machine already has. Missing
tooling is named with its package before any prompt; a stock workstation usually
needs `pacman -S --needed arch-install-scripts gptfdisk parted`. Packages come
from `[core]` and `[extra]` only, through this machine's mirrorlist, into the
drive's own cache. The drive is unlocked under a mapping name of its own and
closed again, and the hardware clock is left alone.

What differs from the fixed recipe:

- rEFInd goes to the removable-media fallback path, `EFI/BOOT/bootx64.efi`
  (`refind-install --usedefault`), with its config beside it. The installing
  machine gets no firmware boot entry. This workstation's rEFInd
  (`scanfor …,external`) lists the drive whenever it is plugged in; any other
  machine boots it from its firmware's one-time boot menu.
- The initramfs omits `autodetect`
  (`/etc/mkinitcpio.conf.d/90-dotfiles-portable.conf`), so it carries the storage,
  USB, and keyboard drivers of machines it has never seen.
- The resume volume is a fixed 64 GiB ceiling, not this machine's RAM. The
  routine swapfile stays at 96 GiB (1.5x that volume), so the disk must hold at
  least 203 GiB. A machine with more than 64 GiB of RAM still boots the drive;
  `hibernate-storage` reports hibernation unavailable there.
- The drive's rEFInd is unsigned (decision row 22 in
  [decision-portable-install.md](./decision-portable-install.md)): disable Secure
  Boot on a machine that enforces it.

Rehearse with `.local/bin/setup/metal-rehearsal run --portable`. It installs over
virtio, then boots the same disk as USB storage under fresh firmware variables
holding no boot entry, and runs the handoff, reboot, and hibernate stages there.
`metal-rehearsal run --host-side` rehearses the workstation route instead. It
boots a fixed install, checks its refusals, builds the drive on a second disk from
inside it, and requires the firmware variables file to be byte-identical and the
host's mounts and device mappings unchanged. Then it boots only the drive, over
USB with fresh firmware, through the same stages.

## Bootstrap preconditions

After the provisioned laptop or drive first boots, network, Git, `base-devel`, and
YADM are already present. Clone and select the concrete class before bootstrap:

```bash
nmtui                                # Wi-Fi only; wired comes up on its own
yadm clone https://github.com/amasover/dotfiles.git
yadm config local.class workstation  # or portable: see the class table
yadm alt
```

The class must match the machine. A fixed install takes the class of its hardware;
the only fixed physical adapter tracked is `workstation`/`hardware-intel-laptop`, so
add another class before provisioning different hardware. A portable drive takes
`portable` whatever machine it is first booted on. Resolve any checkout conflict
before continuing.

## Run

```bash
~/.local/bin/setup/bootstrap --check   # read-only: guards + plan
~/.local/bin/setup/bootstrap           # the real run
```

The script is linear and re-runnable. Every mutation is explicit and idempotent;
package tools show plans/prompts, while service/file steps print their exact action.
What it does, in order:

1. **Secrets** — `yadm decrypt` (interactive passphrase; symmetric GPG, no key
   transfer needed; secret contents are never printed). Skipped when `~/.zshenv`
   already exists, and always skipped under `--unattended` — a passphrase prompt
   can't run without a TTY, so VM/harness runs get no secrets; run `yadm decrypt`
   in the guest manually if a test needs them.
2. **Profile guard** — hard-fails unless `yadm config local.class <class>` is set and
   the rendered `~/.config/metapac/config.toml` has this hostname's entry. Choosing
   the class **is** the desktop-optional step: a class whose group list omits
   `desktop`/`media`/`gaming` bootstraps a headless-ish machine; nothing installs
   i3/polybar/rofi unless the class says so.
3. **Machine-local group** — creates (empty) `~/.local/share/metapac/machine-local.toml`
   if missing: the one group file living outside the repo, and metapac hard-errors
   on missing group files (Story 2.11 owns its contents).
4. **Mirrors** — installs reflector, symlinks the tracked ranking policy
   (`.config/dotfiles/reflector.conf`) into `/etc/xdg/reflector/`, enables
   `reflector.timer` (the steady-state owner, Story 2.18), and re-ranks when
   `/etc/pacman.d/mirrorlist` is older than 7 days. Fresh installs usually skip
   the re-rank (the archiso ranks mirrors at live-boot and the install copies
   that list in). One policy file, so the timer, the bootstrap re-rank and
   zshrc's `update_pacman_mirrorlist` can't disagree — Arch's stock conf ranks
   the five most recently *synced* mirrors worldwide, which is how this machine
   ended up on Brazilian and South African mirrors at ~1.2 MiB/s.
5. **yay** — one manual `makepkg -si` from `yay-bin`; the only unmanaged install.
6. **metapac** — `yay -S metapac` (it's an AUR package).
7. **`metapac sync`** — the fresh install is just the first reconcile: installs the
   class's declared set (AUR through yay), per-package service hooks fire as declared.
   Shell ownership includes official `nvm` and `zsh-autosuggestions`; `.zshrc` sources
   their packaged entry points directly. NVM never reacts to `cd`—run `nvm use`
   explicitly when a Node project needs its `.nvmrc` version.
8. **Network ownership** — enables and starts NetworkManager, then disables and stops
   systemd-networkd. Harness seeds select NetworkManager from first boot; this step also
   migrates older ISO-networked guests. `--check` requires or reports the exact cutover.
9. **Initramfs boot chain** — links the tracked HOOKS policy
   (`.config/dotfiles/mkinitcpio/hooks.conf`) to
   `/etc/mkinitcpio.conf.d/10-dotfiles-hooks.conf` and rebuilds the default and fallback
   images whose embedded merged configuration differs from the post-link configuration.
   A machine whose running command line still carries `cryptdevice=` is reported and
   skipped; see [systemd initramfs migration](#systemd-initramfs-migration).
10. **rEFInd boot configuration** — `workstation` and `portable` only. Reconciles tracked portable policy,
   generated machine scan/kernel entries, and package-owned Nord assets. Production access
   gets a separate `pkexec` approval; existing files are backed up outside the ESP before
   any write. Unmanaged files stop normal apply rather than being replaced.
11. **AUR trust baseline** — `aur-quarantine seed` (trust-first-seen, announced;
    interim until 2.10's portable baseline).
12. **oh-my-zsh** — official installer, `KEEP_ZSHRC=yes` so yadm's `.zshrc` survives;
    then symlinks the tracked patched agnoster theme into its custom theme directory.
    No custom plugin clone supplies autosuggestions or NVM.
13. **Spacemacs checkout** — `setup/spacemacs-checkout apply` clones upstream `develop`
    when `~/.emacs.d` is absent. An existing wrong/dirty/ahead checkout stops with manual
    repair instructions; bootstrap never overwrites it. Tracked `~/.spacemacs` owns user
    configuration.
14. **Emacs Copilot server** — installs a pinned `@github/copilot-language-server`
    under Spacemacs' cache through declared official `nodejs`/`npm` in `/usr/bin`,
    then verifies both package version and launcher. This runs before first Emacs launch.
15. **Claude Code plugins** — merges the declared marketplaces/plugins without replacing
    unrelated settings.
16. **Vim fallback plugins** — after metapac installs the manager and packaged plugins,
    reconciles active `Plug` declarations; `--check` is read-only.
17. **User services** — enables tracked user units; services awaiting attended auth may
    start later through their restart policy.
18. **VMware Firefox policy** — reconciles the guest-only hardware-acceleration policy and
    leaves metal/non-VMware hosts without the managed link.
19. **Login shell** — `chsh -s /usr/bin/zsh` if needed. Reboot when done.

Focused editor validation from the repo checkout:

```bash
clitest tests/emacs-copilot-server.clitest.txt
emacs --batch -Q -l tests/spacemacs-config-test.el -f ert-run-tests-batch-and-exit
SPACEMACS_EXPECT_TREEMACS_PROJECTS=1 tests/spacemacs-live-smoke  # attended laptop
```

The first two checks are host-independent. The GUI smoke runs after normal Spacemacs
startup and fails on programming-mode hook exceptions, missing line numbers, hidden or
broken Treemacs, and (when requested) an empty persisted Treemacs workspace. Its JSON
result contains state/counts only—never project paths.

## Class table

All classes include the same 15 purpose groups from
`.config/metapac/profiles/common.groups` plus the private machine-local group.

| Class | Intended machine | Added groups |
| --- | --- | --- |
| `workstation` | Managed physical Intel laptop | `work`, `hardware-intel-laptop`, `inbox-workstation` |
| `daily-vm` | Windows-hosted VMware daily driver | `guest-vmware`, `inbox-daily-vm` |
| `qemu-harness` | Disposable libvirt validation guest | `guest-qemu`, `inbox-qemu-harness` |
| `portable` | Portable drive booting any x86_64 UEFI machine | `hardware-portable`, `inbox-portable` |

Each concrete class selects exactly one hardware adapter and one inbox. To add a
machine profile, add its guarded template branch, adapter, and inbox; set
`yadm config local.class <class>`, then run `yadm alt`. Bootstrap enables
NetworkManager for every class after package reconcile.

`portable` leaves out `work`. Its adapter carries microcode, firmware, and GPU
userspace for Intel, AMD, and NVIDIA (nouveau/NVK), because the drive meets
chassis it was never installed on. Its inbox started as a copy of
`inbox-workstation`'s untriaged set, since the drive succeeded that laptop.

## Bare-metal hibernation storage

A hibernating workstation uses separate storage for routine paging and the
hibernation image. This prevents ordinary swap occupancy from consuming the
space needed to save RAM.

The Story 2.29 metal recipe creates one LUKS container holding an ext4 root LV and one
resume LV exactly equal to rounded physical RAM. It disables zram and refuses a disk
that cannot also hold the future routine swapfile, sized at 1.5x the resume
volume's rounded-up GiB size, plus 40 GiB workstation headroom. `genfstab` records
mounted filesystems only, so the dedicated resume LV is
never in it; the installer's `metal-finalize` step persists it in the target fstab at
priority -1 and rebuilds the initramfs in the target chroot. The initramfs is the
systemd chain (Story 2.59), which needs no `resume` hook: systemd's
`systemd-hibernate-resume-generator` restores the image from the `resume=` kernel
option that step 3 below persists. Whole-GiB rounding of physical RAM is a safe
target; the image itself can never exceed `MemTotal`, so that is the size the
module enforces.

After first boot and yadm checkout:

1. Run the read-only preflight:
   ```bash
   ~/.local/bin/setup/hibernate-storage --check
   ```
2. Apply through one attended root authorization:
   ```bash
   pkexec /usr/bin/bash ~/.local/bin/setup/hibernate-storage apply
   ```
   The module selects the only active encrypted swap partition when the kernel
   has no resume target yet. It creates `/swapfile` inside encrypted root at
   1.5 times the resume volume's rounded-up whole-GiB size, activates it at
   priority 100, drains the lower-priority resume partition, and atomically adds
   fstab policy after backing up the old
   file under `/var/backups/dotfiles/hibernate-storage/`. It refuses ambiguous,
   unencrypted, undersized, non-ext4, or low-disk-space layouts before mutation.

   Without a `resume=` kernel option, systemd selects a hibernation location on
   its own and takes the highest-priority swap area — `/swapfile` — which aims
   the image at routine paging storage inside root. The module treats that state
   as repairable drift and reprograms `/sys/power/resume` to the dedicated
   partition at offset 0. Step 3 is what makes the selection survive reboot.
3. Run `refind-config apply`. Story 2.29 marks Archinstall's fresh rEFInd files as
   managed handoff inputs, so normal backup-first apply replaces them after the Nord
   package lands. It derives `resume=UUID=...` from the resume device selected above;
   no disk identifier enters this repo. It refuses to derive from a swap-file resume
   target rather than pinning routine paging storage into boot config. Use `adopt`
   only for an older unmanaged install.
4. Reboot, then require both checks before the first attended hibernate test:
   ```bash
   ~/.local/bin/setup/hibernate-storage --check
   refind-config --check
   busctl call org.freedesktop.login1 /org/freedesktop/login1 \
     org.freedesktop.login1.Manager CanHibernate
   ```
   The final command must return `s "yes"`.

### Loaded hibernation stalls in image preallocation

If storage and boot configuration pass but a loaded machine sits at the lock
screen instead of powering off, it is almost certainly still in
`PM: hibernation: Preallocating image memory`. Userspace is frozen there by
design, so a working machine and a stalling one look identical; confirm with
`journalctl -b -k | grep 'hibernation: Allocated'` after the next successful
resume, which reports how long that phase took.

Use the opt-in
[hibernate preallocation workaround](../.config/dotfiles/hibernate/README.md).
It evicts the working set to swap for `systemd-hibernate.service` only, before
the freeze, covering both idle timers and the i3 hibernate shortcut without
disabling zswap or hibernation. Follow its attended verification and
upstream-removal instructions; do not deploy it universally or modify another
OS's swap.

The earlier drop-in in that directory paused the zswap shrinker instead. It did
not prevent the stall and removed the pool's only pressure-driven drain; the
installer deletes it from machines that still carry it.

## systemd initramfs

Every machine this repository provisions boots a systemd initramfs (Story 2.59,
[#258](https://github.com/amasover/dotfiles/issues/258)). The array lives in one
tracked drop-in, `.config/dotfiles/mkinitcpio/hooks.conf`; `install-on-metal` copies
it into a fresh target before `pacstrap` builds the first image, and bootstrap step 9
replaces that copy with a symlink. `mkinitcpio` sources drop-ins after
`/etc/mkinitcpio.conf`, so pacman keeps owning the base file, a `.pacnew` never
touches the boot chain, and `MODULES` stays a machine-local value in the base file.

The chain unlocks through `sd-encrypt` from `rd.luks.name=<uuid>=cryptlvm`, never
`cryptdevice=`, which only the udev `encrypt` hook reads. `base` precedes `systemd` and
`SYSTEMD_SULOGIN_FORCE=1` is on the kernel command line, so a boot that fails before
root still reaches a rescue shell even though the root account is locked.
`refind-config` carries that option forward whenever it regenerates
`refind_linux.conf` from the running kernel.

### systemd initramfs migration

A machine installed before Story 2.59 boots the udev chain with `cryptdevice=` on its
command line, and bootstrap refuses to link the policy there: the next kernel update
would build an image that never prompts for the passphrase. Its command line and
initramfs change together, attended, in one step:

1. Keep a known-good image and an entry that boots it:
   `sudo cp /boot/initramfs-linux.img /boot/initramfs-linux-udev.img`, plus a manual
   rEFInd stanza or `refind_linux.conf` line booting it with today's options.
2. In `/boot/refind_linux.conf`, replace `cryptdevice=UUID=<uuid>:<name>` with
   `rd.luks.name=<uuid>=<name>` and append `SYSTEMD_SULOGIN_FORCE=1`.
3. `sudo ln -sfT ~/.config/dotfiles/mkinitcpio/hooks.conf
   /etc/mkinitcpio.conf.d/10-dotfiles-hooks.conf && sudo mkinitcpio -P`.
4. Reboot immediately. Do **not** run `refind-config apply` between steps 2 and 4:
   it derives the command line from the running kernel and would silently restore
   `cryptdevice=`.
5. After reboot, require `grep -q rd.luks.name= /proc/cmdline`,
   `refind-config --check` and `hibernate-storage --check` converged, then remove the
   fallback image and stanza.

## rEFInd metal boot configuration

Story 2.52 ([#230](https://github.com/amasover/dotfiles/issues/230)) separates
portable boot policy from machine identifiers:

- [`.config/dotfiles/refind/refind.conf`](../.config/dotfiles/refind/refind.conf)
  owns timeout, Arch selection/scanning, and Nord inclusion. It contains no disk,
  root, resume, or partition identifiers.
- [`setup/refind-config`](../.local/bin/setup/refind-config) derives identity-bearing
  kernel options from live `/proc/cmdline` and `/sys/power/resume`, plus the kernel
  directory from `/boot` mount target and filesystem-root metadata. It generates
  `dotfiles-machine.conf` on a verified active FAT ESP and `/boot/refind_linux.conf`;
  Intel microcode precedes the kernel-matched `initramfs-%v.img`.
- `/usr/share/refind/themes/nord` remains package-owned. The reconciler verifies that
  ownership, copies only boot-time theme assets, and marks the ESP copy as managed.
  It leaves Nord's `icons/os_*.png` out of that copy, so rEFInd falls back to the
  stock logos `refind-install` placed in `EFI/refind/icons` (the colored Arch and
  Ubuntu marks) while function, tool, and volume icons stay Nord. The policy sets
  a twelve-entry `showtools` line after the theme include: the first five
  (shell, about, shutdown, reboot, firmware) are the visible row, and the rest
  overwrite leftover default slots, because rEFInd 0.14.2 does not clear the
  default tool list when a shorter line is parsed and would double-render the
  same four tools. Padding entries render only when their tool file exists. A
  missing `EFI/refind/icons` fails `--check`, `apply`, and `adopt` closed.
- The reconciler touches only rEFInd's own directory and `/boot/refind_linux.conf`. It
  never edits NVRAM, installs a firmware entry, removes another loader, or reboots.
- On a portable drive rEFInd's directory is `EFI/BOOT`, not `EFI/refind`: the
  reconciler recognises `EFI/BOOT/bootx64.efi` with `refind.conf` beside it, manages
  the policy, theme, and stock icons there, and binds that ESP to the disk the
  running root is on instead of to a firmware entry, which a drive booted on a
  foreign machine never has. A fixed install's `EFI/refind` wins when both exist.

**Loader follow-up.** Decided 2026-10-19 (decision row 22): stay on stock rEFInd for
now, portable drives included. Stock rEFInd went dormant after 0.14.2 (Nov 2023), and both
live bugs this runbook records (`also_scan_dirs @` prefix, `showtools` not
clearing the default tool array) are fossils of that. If upstream still shows no
active development roughly 2-3 years on, or a concrete need arrives it cannot
serve (shim ≥15.3 SBAT chaining, newer filesystem drivers, future kernel
quirks), switch to [rEFInd Plus](https://github.com/RefindPlusRepo/RefindPlus):
an actively maintained fork (roughly quarterly releases) that fixes the
`showtools` class and embeds the SBAT section for Secure Boot, available as the
unsigned AUR binary `refindplus-bin`. It speaks the same `refind.conf`
vocabulary, including the twelve-entry `showtools` line above. The swap is a
scoped PR: replace the binary, extend `theme_source_owner` to accept the Plus
package, re-verify its `EFI/refind/icons` and driver layout, and re-run the
OVMF/QEMU preview and suites before the attended reboot.

Production modes all re-exec through `pkexec`; read-only modes need elevation because
the ESP is normally mounted root-only:

```bash
refind-config audit       # redacted inventory; no identifiers printed
refind-config --check     # exit 0 converged, 1 drift, 2 unsafe/ambiguous
refind-config apply       # missing or already-managed destinations only
refind-config adopt       # explicit one-time takeover of unmanaged destinations
```

`apply` and `adopt` first copy and sync every existing destination to a timestamped
directory under `/var/backups/dotfiles/refind/`, outside the ESP. Each destination
replacement is atomic; an ordinary write failure restores the complete prior state
and reports the backup path. `adopt` exists for attended migration only; bootstrap
never selects it. Normal apply fails before writing for unmanaged destinations,
symlinked paths, a missing or inactive ESP mount, missing kernel-matched boot
artifacts, or an incomplete/unowned Nord package. No reboot is automatic.

Live derivation is the default and rejects machine-local kernel overrides. The metal
path uses it deliberately: `install-on-metal` installs the first-boot rEFInd binary
and writes its kernel entry, then `metal-finalize` marks those two fresh files with
Story 2.52's managed marker and reserves the empty `EFI/refind/themes/nord` directory
with the reconciler's ownership marker. The `refind-theme-nord` package hook copies
its assets
into that directory (and mounts the already-mounted ESP a second time; the reconciler
accepts identical duplicate mount records) before bootstrap runs, so the first
`refind-config apply` reconciles the theme without `adopt`. An existing unmarked theme
directory stops finalization. After first boot, bootstrap's ordinary
`refind-config apply` derives crypt/root identity from the running kernel and installs
tracked policy plus the package-owned Nord assets. After `hibernate-storage apply`
selects the resume LV, the second `refind-config apply` adds its live-derived UUID.
The current workstation's boot files and identifiers are neither read nor copied.

`pacstrap` installs no microcode package — Archinstall detected the CPU vendor and
added one, and decision 1 of the portable-install record leaves hardware fitting to
the machine class. A freshly installed target therefore has no
`/boot/intel-ucode.img`, and `refind-config` refuses to apply until the package step
above installs microcode. That ordering is why the handoff follows bootstrap rather
than the install.

Other offline provisioners may still use untracked, root-owned
`/etc/dotfiles/refind.json` with `--root`; target roots never borrow the installer
host's `/proc/cmdline` or `/boot` metadata.

The generated `dotfiles-machine.conf` names the kernel directory relative to the
volume root (`also_scan_dirs +,arch`), so rEFInd scans it on every volume it can
read and takes options from the `refind_linux.conf` beside the kernel. Never
prefix it with `@`: rEFInd's default `@/boot` is the literal Btrfs `@` subvolume
path, and `@/arch` silently drops Arch from the menu (see
[knowledge/errors/refind-at-prefix-scan-dir-hides-kernel.md](../knowledge/errors/refind-at-prefix-scan-dir-hides-kernel.md)).

**Dual boot (machine-local only).** A sibling OS whose kernels share the boot
filesystem cannot be auto-scanned: rEFInd would synthesize `root=` from the boot
partition. Add `dual_boot` to the same JSON on that machine only; machines without
it get no stanza, so the tracked policy stays dual-boot-agnostic. Live mode derives
`volume` from the `/boot` mount's partition GUID and verifies each path exists on
the boot volume before writing; target roots must state `volume`. That verification
needs the boot partition's own filesystem root mounted exactly once (for example
under `/mnt/boot`, with its kernel directory bind-mounted at `/boot`); when only
the bind mount exists, the reconciler refuses before writing. `options` takes
identity tokens only (`root=` required); the generator appends the same
`rw add_efi_memmap` it gives the Arch entries. `dont_scan_dirs` hides the
sibling's own loader so the menu carries one entry.

```json
{
  "dual_boot": [
    {
      "title": "Ubuntu",
      "loader": "/ubuntu/vmlinuz",
      "initrd": "/ubuntu/initrd.img",
      "fallback_initrd": "/ubuntu/initrd.img.old",
      "options": ["root=/dev/mapper/<vg>-<ubuntu-root>"],
      "dont_scan_dirs": ["EFI/ubuntu"]
    }
  ]
}
```

### Attended fresh-laptop validation

Treat first policy reconciliation and boot proof as one attended operation:

1. Run `audit`; confirm active FAT ESP, rEFInd firmware entry, package-owned Nord
   source, and Arch kernel/initramfs pairs.
2. Run `apply`; require its backup path and then `rEFInd configuration: converged` from
   `--check`. Story 2.29's handoff markers (config files and theme directory) mean no
   first-install `adopt` is needed.
3. Complete `hibernate-storage apply`, run `refind-config apply` again, and require both
   read-only checks to converge.
4. Reboot once; inspect the intended Arch entry and Nord theme, then boot Arch.
5. Record redacted checksums, backup paths, storage checks, and boot result on #95.

Existing-machine adoption, including the current workstation's Ubuntu preservation
proof, remains issue #230 and is not part of Story 2.29.

## Daily-drivable acceptance (the cleanup-era milestone bar)

The rebuild milestone (see CONTEXT.md **Daily-driver rebuild** and
[decision-daily-driver-vm.md](./decision-daily-driver-vm.md)) is claimed only when
every item passes on the rebuilt machine, executed by hand during the run:

1. Boots via the intended boot path to a login (VM: VMware boot; metal: refind).
2. Graphical session works: i3 + terminal + rofi compose a usable desktop.
3. Network up (wifi included where the hardware has it).
4. `yadm decrypt` restores secrets — one real ssh connection and one AWS call succeed.
5. Interactive zsh starts without missing-plugin warnings; `nvm` resolves, and changing
   directories does not switch Node until `nvm use` is requested.
6. Browser and Spacemacs open and are usable; `setup/spacemacs-checkout --check` reports a
   clean upstream `develop` checkout, and Emacs packages update through `setup/update`.
7. Audio plays.
8. `metapac unmanaged` is exactly empty and the drift report is clean — the machine
   is converged, not merely running.

Anything not listed (gaming, media tuning, polybar cosmetics, screenlayout) is
steady-state work and does not block the milestone.

## After first boot

- `yay -Syu` is quarantine-gated from the start (holds are normal for a young
  baseline; `aur-quarantine accept <pkg>` after verifying).
- `setup/update` is the update loop; it ends with the read-only drift report
  (unmanaged / declared-but-missing / inbox triage).
- Machine-specific extras go in untracked `~/.gitconfig-local` / `~/.zshrc.local`
  (work machines: git identity, work aliases — see Story 1.8).

## Troubleshooting

- **"yadm.class is unset"** — `yadm config local.class <class>`, `yadm alt`, re-run.
- **"no [hostname_groups] entry"** — the template has no branch for this class, or
  `yadm alt` hasn't re-rendered since the class was set.
- **metapac errors on a missing group file** — re-run the script (step 3 creates
  empty ones), or check the absolute paths in the rendered config.
- **`metapac sync` proposes nothing** — the profile guard should have caught it;
  verify the hostname key really is in the rendered config (guard checks the
  `uname -n` nodename — the `hostname` binary does not exist on minimal installs).
