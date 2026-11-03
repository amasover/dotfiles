# Decision: the first daily-driver rebuild is an aarch64 work VM on the Mac

**Date:** 2026-11-02
**Status:** Accepted
**Origin:** work-laptop replacement, 2026-11-02 — the old work laptop was wiped and
returned; the employer issued an Apple Silicon Mac (M5 Pro, 24 GB).
**Supersedes in part:** [decision-daily-driver-vm.md](./decision-daily-driver-vm.md)
(first target and the Story 1.8 exit condition; the trust and LUKS choices stand)
**Related:** [CONTEXT.md](../CONTEXT.md) · [epic-5-guest-daily-driver.md](./epic-5-guest-daily-driver.md)
(Mac work VM story) · Story 2.29 (#95, provisioning recipe) · Story 2.30 (class model)

## Decision

The first **daily-driver rebuild** target is **the work VM**: native aarch64 Arch
Linux under VMware Fusion Pro on the employer Mac, class `work-vm`. It is
installed from archiso-aarch64 against the unofficial Arch Linux Ports repositories
(drzee.net) and bootstrapped by the same harness model as the Windows target.
The Windows-hosted `daily-vm` and a bare-metal install become later, optional
variants of the same recipe.

The cleanup era no longer waits on the old work machine's Story 1.8
history-rewrite recovery. That machine is gone and was wiped, so the condition
can never be met and nothing on it needs recovering. The exit is the daily-driver
rebuild alone.

Supporting choices, decided together:

- **Guest OS: Arch Linux Ports (drzee), not Asahi.** Asahi Linux does not support
  the M5: its [M5 feature-support page](https://asahilinux.org/docs/platform/feature-support/m5/)
  lists the installer as "no" and every hardware block as TBA. Asahi would also
  replace macOS as the host, and meetings stay on macOS.
- **Repositories: Arch Linux Ports, not Arch Linux ARM.** The Ports repos
  (`core`, `extra`, `forge` for aarch64, ARMv8.2+) rebuild Arch's own package set,
  so the purpose groups resolve with few substitutions; drzee extra carries
  open-vm-tools, mesa, xorg-server, i3-wm, polybar, emacs, zsh, archinstall and
  cloud-init. Arch Linux ARM is board-oriented and follows its own tree, so more
  of the package groups would need per-architecture forks. Ports lose on one point:
  no `xf86-video-vmware`, so Xorg runs modesetting on vmwgfx.
- **Hypervisor: VMware Fusion Pro, not UTM.** Fusion gives arm64 Linux guests
  accelerated OpenGL 4.3 through vmwgfx; UTM's Linux-guest 3D is virgl, still
  experimental on macOS. Fusion's "Use All Displays in Full Screen" spans the VM
  across the Mac panel and the external 4K, which the daily layout depends on.
  Fusion also shares the Mac camera with the guest, which later Slacky huddles
  need. UTM is free and open source, but neither benefit outweighs a desktop that
  is the daily driver.
- **Secrets: full archive, host trusted.** Unchanged from the Windows decision:
  the guest decrypts the full encrypted archive and keeps a LUKS root. The Mac host
  can read guest memory and disk regardless, and the old work laptop already
  carried full secrets on hardware not fully controlled.
- **Architecture adapters, not forked purpose groups.** x86-only packages move
  from the shared purpose groups into `arch-x86_64`; aarch64 substitutes go in
  `arch-aarch64`. `config.toml##template,os.Linux` includes the adapter matching
  `yadm.arch` (`uname -m`) for every class. Shared groups stay
  architecture-neutral. Per-class package lists would duplicate the purpose set
  per architecture. A skip-missing bootstrap mode would hide packages that are
  genuinely missing, so bootstrap still fails loudly on them.
  `xf86-video-vmware` moves to `guest-vmware-x86_64`, used only by `daily-vm`.
- **Class model.** `work-vm` = the common purpose groups + `guest-vmware` +
  `work` + `inbox-work-vm` + the machine-local group. The `workstation` class and
  `inbox-workstation` are retired with the work laptop. The `hardware-intel-laptop`
  adapter, the autorandr profiles and the `.screenlayout` scripts stay for a planned
  personal Linux laptop.

## Why this is recorded

The target change reverses the Windows-first sequencing that Story 2.29, Story 2.37
and Epic 5 were planned around. It also adds a second CPU architecture to every
package decision. Each supporting choice beat a concrete alternative for a stated
reason, and first-boot evidence is still missing: nobody had reported
archiso-aarch64 booting in a VM when this was decided.

## Consequences

- Epic 5 gains the Mac work VM story: Fusion recipe and harness under PowerShell 7
  on macOS, class `work-vm`, architecture adapters, multi-display and HiDPI tuning,
  and later camera/mic for Slacky.
- The `vmware-aarch64` (disposable) and `work-vm` (LUKS) provisioning targets
  join `provision-seed`; the Windows `daily-vm` record is no longer the next gate.
- Story 3.17 closes: the laptop-bound autorandr profiles and `.screenlayout`
  scripts are retired, not re-captured.
- The milestone bar is still the runbook's daily-drivable acceptance checklist.
