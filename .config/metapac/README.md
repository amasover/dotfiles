# metapac — declarative packages

[metapac](https://github.com/ripytide/metapac) reconciles installed packages
against what's declared here: `metapac sync` installs the declared set,
`metapac unmanaged` shows drift.

- **`groups/*.toml`** — shared packages by purpose plus concrete hardware
  adapters and one inbox per class. Plain tracked files, read directly at sync
  time; no render step.
- **`profiles/common.groups`** — the one shared 15-purpose list included by every
  class branch. Add a universal purpose group here once, not in every profile.
- **`config.toml##template`** — maps the rendered hostname to the selected class
  and adds the architecture adapter `arch-{{ yadm.arch }}` to every class.
  YADM renders `config.toml` on clone/pull/class change; hostnames and `$HOME`
  paths remain machine-local.

  | Class | Machine | Added groups |
  | --- | --- | --- |
  | `work-vm` | Mac-hosted VMware Fusion aarch64 work VM | `guest-vmware`, `work`, `inbox-work-vm` |
  | `daily-vm` | Windows-hosted VMware daily driver | `guest-vmware`, `guest-vmware-x86_64`, `inbox-daily-vm` |
  | `qemu-harness` | Disposable libvirt validation guest | `guest-qemu`, `inbox-qemu-harness` |
  | `portable` | Portable drive booting any x86_64 UEFI machine | `hardware-portable`, `inbox-portable` |

- **`groups/arch-x86_64.toml` / `groups/arch-aarch64.toml`** — architecture
  adapters. Shared purpose groups stay architecture-neutral: a package that
  exists only as an x86_64 binary (prebuilt `-bin` artifacts, chaotic-aur,
  every `lib32-*`) lives in `arch-x86_64`, and its aarch64 substitute, if any,
  in `arch-aarch64` (Arch Linux Ports repos). AUR source builds whose `arch=()`
  merely omits aarch64 stay shared: aarch64 builds them with
  `makepkg --ignorearch`. Bootstrap still fails loudly on a missing package.
- **`~/.local/share/metapac/machine-local.toml`** — untracked group for
  never-publish package names only. Hardware belongs in tracked class adapters;
  bootstrap creates this file empty on fresh machines.
- **`known-broken.toml`** — NOT a group: declared packages a human recorded as
  unbuildable (Story 2.38). Unattended runs skip them while the AUR commit is
  unmoved. Managed only via `aur-quarantine broken`/`unbroken`, never by hand
  or by a failure; metapac itself ignores the file.

Why the profile knob is yadm's (`local.class`) rather than metapac's, and the
rest of the design: [docs/decision-bootstrap-architecture.md](../../docs/decision-bootstrap-architecture.md).
Fresh-machine flow: [docs/runbook-fresh-machine-bootstrap.md](../../docs/runbook-fresh-machine-bootstrap.md).
