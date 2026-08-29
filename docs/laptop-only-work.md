# Laptop-only work

This queue filters open work whose acceptance evidence depends on the current Linux
laptop: live `$HOME`/YADM state, physical hardware and docks, boot/session behavior,
host package state, or its libvirt installation. GitHub issues and the project board
remain status sources; this file records why work belongs on this machine and useful
ordering.

## Working rules

- Capture read-only evidence before changing live state.
- Keep one story per branch and PR.
- Package, service, boot, YADM encryption, and root-level changes remain individually
  gated. Use `pkexec`, never bare `sudo`.
- Never paste raw home scans, credential-store paths, private hostnames, or
  machine-local package contents into tracked files or issues. Record safe path names,
  categories, counts, and decisions.
- Prefer perishable evidence first: attached monitors, current untracked files, and
  live package/service drift can disappear during unrelated cleanup.

## Recommended queue

### 1. Capture current home and hardware state

#### Story 3.17 — monitor-name migration ([#129](https://github.com/amasover/dotfiles/issues/129))

**Why laptop-only:** each autorandr profile must be rebuilt with its physical monitor
EDIDs and current `modesetting` output names. Polybar roles and i3 workspace placement
need real dock/undock verification.

**Remaining:** save and validate each available docking setup; add its layout override;
verify `autorandr --detected`, bar placement, and workspace placement after reconnect;
retire profiles whose hardware no longer exists. Do the currently attached setup before
moving docks.

#### Story 3.2 — classify editor configs ✅ ([#29](https://github.com/amasover/dotfiles/issues/29))

Completed decision: Vim is the terminal editor; Spacemacs is the workspace editor; OMP is
the agentic coding environment; VS Code is a secondary IDE; Neovim is a compatibility
frontend. IntelliJ is an archive/remove candidate. Details:
[editor-config-inventory.md](./editor-config-inventory.md).

#### Story 3.30 — modernize Spacemacs config ([#210](https://github.com/amasover/dotfiles/issues/210))

**Why laptop-only:** behavior-preserving cleanup needs the current GUI editor, active
packages/language tools, and real workflow evidence.

**Remaining:** baseline startup and retained workflows; audit the 900-line `.spacemacs`;
restore warnings/GC; fix YAML schema loss and debug output; prove or remove old workarounds;
measure and live-test every retained behavior under explicit approval.

#### Story 3.31 — integrate OMP into Emacs over ACP ([#214](https://github.com/amasover/dotfiles/issues/214))

**Why laptop-only:** the keep/drop decision needs the real Spacemacs workspace, OMP auth
boundary, interactive permission prompts, project context, and diff workflow.

**Remaining:** security-review `agent-shell`/`acp.el`; prototype its built-in `omp acp`
adapter under isolated state; compare against Copilot, Aider/Aidermacs, and old GPTel work;
then either declare/test a user-facing integration or remove the prototype.


#### Story 3.1 — clean shell config ([#28](https://github.com/amasover/dotfiles/issues/28))

**Why laptop-only:** tracked shell files must be compared with live startup behavior and
machine-local/secret inputs before cleanup.

**Remaining:** reconcile live differences, stale PATH entries, duplicate aliases and
functions, and local/secret boundaries without breaking the interactive shell.

#### Story 3.3 — classify desktop configs ([#30](https://github.com/amasover/dotfiles/issues/30))

**Why laptop-only:** current versus dead i3/polybar/rofi assets needs the running desktop
and live YADM state.

**Remaining:** classify each desktop surface; decide stale polybar backups and dead
bindings; decide tracked legacy font collections now superseded by packages; document
machine-specific layouts retained by Story 3.17.

#### Story 3.15 — encrypt-manifest leftovers ([#77](https://github.com/amasover/dotfiles/issues/77))

**Why laptop-only:** decisions depend on the live encrypt manifest, keyed local file,
and encrypted archive. Any accepted encryption update is attended and interactive.

**Remaining:** remove or re-justify stale encrypt patterns; encrypt-adopt or drop the
keyed `settings.json`; decide whether the private redaction note becomes encrypted
portable state. Never expose file contents in review output.

#### Story 3.20 — retire remaining `dot` CLI consumers (no dedicated issue)

**Why laptop-only:** acceptance requires a consumer scan across the repo and laptop's
live `$HOME`; historical shell usage may reveal consumers absent from tracked files.

**Remaining:** inventory remaining subcommands, replace or retire each consumer, and
confirm the already-removed binary has no live dependency. Open a dedicated issue before
pickup so status and decisions have a source of truth.

### 2. Verify boot, hardware, and host package decisions

#### Story 3.7 — start xidlehook with the desktop ([#14](https://github.com/amasover/dotfiles/issues/14))

**Why laptop-only:** completion requires a real login/boot and observed idle-lock/DPMS
behavior. `xidlehook` was not running during the 2026-08-27 check.

**Remaining:** choose one autostart owner, remove any retired competing logic, restart the
session or reboot, and verify lock/screen-off behavior.

#### Story 2.30 — machine class and hardware split ([#96](https://github.com/amasover/dotfiles/issues/96))

