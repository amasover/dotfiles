# Runbook: QEMU VM validation of bootstrap + manifests

Evidence artifact for Story 2.7 ([#46](https://github.com/amasover/dotfiles/issues/46)).
Harness: [`.local/bin/setup/vm-harness`](../.local/bin/setup/vm-harness). Validates
[`setup/bootstrap`](../.local/bin/setup/bootstrap) and the metapac groups in a
disposable VM before anything is trusted on metal (Story 2.10 gates metal runs).

## The loop

```bash
vm-harness fetch      # once per ISO refresh: download + sha256-verify latest archiso
vm-harness create     # pool volumes: 40G qcow2 + ISO + cloud-init seed (fresh answers)
vm-harness install    # unattended: archiso's cloud-init runs archinstall --silent,
                      #   VM powers off, media auto-ejected; watch the virt-manager console
vm-harness boot       # start the domain; prints its NAT IP when the lease appears
vm-harness ip         # the VM's IPv4 (ssh aaron@$(vm-harness ip))
vm-harness bootstrap  # ssh in: yadm clone → class workstation → repo bootstrap (attended)
vm-harness check      # assert: metapac unmanaged EXACTLY empty, services, graphical target
vm-harness destroy    # undefine domain + delete disk/seed volumes — next run is pristine
```

The VM is a **first-class libvirt domain** — `arch-harness` on `qemu:///system`, visible
and attachable in **virt-manager** (Aaron's ask, 2026-07-04), with storage as managed
volumes in the `default` pool and NAT networking (no port forwards). VM shape (learned
partly from the retired win10 VM's config): q35 + KVM, 4G/8vcpu, **OVMF/UEFI** (win10
ran legacy BIOS; UEFI mirrors the refind metal setup), virtio disk/net (win10's SATA
was the slow path). Throwaway credentials (`aaron`/`vm`, NOPASSWD sudo, host pubkey
pre-authorized) — reachable only from this host's NAT, and the VM is disposable.
The serial log (`~/.local/share/bootstrap-harness/install.log`, **root-owned** by
virtlogd — `sudo cat` to read) carries the `HARNESS-*` markers; install success is
asserted via libvirt itself (disk-volume allocation), and archinstall's TUI errors
show on the virt-manager console.

## How the pieces fit

- **Unattended install:** recent official archisos ship cloud-init; the seed ISO
  (NoCloud) writes `user_configuration.json`/`user_credentials.json` and runs
  `archinstall --silent` via `runcmd`, then powers off. Systemd-boot, ext4
  best-effort on `/dev/vda`, hostname `archvm`, sshd enabled, git/base-devel/yadm
  preinstalled to skip bootstrap preconditions.
- **VM accommodations (no bootstrap changes needed):** the seed's `custom_commands`
  set the login shell to zsh at install time (bootstrap's `chsh` step self-skips —
  `chsh` would password-prompt over ssh), and `vm-harness bootstrap` touches
  `~/.zshenv` so the secrets step self-skips (no yadm passphrase inside VMs; secret
  contents never enter the harness).
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

- `vm-harness bootstrap` is **attended**: `metapac sync` shows its plan and prompts,
  and the AUR set (dotnet, storageexplorer, etc.) builds for **hours** in the VM.
  Run it in a spare terminal; ssh disconnects don't kill the qemu process.
- The VM clones the repo from **GitHub main** — bootstrap-affecting PRs must merge
  before their VM validation run (or pass a branch clone URL via `VM_HARNESS_REPO`).
- archinstall's network choice is the ISO's (systemd-networkd/dhcp); `metapac sync`
  later installs `networkmanager-iwd` per the groups — a replace prompt inside the
  sync run is expected, answer it (attended run).
- First `yay -Syu` inside the VM is quarantine-gated like any machine (2.6 hook
  arrives with the dotfiles; baseline seeded by bootstrap step 7).
- Install-time AUR gating does not exist until **2.10** — VM runs accept that risk
  by design; metal runs do not (bootstrap's metal gate).

## Resetting

`vm-harness destroy` removes the whole VM state; `create` starts pristine. The only
cached artifact is the verified ISO (`~/.cache/bootstrap-harness/`), refreshed by
re-running `fetch`.
