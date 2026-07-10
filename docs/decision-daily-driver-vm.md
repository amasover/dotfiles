# Decision: the first daily-driver rebuild is a VM on the Windows personal machine

**Date:** 2026-07-10
**Status:** Accepted
**Origin:** repo-direction grill, 2026-07-10 (Q1–Q7)
**Related:** [CONTEXT.md](../CONTEXT.md) era terms · [prd.md](./prd.md) ·
[runbook-fresh-machine-bootstrap.md](./runbook-fresh-machine-bootstrap.md) (acceptance checklist) ·
Story 2.29 (#95, provisioning recipe) · Story 2.30 (class + hardware split)

## Decision

The cleanup era ends on two conditions: (1) a **daily-driver rebuild** — bootstrapping,
from nothing but this repo and the encrypted archive, a machine that then gets used
daily — and (2) the work machine completing its Story 1.8 history-rewrite recovery
steps. The first rebuild target is **a VM under VMware Workstation on the Windows
personal machine**, not bare metal; a spare-laptop metal run is a later, optional
variant of the same recipe.

Supporting choices, decided together:

- **Hypervisor: VMware Workstation** (free for personal use). Chosen for the only
  first-class Linux-guest 3D acceleration among the candidates — a daily i3 desktop
  and the `gaming` group live or die on it. Hyper-V rejected (no practical Linux 3D;
  xrdp session hack); VirtualBox rejected (weak 3D); WSL2 rejected (runs apps, not
  the platform — no archinstall, bootloader, or full session to rehearse).
- **Class model:** the VM is its own machine class (working name `daily-vm`,
  finalized in Story 2.30) activating every purpose group except `work` and the new
  `hardware` group, plus a hypervisor guest-tools group (`open-vm-tools`,
  `xf86-video-vmware`). The nine hardware-bound packages (`acpi`, `acpid`,
  `intel-ucode`, `linux-firmware`, `refind`+theme, `xf86-video-{amdgpu,intel,vesa}`)
  move out of `base`/`desktop` into `hardware`, activated only by metal classes —
  keeping the shared groups honest instead of forking VM variants.
- **Secrets: full archive, host trusted.** The VM decrypts the real archive; the
  Windows host is accepted into the trust boundary (it can read guest memory/disk
  regardless). A second-tier secret set was rejected as permanent curation friction
  against an adversary who already owns the host. Precedent: the work machine already
  carries full secrets on hardware not fully controlled.
- **LUKS inside the guest** anyway: protects the VM disk file at rest (host theft,
  host backups). Provisioned by the Story 2.29 recipe, whose primary consumer is now
  this VM — metal inherits the recipe later.

## Why this is recorded

Reversal cost is real (class branches, groups, guest tooling, provisioning recipe all
encode it), the choice contradicts the PRD's original metal-centric cleanup framing,
and each supporting choice beat concrete alternatives for stated reasons.

## Consequences

- Story 2.29's spec is amended: daily-VM first, metal later.
- Epic 3 (shell/editor/desktop) deliberately follows the VM bring-up: living in the
  rebuilt environment turns classification archaeology into triage of observed friction.
- The milestone bar is the runbook's daily-drivable acceptance checklist; nothing
  outside it blocks the milestone.
