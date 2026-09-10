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
disk_gib=$(( $(blockdev --getsize64 "$device") / 1073741824 ))
ram_gib=$(awk '/^MemTotal:/ {print int(($2 + 1048575) / 1048576)}' /proc/meminfo)
printf 'device=%s disk=%sGiB ram=%sGiB\n' "$device" "$disk_gib" "$ram_gib"
```

Fetch this repository into the ISO's tmpfs and generate directly runnable files. This
path needs no second seed medium and no `pycdlib`:

```bash
pacman -Sy --needed git
git clone https://github.com/amasover/dotfiles.git /run/dotfiles
/run/dotfiles/.local/bin/setup/vm-harness-seed create \
  --files-only \
  --target metal \
  --out /run/metal-provision \
  --disk-device "$device" \
  --disk-size "$disk_gib" \
  --ram-gib "$ram_gib" \
  --hostname new-laptop \
  --user aaron
python -m json.tool /run/metal-provision/user_configuration.json
/run/metal-provision/run-install.sh
```

The driver requires UEFI mode, then rechecks that the path is a whole, unmounted disk
whose size and rounded RAM match the recipe. It requires exact `WIPE <device>` input
before prompting twice for the user password and LUKS password. Secrets exist only in
a mode-0600 file in the ISO's tmpfs; the driver removes it on success, failure, or
interruption. Archinstall creates the 1 GiB ESP, LVM-on-LUKS root/resume layout,
NetworkManager, user, sshd, and rEFInd.

To prepare CIDATA media elsewhere instead, omit `--files-only` on a machine with
`pycdlib`; attach the resulting `seed.iso` beside the Arch ISO. Cloud-init writes the
same files but deliberately does not launch `/root/run-install.sh` on metal.

## Bootstrap preconditions

After the provisioned laptop first boots, network, Git, `base-devel`, and YADM are
already present. Clone and select the concrete class before bootstrap:

```bash
yadm clone https://github.com/amasover/dotfiles.git
yadm config local.class workstation  # current tracked physical adapter: Intel laptop
yadm alt
```

The class must match the new laptop's hardware. The only physical adapter currently
tracked is `workstation`/`hardware-intel-laptop`; add another class before provisioning
different hardware. Resolve any checkout conflict before continuing.

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
9. **rEFInd boot configuration** — `workstation` only. Reconciles tracked portable policy,
   generated machine scan/kernel entries, and package-owned Nord assets. Production access
   gets a separate `pkexec` approval; existing files are backed up outside the ESP before
   any write. Unmanaged files stop normal apply rather than being replaced.
10. **AUR trust baseline** — `aur-quarantine seed` (trust-first-seen, announced;
    interim until 2.10's portable baseline).
11. **oh-my-zsh** — official installer, `KEEP_ZSHRC=yes` so yadm's `.zshrc` survives;
    then symlinks the tracked patched agnoster theme into its custom theme directory.
    No custom plugin clone supplies autosuggestions or NVM.
12. **Spacemacs checkout** — `setup/spacemacs-checkout apply` clones upstream `develop`
    when `~/.emacs.d` is absent. An existing wrong/dirty/ahead checkout stops with manual
    repair instructions; bootstrap never overwrites it. Tracked `~/.spacemacs` owns user
    configuration.
13. **Emacs Copilot server** — installs a pinned `@github/copilot-language-server`
    under Spacemacs' cache through declared official `nodejs`/`npm` in `/usr/bin`,
    then verifies both package version and launcher. This runs before first Emacs launch.
14. **Claude Code plugins** — merges the declared marketplaces/plugins without replacing
    unrelated settings.
15. **Vim fallback plugins** — after metapac installs the manager and packaged plugins,
    reconciles active `Plug` declarations; `--check` is read-only.
16. **User services** — enables tracked user units; services awaiting attended auth may
    start later through their restart policy.
17. **VMware Firefox policy** — reconciles the guest-only hardware-acceleration policy and
    leaves metal/non-VMware hosts without the managed link.
18. **Login shell** — `chsh -s /usr/bin/zsh` if needed. Reboot when done.

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

Each concrete class selects exactly one hardware adapter and one inbox. To add a
machine profile, add its guarded template branch, adapter, and inbox; set
`yadm config local.class <class>`, then run `yadm alt`. Bootstrap enables
NetworkManager for every class after package reconcile.

## Bare-metal hibernation storage

A hibernating workstation uses separate storage for routine paging and the
hibernation image. This prevents ordinary swap occupancy from consuming the
space needed to save RAM.

The Story 2.29 metal recipe creates one LUKS container holding an ext4 root LV and one
resume LV exactly equal to rounded physical RAM. It disables zram, activates the resume
LV at priority -1 before Archinstall runs `genfstab`, and refuses a disk that cannot
also hold the future 1.5x-RAM routine swapfile plus 40 GiB workstation headroom.

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
   has no resume target yet. It creates `/swapfile` inside encrypted root at 1.5
   times rounded RAM, activates it at priority 100, drains the lower-priority
   resume partition, and atomically adds fstab policy after backing up the old
   file under `/var/backups/dotfiles/hibernate-storage/`. It refuses ambiguous,
   unencrypted, undersized, non-ext4, or low-disk-space layouts before mutation.
3. Run `refind-config apply`. Story 2.29 marks Archinstall's fresh rEFInd files as
   managed handoff inputs, so normal backup-first apply replaces them after the Nord
   package lands. It derives `resume=UUID=...` from the resume device selected above;
   no disk identifier enters this repo. Use `adopt` only for an older unmanaged install.
4. Reboot, then require both checks before the first attended hibernate test:
   ```bash
   ~/.local/bin/setup/hibernate-storage --check
   refind-config --check
   busctl call org.freedesktop.login1 /org/freedesktop/login1 \
     org.freedesktop.login1.Manager CanHibernate
   ```
   The final command must return `s "yes"`.

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
- The reconciler touches only `EFI/refind/**` and `/boot/refind_linux.conf`. It never
  edits NVRAM, installs a firmware entry, removes another loader, or reboots.

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

Live derivation is the default and rejects machine-local kernel overrides. Story 2.29
uses that path deliberately: Archinstall 4.4 installs the first-boot rEFInd binary and
kernel entry, then the provisioner marks only those two fresh files with Story 2.52's
managed marker. After first boot, bootstrap's ordinary `refind-config apply` derives
crypt/root identity from the running kernel and installs tracked policy plus the
package-owned Nord assets. After `hibernate-storage apply` selects the resume LV, the
second `refind-config apply` adds its live-derived UUID. The current workstation's boot
files and identifiers are neither read nor copied.

Other offline provisioners may still use untracked, root-owned
`/etc/dotfiles/refind.json` with `--root`; target roots never borrow the installer
host's `/proc/cmdline` or `/boot` metadata.

### Attended fresh-laptop validation

Treat first policy reconciliation and boot proof as one attended operation:

1. Run `audit`; confirm active FAT ESP, rEFInd firmware entry, package-owned Nord
   source, and Arch kernel/initramfs pairs.
2. Run `apply`; require its backup path and then `rEFInd configuration: converged` from
   `--check`. Story 2.29's handoff marker means no first-install `adopt` is needed.
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
