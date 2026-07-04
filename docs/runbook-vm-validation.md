# Runbook: QEMU VM validation of bootstrap + manifests

Evidence artifact for Story 2.7 ([#46](https://github.com/amasover/dotfiles/issues/46)).
Harness: [`.local/bin/setup/vm-harness`](../.local/bin/setup/vm-harness). Validates
[`setup/bootstrap`](../.local/bin/setup/bootstrap) and the metapac groups in a
disposable VM before anything is trusted on metal (Story 2.10 gates metal runs).

## The loop

```bash
vm-harness fetch      # once per ISO refresh: download + sha256-verify latest archiso
vm-harness create     # 40G sparse qcow2 + cloud-init seed (fresh answers every time)
vm-harness install    # unattended: archiso's cloud-init runs archinstall --silent,
                      #   VM powers off; watch: tail -f ~/.local/share/bootstrap-harness/install.log
vm-harness boot       # boot installed disk headless, sshd forwarded to localhost:2222
vm-harness bootstrap  # ssh in: yadm clone → class workstation → repo bootstrap (attended)
vm-harness check      # assert: metapac unmanaged EXACTLY empty, services, graphical target
vm-harness destroy    # delete disk+seed (ISO cache kept) — next run is pristine
```

VM specifics (learned partly from the retired win10 VM's config): q35 + KVM, 4G/8vcpu,
**OVMF/UEFI** (win10 ran legacy BIOS; UEFI mirrors the refind metal setup), virtio
disk/net (win10's SATA was the slow path), user-mode net with ssh on `127.0.0.1:2222`,
serial logs in `~/.local/share/bootstrap-harness/`. Throwaway credentials
(`aaron`/`vm`, NOPASSWD sudo) — sshd is loopback-only, and the VM is disposable.

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