**Why laptop-only:** the hardware group must match this Intel laptop and produce a live
no-op reconcile. Current declarations still contain old AMD graphics packages and omit
`vulkan-intel`; existing inbox entries also need per-machine attribution.

**Remaining:** separate class from hardware groups, correct Intel/AMD GPU membership,
give guest and laptop distinct inboxes, render both classes, and prove the laptop dry run
is safe before any approved package mutation.

#### Story 2.25 — finish host .NET transition ([#82](https://github.com/amasover/dotfiles/issues/82))

**Why laptop-only:** repo declarations already use official packages; closure needs the
host's installed package transition and drift evidence.

**Remaining:** remove leftover `dotnet-*-bin` runtime/dependency packages under an
approved transaction; decide EOL `dotnet-runtime-2.1` and `2.2`; verify the resulting
manifest drift.

#### Story 2.43 — retire unused host Secure Boot packages ([#136](https://github.com/amasover/dotfiles/issues/136))

**Why laptop-only:** tracked declaration is already removed; only this host's installed
copies remain.

**Remaining:** decide uninstall versus retain-until-2.44 for `shim-signed`, `sbsigntools`,
and `mokutil-git`. Do not touch Ubuntu's live dual-boot shim or ESP files.

#### Story 2.18 — close reflector timer evidence ([#66](https://github.com/amasover/dotfiles/issues/66))

**Why laptop-only:** scheduled behavior and `/etc` policy need live service evidence.

**Remaining:** current laptop check already shows `reflector.timer` enabled and active;
attach that evidence plus tracked-policy/fresh-machine evidence, then close if issue
acceptance is otherwise met.

### 3. Use Linux-only host capabilities

#### Story 2.41 — converge libvirt guest glue ([#132](https://github.com/amasover/dotfiles/issues/132))

**Why this laptop:** it is the configured libvirt/QEMU host; Windows-side validation
cannot prove this path.

**Remaining:** replace inline guest commands with `vm-harness-guest`, preserve only
intentional hypervisor differences, then run a real libvirt `up` with QEMU hardware
parameters.

#### Fresh libvirt evidence batch

After Story 2.41 and pending bootstrap fixes land, one clean `destroy` → `up` can provide
fresh-run evidence for several open stories: 2.19 [#70](https://github.com/amasover/dotfiles/issues/70),
2.21 [#73](https://github.com/amasover/dotfiles/issues/73), 2.26 [#83](https://github.com/amasover/dotfiles/issues/83),
2.27 [#87](https://github.com/amasover/dotfiles/issues/87), 2.32 [#100](https://github.com/amasover/dotfiles/issues/100),
2.33 [#103](https://github.com/amasover/dotfiles/issues/103), 2.34 [#107](https://github.com/amasover/dotfiles/issues/107),
2.38 [#124](https://github.com/amasover/dotfiles/issues/124), and 2.45 [#144](https://github.com/amasover/dotfiles/issues/144).
Story 2.31 [#98](https://github.com/amasover/dotfiles/issues/98) additionally needs a
deliberate interrupt/resume run. Record each issue's exact evidence from the shared log
set; do not assume one green run automatically satisfies every criterion.

#### Epic 5 Story 5.4 Linux-host remainder

The closed guest-resolution issue [#151](https://github.com/amasover/dotfiles/issues/151)
left a Linux/libvirt remainder: enable the dormant pointer-calibration path with declared
`xinput` plus the evdev `InputClass`, then validate on the Linux host. Open a focused
follow-up issue before implementation because the original issue is closed.

### 4. Expand the agentic coding environment

- **Story 3.28 — OMP LSP workstation coverage ([#206](https://github.com/amasover/dotfiles/issues/206)):**
  declare the active cross-repo language servers, replace unowned global copies, and
  validate semantic operations on real/disposable projects.
- **Story 3.29 — OMP plugin evaluation ([#207](https://github.com/amasover/dotfiles/issues/207)):**
  source-review and isolate one agent, one hook, and one LSP plugin; promote only keepers
  that add unique value and can be reproduced.

### 5. Lower-priority live workflow evaluations

- **Story 3.13 — Atuin shell history ([#67](https://github.com/amasover/dotfiles/issues/67)):**
  local install/hook and Ctrl-R behavior need live-shell validation; server sync remains
  blocked on the homelab service.
- **Story 3.14 — Atuin Desktop ([#68](https://github.com/amasover/dotfiles/issues/68)):**
  install and exercise one real repo runbook on the daily workstation; record keep/drop.

## Explicitly not current-laptop work

- Story 2.29's first consumer is the Windows-hosted daily VM; spare-laptop metal install
  is later.
- Story 2.44 Secure Boot targets fresh provisioning; current workstation is explicitly
  out of scope.
- CI, vendored-package watches, nord-vim packaging, and metapac's `--needed`
  experiment can run in branches, containers, or disposable Arch guests. Use this laptop
  for them only when convenient, not because acceptance requires it.
- Home-server Meridian/Atuin deployment belongs on the homelab host.
