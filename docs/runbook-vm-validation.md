# Runbook: QEMU VM validation of bootstrap + manifests

Evidence artifact for Story 2.7 ([#46](https://github.com/amasover/dotfiles/issues/46)).
Harness: [`.local/bin/setup/vm-harness`](../.local/bin/setup/vm-harness). Validates
[`setup/bootstrap`](../.local/bin/setup/bootstrap) and the metapac groups in a
disposable VM before anything is trusted on metal (Story 2.10 gates metal runs).

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
vm-harness bootstrap  # waits for ssh, then: yadm clone → class workstation → repo
                      #   bootstrap --unattended (metapac sync --no-confirm inside)
vm-harness check      # assert: metapac unmanaged EXACTLY empty, services, graphical target
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
- **Walk away:** `vm-harness --detach up` runs under `systemd-run --user` — it
  survives the closed terminal, logs plain output, and sends a desktop
  notification on completion (success or failure). `vm-harness status` shows
  the detached unit, the domain state, and the newest log's tail.
- **On failure** (any phase, attached or not): the run stops at the failing
  phase and the VM is left exactly as it died — read the log, fix and re-run
  the phase, or `destroy` for a clean slate. `up` never auto-destroys.

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

- **Unattended install:** recent official archisos ship cloud-init; the seed ISO
  (NoCloud) writes `user_configuration.json`/`user_credentials.json` and runs
  `archinstall --silent` via `runcmd`, then powers off. Systemd-boot, ext4
  best-effort on `/dev/vda`, hostname `archvm`, sshd enabled, git/base-devel/yadm
  preinstalled to skip bootstrap preconditions.
- **VM accommodations:** the seed's `custom_commands` set the login shell to zsh at
  install time (bootstrap's `chsh` step self-skips — `chsh` would password-prompt
  over ssh), and `bootstrap --unattended` skips secret decrypt by design — a
  passphrase prompt can't run without a TTY, so no yadm passphrase or secret
  contents ever enter the harness. If a test needs real secrets, run `yadm decrypt`
  in the guest manually.
- **Profile guard in the VM:** `yadm config local.class workstation` + `yadm alt`
  renders the VM's own hostname into `config.toml` — the guard passes without any
  repo change; `machine-local.toml` is auto-created empty by bootstrap step 3.
- **The acceptance assert:** `vm-harness check` fails unless `metapac unmanaged` is
  exactly empty — same bar as live adoption (Story 2.8).

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
  reaching archinstall sooner. The serial stream also prints a
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
  `virsh send-key arch-harness KEY_ENTER` was the rescue).
- **The installed system keeps a serial console too**: its loader entries get
  `console=tty0 console=ttyS0` and `serial-getty@ttyS0` is enabled at install
  time — every later boot logs to the serial file, and
  `virsh -c qemu:///system console arch-harness` gives a login when ssh is down.
- **Serial output and terminal resizes:** full-screen phases (firmware, TUI
  redraws) draw for a fixed 80×24-ish geometry; a serial line carries no resize
  signal back to the guest, so resizing the watching terminal garbles the
  picture until the next linear output. Inherent to serial consoles — wait it
  out or don't resize mid-TUI.
- **Class profile**: `vm-harness bootstrap` sets `yadm config local.class` to
  `$VM_HARNESS_CLASS` (default `workstation` — the full 16-group daily-driver set,
  ~375 packages; that's the profile 2.7 exists to prove). When other classes exist,
  validate them with e.g. `VM_HARNESS_CLASS=laptop vm-harness bootstrap`.

- `vm-harness bootstrap` runs `bootstrap --unattended` in the guest (no prompts),
  but the AUR set (dotnet, storageexplorer, etc.) builds for **hours** in the VM.
  A closed terminal kills an *attached* harness run (the qemu process survives;
  the driver doesn't) — use `--detach` when walking away.
- The VM clones the repo from **GitHub main** — bootstrap-affecting PRs must merge
  before their VM validation run (or pass a branch clone URL via `VM_HARNESS_REPO`).
- archinstall's network choice is the ISO's (systemd-networkd/dhcp); `metapac sync`
  later installs `networkmanager-iwd` per the groups — the replace prompt inside the
  sync run is expected (`--no-confirm` answers it in harness runs).
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

## Resetting

`vm-harness destroy` removes the whole VM state; `create` starts pristine. The only
cached artifact is the verified ISO (`~/.cache/bootstrap-harness/`), refreshed by
re-running `fetch`.
