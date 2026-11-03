# Runbook: QEMU VM validation of bootstrap + manifests

Evidence artifact for Story 2.7 ([#46](https://github.com/amasover/dotfiles/issues/46)).
Harness: [`.local/bin/setup/vm-harness`](../.local/bin/setup/vm-harness). Validates
[`setup/bootstrap`](../.local/bin/setup/bootstrap) and the metapac groups in a
disposable VM before anything is trusted on metal (Story 2.10 gates metal runs).

The attended encrypted-metal path has a separate local gate:
[`metal-rehearsal run`](./runbook-fresh-machine-bootstrap.md#rehearse-the-metal-path-in-a-vm).
It proves installation, rEFInd/storage handoff, reboot, and actual hibernate/resume
from the host working tree. Run it before pushing changes to `install-on-metal`,
`refind-config`, or `hibernate-storage`; it is not part of GitHub Validate.

## The loop

```bash
vm-harness up         # the whole loop below except destroy: fetch (only if no
                      #   cached ISO) → create → install → boot → bootstrap → check
# …or phase by phase:
vm-harness fetch      # once per ISO refresh: download + sha256-verify latest archiso
vm-harness create     # pool volumes: 80G sparse qcow2 + ISO + cloud-init seed (fresh answers)
vm-harness install    # unattended: archiso's cloud-init runs archinstall --silent,
                      #   VM powers off, media auto-ejected; watch: vm-harness tail install
vm-harness boot       # start the domain; prints its NAT IP when the lease appears
vm-harness ip         # the VM's IPv4 (ssh aaron@$(vm-harness ip))
vm-harness bootstrap  # waits for ssh, then: yadm clone → class qemu-harness → repo
                      #   bootstrap --unattended (metapac sync --no-confirm inside)
vm-harness check      # assert: class/adapter/inbox, network owner, drift, graphical target
vm-harness destroy    # undefine domain + delete disk/seed volumes — next run is pristine
```

## Logs, watching, walking away (Story 2.19)

Every phase writes an ANSI-stripped copy of its output to
`~/.local/state/bootstrap-harness/logs/<timestamp>-<phase>.log`, ending with a
`=== <phase> done rc=N` result line. Logs **survive `destroy`** (the post-mortem
of a failed run is their main job); phases run by one `up` share the run's
timestamp so they sort as a set. The terminal keeps the raw colorful stream;
`--quiet` (or `VM_HARNESS_QUIET=1`) suppresses it.

- **Watch live:** `vm-harness tail` follows the newest log and hops to the next
  phase as an `up` run advances — including `install`, whose serial console is
  streamed into its phase log (when sudo was available). `vm-harness tail
  install` follows the raw serial file itself (sudo — root-owned in the workdir).
- **Attended display** (Story 2.21, decisions on [#73](https://github.com/amasover/dotfiles/issues/73)):
  with a tty, phase commands show the raw firehose plus a pinned bottom status
  bar — phase n/m · stage · elapsed, rendered by `tools/vm-harness-display`
  (python-rich styles it; unstyled without). `--progress` swaps to a compact
  one-line status instead of the stream (a failing phase prints its log's last
  40 lines); `--plain` restores the bare stream. `--quiet`/`--detach`/non-tty
  fall back to plain automatically and reject `--progress` loudly. The guest
  sync runs under a pty (script(1)) so pacman's own download bars render live;
  state logs keep one final 100% line per package instead of every redraw.
- **Walk away:** `vm-harness --detach up` runs under `systemd-run --user` — it
  survives the closed terminal, logs plain output, and sends a desktop
  notification on completion (success or failure). `vm-harness status` shows
  the detached unit, the domain state, and the newest log's tail.
- **On failure** (any phase, attached or not): the run stops at the failing
  phase and the VM is left exactly as it died — read the log, fix the cause,
  and re-run `up`: it probes live state (volumes, ejected install media,
  running + lease), skips the phases that completed, and continues from the
  first incomplete one (`status` names it: "up would resume at"). bootstrap
  and check always re-run — bootstrap is idempotent, so a converged guest is
  a fast no-op. The one unresumable state is a half-finished install (media
  still attached): `up` dies pointing at `destroy`. It never auto-destroys.
  (Story 2.31, [#98](https://github.com/amasover/dotfiles/issues/98).)

The VM is a **first-class libvirt domain** — `arch-harness` on `qemu:///system`, visible
and attachable in **virt-manager** (Aaron's ask, 2026-07-04), with storage as managed
volumes in the `default` pool and NAT networking (no port forwards). VM shape (learned
partly from the retired win10 VM's config): q35 + KVM, 4G/8vcpu, **OVMF/UEFI** (win10
ran legacy BIOS; UEFI mirrors the refind metal setup), virtio disk/net (win10's SATA
was the slow path). Throwaway credentials (`aaron`/`vm`, NOPASSWD sudo, host pubkey
pre-authorized) — reachable only from this host's NAT, and the VM is disposable.
The serial log (`~/.local/share/bootstrap-harness/install.log`, **root-owned** by
virtlogd — a 0666 pre-create does not survive, verified live) carries the
`HARNESS-*` markers. `install` streams it live to the terminal and into the
install phase log via `sudo -n tail` (a `sudo -v` at phase start prompts once
when attended); a detached run without cached sudo skips the stream and instead
attempts a `<timestamp>-install-serial.log` fallback copy at completion. Install
success is asserted via libvirt itself (disk-volume allocation), and
archinstall's TUI errors show on the virt-manager console.

## How the pieces fit

- **Unattended install:** both disposable VM harnesses call the shared
  `setup/provision-seed create` interface with the `qemu`, `vmware` or (Fusion on
  the Mac) `vmware-aarch64` target; no inline Archinstall recipe remains. Recent
  official archisos and archiso-aarch64 consume its
  NoCloud seed, which writes `user_configuration.json`/`user_credentials.json`
  and runs `archinstall --silent` through a transient `systemd-run` unit.
  Cloud-init finishes in seconds, so its spinner does not occupy the serial
  stream for the whole install, and the driver powers off only afterward. All
  disposable targets keep Systemd-boot, zram, unencrypted ext4 root, sshd, and
  git/base-devel/yadm. The `daily-vm` target (and its aarch64 twin `work-vm`)
  shares VMware hardware defaults but
  emits the LUKS-encrypted root required by Story 2.29 and omits harness-only
  passwordless sudo and serial policy. Its real VMware creation run remains the
  story's primary evidence. The `metal` target is deliberately attended,
  LVM-on-LUKS, rEFInd-based, and never auto-started.
  Supply the daily target's user and LUKS secrets at invocation through
  `PROVISION_USER_PASSWORD` and `PROVISION_LUKS_PASSWORD`; do not place real
  values in command arguments. The generator makes its output directory private
  and writes the credential-bearing user-data and seed ISO mode 0600. The caller
  must delete that output after installation.
- **VM accommodations:** the seed's `custom_commands` set the login shell to zsh at
  install time (bootstrap's `chsh` step self-skips — `chsh` would password-prompt
  over ssh), and `bootstrap --unattended` skips secret decrypt by design — a
  passphrase prompt can't run without a TTY, so no yadm passphrase or secret
  contents ever enter the harness. If a test needs real secrets, run `yadm decrypt`
  in the guest manually.
- **Shared guest glue (Story 2.41):** every `bootstrap` and `check` scp's the host
  checkout's `vm-harness-guest` into the VM, then invokes it over ssh. Each harness
  passes its concrete class (`qemu-harness` or `daily-vm`); tracked class adapters own
  hypervisor packages. Repo/class/branch selection and end-state gates have one owner.
- **Intentional host differences stay outside the helper:** QEMU's `exec` debugging
  peephole uses qemu-guest-agent and does not propagate guest exit status; guest-glue
  bootstrap/check use ssh and do propagate it through the phase result. Both harnesses
  request one pty with `ssh -t`; the Bash host streams bytes while PowerShell line-buffers
  redraws.
- **AUR trust baseline (Story 2.10):** the bootstrap phase injects the host's
  `~/.local/state/aur-quarantine/{maintainers.tsv,exempt.txt}` into the VM over
  ssh before running bootstrap, so install-gate identity checks see the same
  baseline a decrypt-restored machine would. These are identity judgments, not
  secrets — the no-secrets rule above is unaffected. `VM_HARNESS_FRESH_TRUST=1`
  skips the copy to exercise the fresh-TOFU path.
- **Profile guard in the VM:** the shared helper sets the harness's concrete class,
  renders alternatives, and verifies the expected adapter and inbox during `check`.
  Legacy harness-owned `machine-local.toml` files lose only the formerly injected
  hypervisor packages; any private declarations survive.
- **Acceptance asserts:** `vm-harness check` requires the expected class/adapter/inbox,
  NetworkManager enabled and active with systemd-networkd disabled/inactive, and no
  unmanaged packages except tracked custom-PKGBUILD outputs. Drift remains visible.

## archinstall schema skew (debugging record, 2026-07-03)

The seed config targets the **release** on the ISO (4.4 at first build), whose JSON
dialect differs from archinstall's master-branch sample — validating against the
wrong one cost five iterations. Release-4.4 facts, all verified the hard way:

- `version` (e.g. `"2.8.6"`), not `config_version`; `bootloader_config` object, not
  a `bootloader` string; `swap` is `{"enabled": true}`, not a bool.
- Credentials ship as SHA512-crypt **hashes**: `users[].enc_password` +
  `root_enc_password` (no plaintext `!password` keys).
- Partitions need `dev_path` present, `sector_size` as a real `{value, unit}` object
  (`null` crashes), no `Percent` size unit, **non-overlapping ranges** (1MiB + 1GiB
  ESP overlaps a root starting at 1GiB), and the ESP wants the **`esp` flag** —
  `boot` alone leaves bootctl unable to detect the ESP after pacstrap.
- Metal LVM-on-LUKS nests `disk_encryption` inside `disk_config`, references the
  encrypted PV by its `obj_id`, models the resume LV as `linux-swap`, and puts the
  plaintext LUKS passphrase only in the transient credentials file. These fields were
  checked against the cached ISO's exact `archinstall 4.4-1` package, not master docs.
- The `daily-vm` target uses direct partition LUKS: `disk_encryption` references
  the root partition's `obj_id`, and `user_credentials.json` supplies its runtime
  `encryption_password`.
- **Failure visibility:** archinstall's late-stage errors print via its TUI to the
  VGA console — invisible on serial even with stdout/stderr redirected. The seed's
  `runcmd` therefore emits `HARNESS-RUNCMD-START` / `HARNESS-ARCHINSTALL-EXIT:<rc>`
  markers and dumps the archinstall log tail to serial on failure. When that still
  isn't enough: boot the ISO with a debug seed (root `ssh_authorized_keys`, no
  runcmd), ssh in, and run archinstall by hand on a real pty — that's how
  "Partitions overlap" and the ESP error finally surfaced.

On an ISO refresh (`vm-harness fetch`), expect this section to need re-verification
against the new release's `examples/config-sample.json` **at its git tag** — never
master.

**aarch64 (archiso-aarch64, 2026-11-02):** the ISO bundles its own archinstall, and
its version is not the package repo's. archiso-aarch64 2026.09.01 ships
`archinstall-aarch64 4.4-4` (`arch/pkglist.aarch64.txt`; the installed
`archinstall-4.4.dist-info`), while ironrobin's package repo already carries 4.5-1 —
so the seed keeps the 4.4 / `"2.8.6"` dialect on both architectures. The bundled
package was checked against upstream tag 4.4 by extracting it from the ISO's
`airootfs.sfs` (`unsquashfs`, Homebrew `squashfs`) and diffing: only three files
differ — GRUB/Limine EFI target names for aarch64 and a `Forge` repository enum —
none of them touching the config schema. On an aarch64 ISO refresh, repeat that
extraction and diff; do not read the version off the package repo.

## Expectations / known wrinkles

- **Host prerequisite: the `default` libvirt network must actually work.** A wedged
  `virbr0` (no IPv4 on the bridge — happened after the docker/iptables removal) means
  the guest gets no DHCP → no NTP → `systemd-time-wait-sync` blocks cloud-init's
  *final* stage forever, i.e. `runcmd`/archinstall never starts even though
  `cloud-init status` says "running" and the datasource was found. Check
  `ip -4 addr show virbr0`; fix with `virsh net-destroy default && virsh net-start
  default` — then **power-cycle the VM** (`virsh destroy` + `start`): the net bounce
  detaches running taps, and `virsh reset` does not reliably reset this OVMF domain.
  Since 2.19, the install boot masks `systemd-time-wait-sync` (a KVM guest's clock
  is already the host's via the RTC), so this failure mode is loud archinstall
  mirror errors rather than a silent hang — and healthy boots skip the NTP wait,
  reaching archinstall sooner. archinstall's *own* sync check is skipped too
  (`--skip-ntp`): timesyncd may never sync inside the NAT guest, and with the
  first gate gone it no longer pre-syncs the clock before archinstall checks. The serial stream also prints a
  `HARNESS-CLOUDINIT-UP` marker at cloud-init's early stage: quiet before it =
  still booting; quiet after it = cloud-init's later stages.
- **`vm-harness exec '<cmd>'`** runs commands as root in the guest via the qemu
  agent — works in the live ISO before ssh exists; it's how the hang above was
  diagnosed without touching the console.
- **There is no boot menu during `install` anymore** — the archiso kernel is
  loaded directly (qemu fw_cfg) with `console=ttyS0` appended, read from the ISO's
  own loader entry. Two effects: the full kernel/systemd boot shows on the serial
  stream, and the old footgun is gone (a stray keypress in the systemd-boot menu
  used to cancel the auto-boot countdown and stall the run forever;
  `virsh send-key arch-harness KEY_ENTER` was the rescue). The install boot also
  masks `serial-getty@ttyS0`: `console=ttyS0` makes systemd auto-spawn a getty
  there, and agetty's `vhangup()` invalidates every fd already open on the line —
  it killed archinstall on its first write (instant BrokenPipeError, ~200KB on
  disk, caught by the alloc check).
- **The installed system keeps a serial console too**: its loader entries get
  `console=tty0 console=ttyS0` and `serial-getty@ttyS0` is enabled at install
  time — every later boot logs to the serial file, `vm-harness boot` streams it
  live while waiting for the NAT lease (then the flow switches to ssh), and
  `virsh -c qemu:///system console arch-harness` gives a login when ssh is down.
- **Serial output and terminal resizes:** full-screen phases (firmware, TUI
  redraws) draw for a fixed 80×24-ish geometry; a serial line carries no resize
  signal back to the guest, so resizing the watching terminal garbles the
  picture until the next linear output. Inherent to serial consoles — wait it
  out or don't resize mid-TUI.
- **Class profile**: the libvirt harness defaults to `qemu-harness`; the VMware harness
  defaults to `daily-vm` on Windows and `work-vm` on macOS. `VM_HARNESS_CLASS` can select
  another concrete profile when deliberately testing it, e.g.
  `VM_HARNESS_CLASS=daily-vm vm-harness bootstrap`.

- `vm-harness bootstrap` runs `bootstrap --unattended` in the guest (no prompts),
  but the AUR set (dotnet, storageexplorer, etc.) builds for **hours** in the VM.
  A closed terminal kills an *attached* harness run (the qemu process survives;
  the driver doesn't) — use `--detach` when walking away.
- The VM clones the repo from **GitHub main** — bootstrap-affecting PRs must merge
  before their VM validation run (or set `VM_HARNESS_BRANCH` to the branch).
- archinstall selects NetworkManager in the installed system from first boot. Bootstrap
  reasserts it as sole network manager and retires systemd-networkd on older ISO-networked
  guests; `wpa_supplicant` remains NetworkManager's declared backend (Story 3.9).
- First `yay -Syu` inside the VM is quarantine-gated like any machine (2.6 hook
  arrives with the dotfiles; baseline seeded by bootstrap step 7).
- **Disk sizing:** the full workstation profile filled a 38G root mid-run (1,500+
  packages + pacman's download cache + yay's build cache with multi-GB AUR
  tarballs) — the harness default is now **80G** (sparse, costs nothing until
  used). A live-grow rescue is possible without reboot: `virsh blockresize` →
  in-guest `sfdisk -N 2` + `partx -u` + `resize2fs`. Metal sizing: budget the
  same before a first real run.
- Install-time AUR gating does not exist until **2.10** — VM runs accept that risk
  by design; metal runs do not (bootstrap's metal gate).

- **Interrupted runs leave scars** (seen while iterating): repo providers fill deps
  of partially-installed AUR families (`dotnet-host` vs `dotnet-host-bin`, rust vs
  rustup) and failed builds leave requirer-less explicit deps (`gtk2` from a
  colorpicker attempt) plus corrupt `.pkg.tar.zst` archives. The retry loop purges
  corrupt archives and bootstrap normalizes install reasons; anything else → the
  clean answer is `destroy` + a fresh single-pass run.

## VMware harness on macOS (Fusion, aarch64)

`vm-harness-vmware.ps1` drives Workstation on Windows and Fusion Pro on an
Apple-silicon Mac; `$IsMacOS` picks the host. Fusion runs arm64 guests only, so the
Mac guest is aarch64 Arch Linux Ports installed from the latest
[archiso-aarch64](https://codeberg.org/ironrobin/archiso-aarch64/releases) release.

```sh
export VM_HARNESS_SSH_KEY=~/.ssh/<key>   # optional: key to seed + log in with
pwsh ~/.local/bin/setup/vm-harness-vmware.ps1 up      # or fetch/create/install/boot
```

Disposable runs share no host folders. The attended `work-vm` creation
([Create the real work VM](#create-the-real-work-vm-attended-macos)) shares two, set
before `create` (or `up`):

```sh
export VM_HARNESS_SHARES='vmshare=~/vmshare;Downloads=~/Downloads'
```

`NAME=HOSTPATH` pairs separated by `;`; a leading `~` is the Mac home, a missing host
folder is created, and an existing one (Downloads) is used as it is. `create` passes
them to `vm-harness-vmx --share`. To add shares to a VM that already exists (it may
be running), use Fusion's two `vmrun` commands, which write the same vmx keys:

```sh
vmrun=/Applications/VMware\ Fusion.app/Contents/Library/vmrun
"$vmrun" -T fusion enableSharedFolders <vm>.vmx
"$vmrun" -T fusion addSharedFolder <vm>.vmx vmshare ~/vmshare
"$vmrun" -T fusion addSharedFolder <vm>.vmx Downloads ~/Downloads
```

Host prerequisites (no sudo): PowerShell 7 (`~/.local/bin/pwsh`, unpacked from the
official `osx-arm64` tarball into `~/.local/opt/powershell`); a Python >= 3.10 with
`pycdlib` — the driver prefers `<work dir>/venv`, then Homebrew `python3.14`, then
PATH `python3` (macOS's own 3.9 is too old). Work dir:
`~/.local/share/bootstrap-harness-vmware` (`VM_HARNESS_DIR` overrides). The Mac
defaults to class `work-vm`, seed target `vmware-aarch64`, 8 vcpus.

Fusion-specific facts, verified live on Fusion 26H1 (26.0.1), 2026-11-02:

- **ISO + checksum:** releases carry one off-site ISO asset and no checksum file; the
  sha256 is in the release notes as `<hex>  <name>`. `fetch` matches it against the
  exact asset name and verifies before renaming into place.
- **Hardware:** `guestOS = "arm-other7xlinux-64"` (Fusion's guest table: "Other Linux
  7.x and later kernel 64-bit Arm"; the Ports kernel is 7.2) and
  `virtualHW.version = "22"` (what `vmcli VM Create` writes). USB input on XHCI
  (`usb.present`, `usb_xhci.present`) per
  [KB 315602](https://knowledge.broadcom.com/external/article/315602) — the guest sees
  a VMware USB keyboard and mouse. UEFI, NVMe, vmxnet3, SATA CDs and `mks.enable3d`
  as on Workstation.
- **Multiple displays:** `svga.autodetect` stays on and no `svga.maxWidth`/
  `numDisplays`/`vramSize` caps are set: at power-on Fusion sizes display memory
  from the host topology (`SVGA-GFB: Max wh(6688, 5016), number of displays: 10`)
  and vmwgfx exposes `Virtual-1..8`. `svga.graphicsMemoryKB` raises 3D memory from
  the 256 MiB default to 2 GiB. "Use All Displays in Full Screen" itself needs the
  Fusion GUI and running Tools — not exercised headless.
- **Sound and camera (2026-11-03):** `sound.present` with `sound.virtualDev =
  "hdaudio"`; Fusion's default `es1371` stops an arm power-on with
  `msg.devicePowerOn.invalidDT`. The Mac's camera is the virtual UVC device
  `usb_xhci:5.deviceType = "video"` (vid:pid `0e0f:000b`), fed by the host's default
  AVCapture camera; Fusion still adds its own HID on port 4 and hubs on 6 and 7.
  Both need macOS's camera and microphone permission for VMware Fusion (System
  Settings > Privacy & Security).
- **Shared folders (2026-11-03):** the host's shared folders (HGFS) are the file
  route between the Mac and the guest, both ways. `--share` writes
  `isolation.tools.hgfs.disable = "FALSE"`, then per share `sharedFolderN.present`,
  `.enabled`, `.readAccess`, `.writeAccess`, `.hostPath`, `.guestName` and
  `.expiration = "never"`, then `sharedFolder.maxNum`: the keys `vmrun` wrote on a
  running VM. In the guest, `mac-shares.service` (a user unit; no root, no fstab)
  mounts `.host:/` with `vmhgfs-fuse` at `~/mac`, so the shares appear as
  `~/mac/vmshare` and `~/mac/Downloads`. `vmware-hgfsclient` lists the share names.
  VMware has no 9p; HGFS is its equivalent.
- **Drag-and-drop off, clipboard on:** aarch64 vmx output sets
  `isolation.tools.dnd.disable = "TRUE"` and leaves the copy/paste keys alone. See
  Story 5.8 for the live findings behind it.
- **Time zone:** the guest installs on UTC; `bootstrap` writes the Mac's IANA zone into
  the guest's private `~/.config/dotfiles/timezone` before running the repo bootstrap,
  which sets it (`VM_HARNESS_TIMEZONE` overrides the zone).
- **Serial console:** ACPI SPCR puts the kernel console on `ttyS0` (16550 MMIO), the
  VMware serial port; no `ttyAMA0`. The live ISO therefore spawns
  `serial-getty@ttyS0`, which the install driver stops before writing the line.
  The installed system needs no extra kernel parameters (the ISO's
  `clk_ignore_unused pd_ignore_unused arm64.nopauth` are for Snapdragon laptops).
- **Live-ISO root ssh:** archiso-aarch64's `cloud.cfg` has `disable_root: true`;
  the seed sets `disable_root: false` so `exec` reaches root.
- **Mirrors:** the ISO's `pacman.conf` names drzee with literal `Server` lines plus
  the builder's `[ironrobin-aarch64]` repo, and its mirrorlist is the stock x86_64
  list. The aarch64 targets rewrite the installed system to `Include =
  /etc/pacman.d/mirrorlist` (drzee) for `[forge]`/`[core]`/`[extra]`, drop
  `[ironrobin-aarch64]`, and install `archports-keyring`.
- **Leases:** `/var/db/vmware/vmnet-dhcpd-vmnet8.leases` (world-readable).
- **vmrun start:** `vmware-vmx` inherits vmrun's stdout and process group, so the
  driver starts it in its own session with output in a temp file; a plain captured
  call never returns while the VM runs, and a Ctrl-C would kill the VM.
- **Tools:** `vmrun checkToolsState` reports `installed`, not `running`, though the
  VMX log shows open-vm-tools 13.1 heartbeating; `getGuestIPAddress` answers only
  with `-wait`. The driver's lease fallback covers it.
- **Timing:** unattended install ~5 minutes, boot to ssh ~15 s.

## Create the real work VM (attended, macOS)

`VM_HARNESS_TARGET=work-vm` switches the same driver from a throwaway VM to the real,
LUKS-encrypted work VM (Story 5.8). With it unset, every run stays disposable. What
changes in attended mode:

| | Disposable | Attended (`work-vm`) |
| --- | --- | --- |
| Seed target, VM name | `vmware-aarch64`, `arch-harness` | `work-vm`, `work-vm` (`VM_HARNESS_NAME`) |
| VM directory | `<work dir>/vm` | `~/vms/work-vm` (`VM_HARNESS_VM_DIR`), seed and logs inside |
| Disk, vcpus, RAM | 80 GiB, 8, 12288 MiB | 300 GiB, 10, 12288 MiB |
| Passwords | user `vm`, password-free sudo | typed by you; LUKS root; normal sudo |
| ssh key | `VM_HARNESS_SSH_KEY` or `~/.ssh/id_*.pub` | always your `~/.ssh/id_*.pub` |
| VMware window | per `VM_HARNESS_GUI` | always open |
| Bootstrap | `--unattended` | prompts, over `ssh -t` in your terminal |
| GitHub token | never copied | `~/.config/dotfiles/github-token` copied at 0600, if present |
| `destroy` | no questions | type the VM name, or `VM_HARNESS_DESTROY_REAL=work-vm` |

Prerequisites: the work dir has the cached ISO (`fetch`) and a Python with `pycdlib`
(`<work dir>/venv`), as for disposable runs; your ssh key is in `~/.ssh/id_*.pub`. A
disposable VM can keep running: the two VMs share nothing but the cached ISO.

Run it from the repo checkout that has this change (from its root), in a terminal you
can leave open; `pwsh ~/.local/bin/setup/vm-harness-vmware.ps1 …` works the same once
the change is in your home directory's yadm checkout:

```sh
unset VM_HARNESS_SSH_KEY VM_HARNESS_BUNDLE VM_HARNESS_BRANCH VM_HARNESS_REPO VM_HARNESS_GUI
export VM_HARNESS_DIR=~/vmh-scratch/work   # the work dir holding cache/ and venv/
export VM_HARNESS_TARGET=work-vm
export VM_HARNESS_SHARES='vmshare=~/vmshare;Downloads=~/Downloads'
pwsh .local/bin/setup/vm-harness-vmware.ps1 up
```

The VM clones and bootstraps GitHub `main` as class `work-vm`. You type everything in
the first few minutes; after that the run needs nobody for hours. What you type, and
when:

1. **create** (under a minute): in the terminal, your VM user password twice, then the
   disk (LUKS) password twice. Input is hidden; a mismatch asks again. They reach
   `provision-seed` only through its environment, never its command line or a log.
2. **install** (about 5 minutes; the VMware window opens on the live ISO): nothing.
   When it ends, failed or not, the seed (your password hash and disk password) is
   deleted; the terminal says so.
3. **boot** (seconds, then you): type the disk password in the VMware window. The
   terminal waits up to 30 minutes for ssh. Every later boot asks for it there too.
4. **bootstrap**, at its start: in the terminal, your VM user password once for
   `sudo`, then the archive passphrase for `yadm decrypt` (three attempts; a third
   wrong one stops the run before the long part). The `sudo` password puts a temporary
   password-free drop-in at `/etc/sudoers.d/89-first-bootstrap`; it is deleted when
   bootstrap ends, also on failure or Ctrl-C. Before the prompts, the Mac's AUR trust
   baseline, time zone and GitHub token are copied in.
5. **bootstrap**, the long part (hours; the disposable run took about 45 minutes):
   nothing. It is the same `bootstrap --unattended` as a disposable run, so its
   quarantine pre-flight guards the sync; its decrypt step reports the secrets as
   already decrypted.
6. **bootstrap**, at its end: it lists the follow-ups `--unattended` skipped, each with
   its command, to run later in a terminal on the VM: the OpenViking memory sign-in
   (`~/.local/bin/setup/openviking-memory`, a passkey sign-in to OpenBao) and, if
   bootstrap reported packages the quarantine held, a later
   `~/.local/bin/setup/bootstrap --unattended`.
7. **check** (a minute): nothing. It fails if the sudo drop-in is still there.

A failed phase stops `up` and leaves the VM as it is. Re-run `up` with the same
environment: it resumes from what the VM's state proves done. Or run one phase:

```sh
pwsh .local/bin/setup/vm-harness-vmware.ps1 install     # asks both passwords again
pwsh .local/bin/setup/vm-harness-vmware.ps1 boot
pwsh .local/bin/setup/vm-harness-vmware.ps1 bootstrap   # sudo password again; decrypt is skipped once done
pwsh .local/bin/setup/vm-harness-vmware.ps1 check
pwsh .local/bin/setup/vm-harness-vmware.ps1 tail bootstrap
```

Logs are in `~/vms/work-vm/logs`. If `check` reports the sudo drop-in (a run cut off
by a power loss), delete it in the VM: `sudo rm /etc/sudoers.d/89-first-bootstrap`.

`destroy` on this VM asks you to type its name; non-interactively it needs
`VM_HARNESS_DESTROY_REAL=work-vm`. It deletes `~/vms/work-vm`, logs included.

## Resetting

`vm-harness destroy` removes the whole VM state; `create` starts pristine. The only
cached artifact is the verified ISO (`~/.cache/bootstrap-harness/`), refreshed by
re-running `fetch`.
