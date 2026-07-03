# Epic 2: Bootstrap and Package Modernization

**Priority:** High
**Status:** Draft
**Phase:** Phase 2 — inventory and bootstrap stabilization
**PRD Reference:** [prd.md](./prd.md)
**FR Alignment:** FR-1 (Repo and Live-Home Inventory), FR-4 (Product Documentation), FR-5 (Safe Commit and Sync Workflow)
**Outcome Type:** Recoverability + maintainability

---

## Objective

Turn the old install/update flow into a safe, staged, and documented bootstrap model for rebuilding a useful workstation without blindly executing stale scripts.

## Context

The bootstrap material (`install.md`, `.local/bin/setup/install` + `update`, `.config/dotfiles/arch-packages/{pacman,aur}`) encodes years of useful setup knowledge but carries old Arch/AUR assumptions and may mutate the system unsafely. The repo can't be trusted as a fresh-machine bootstrap until scripts are classified (current/legacy/unsafe/unknown), package lists are triaged against the live machine with Aaron, destructive ops are gated, and a dry-run path exists. Package cleanup is collaborative: inventory first, then ask targeted questions before changing install inputs. Background: [prd.md](./prd.md) §2–3, FR-6.

---

## Scope

### In Scope

- Review bootstrap scripts without executing them
- Classify package lists into core, shell, editor, desktop, development, cloud, media, gaming, optional, unknown, and legacy groups
- Inventory explicitly installed native packages and foreign/AUR packages from the local machine
- Ask Aaron targeted questions about ambiguous packages or package groups
- Identify stale tools such as old AUR helpers or deprecated distro packages
- Create a dry-run/checklist bootstrap runbook
- Define the minimum viable fresh-machine setup
- Identify which scripts should be rewritten, retained, archived, or deleted

### Out of Scope

- Running full bootstrap on the live machine
- Installing or removing packages automatically
- Rewriting the entire setup system in one pass
- Migrating to a new dotfile manager
- Building cross-platform support beyond the chosen Linux target

---

## Stories

### Story 2.1: Classify setup scripts

As the repo owner,
I want every setup script classified by safety and currentness,
So that I know what can be inspected, tested, rewritten, or archived.

Issue: [#16](https://github.com/amasover/dotfiles/issues/16) · Artifact: [bootstrap-inventory.md](./bootstrap-inventory.md)

**Acceptance criteria:**

- Given a script exists under `.local/bin/setup/`, when reviewed, then it is classified as current, legacy, unsafe, or unknown
- Given a script performs system mutations, when classified, then those mutations are listed at a high level
- Given a script should not be executed, when docs are updated, then the warning is explicit

**Evidence artifact:** Bootstrap inventory or runbook section

---

### Story 2.2: Inventory local packages and split manifests by purpose

As the repo owner,
I want package lists grouped by intent and checked against the actual installed package set,
So that a fresh-machine setup can install only what is needed.

Issue: [#24](https://github.com/amasover/dotfiles/issues/24) · Artifact: [package-inventory.md](./package-inventory.md)

**Acceptance criteria:**

- Given historical package lists exist, when reviewed, then packages are grouped into core, shell, editor, desktop, development, cloud, media, gaming, optional, unknown, and legacy categories
- Given the local package manager can report explicitly installed packages, when inventory runs, then native repo packages and foreign/AUR packages are captured separately
- Given a package is installed locally but missing from repo manifests, when reviewed, then it is classified as add-to-bootstrap, machine-local, optional, unknown, or remove-candidate
- Given a package is in repo manifests but not installed locally, when reviewed, then it is classified as legacy, stale, optional, or fresh-machine-only
- Given a package is deprecated or distro-specific, when retained, then it is marked as requiring verification
- Given a package purpose is ambiguous, when package triage reaches it, then Aaron is asked a targeted question before it is removed from install inputs

**Evidence artifact:** Package inventory docs, triage notes, or refactored package manifests

---

### Story 2.3: Define minimum viable bootstrap

As future Aaron on a new machine,
I want a minimal setup path,
So that I can become productive before restoring every desktop customization.

Design input: [bootstrap-architecture-notes.md](./bootstrap-architecture-notes.md) — Bash vs Ansible vs Go, idempotency, "not NixOS."

Issue: [#25](https://github.com/amasover/dotfiles/issues/25)

**Acceptance criteria:**

- Given a fresh Linux machine, when minimum bootstrap is followed, then shell, Git/YADM, editor basics, and core tools are installed or configured
- Given desktop customization is optional, when minimal bootstrap runs, then it does not require i3/polybar/rofi unless explicitly selected
- Given secrets are needed, when bootstrap reaches secret restore, then it uses YADM encryption guidance without printing secrets

**Evidence artifact:** Fresh-machine bootstrap runbook

---

### Story 2.4: Add dry-run/checkpoint behavior

As the repo owner,
I want bootstrap work to show what it would do before doing it,
So that I can avoid accidental system mutation.

Issue: [#26](https://github.com/amasover/dotfiles/issues/26)

**Acceptance criteria:**

- Given a setup command would install packages or change services, when dry-run mode is used, then it prints planned actions without executing them
- Given dry-run cannot be implemented immediately, when bootstrap docs are updated, then manual checkpoints are documented
- Given a script lacks safety gates, when reviewed, then it is not promoted as current

**Evidence artifact:** Script changes or runbook checklist

---

### Story 2.5: Decide future bootstrap architecture

As the repo owner,
I want a clear decision on the future bootstrap model,
So that cleanup does not drift into multiple half-supported approaches.

Issue: [#27](https://github.com/amasover/dotfiles/issues/27)

**Acceptance criteria:**

- Given current bootstrap options include Bash, YADM, package manifests, and possible Ansible, when reviewed, then a decision record documents the preferred direction
- Given YADM remains in use, when the bootstrap model is defined, then it explains what YADM owns versus what scripts own the bootstrap model is defined, then it explains what YADM owns versus what scripts own
- Given a future rewrite is deferred, when the decision is made, then the interim safe path is documented

**Evidence artifact:** Decision record under `docs/`

---

### Story 2.6: Quarantine AUR updates by a default delay

As the repo owner,
I want AUR package upgrades held back by a default delay (~2 weeks),
So that a freshly compromised AUR package (cf. the June 2026 AUR malware incident) is less likely to land on my machine immediately.

Issue: [#40](https://github.com/amasover/dotfiles/issues/40) · Implementation anchor: existing TODO at `.local/bin/setup/update:32` (line 33 runs `yay -Syu --devel --noconfirm ...`).

**Acceptance criteria:**

- Given `setup/update` upgrades AUR packages, when an AUR package's latest version is newer than a configurable threshold (default ~14 days), then it is skipped this run
- Given an AUR update is older than the threshold, when update runs, then it is upgraded normally
- Given native pacman/repo packages (signed Arch repos), when update runs, then they are NOT subject to the AUR delay
- Given I want to upgrade a held package (or everything) now, when I pass an override flag/env, then the delay is bypassed
- Given `-git`/`--devel` packages always build latest upstream, when the design is settled, then their handling under quarantine is decided and documented (the time-based delay means less for them)
- Given the mechanism ships, when documented, then the rationale (June 2026 AUR malware) and the override are recorded

**Notes / approach:**

- Likely approach: read `yay -Qua`, look up each AUR package's Last-Modified date via the AUR RPC, and skip updates newer than the threshold.
- Complementary control: consider running a scanner such as [`aur-malware-check`](https://github.com/lenucksi/aur-malware-check) over to-be-upgraded PKGBUILDs as a second layer, independent of the time delay.

**Evidence artifact:** Changes to `.local/bin/setup/update` (or a helper) + notes; resolves the `setup/update:32` TODO.

---

### Story 2.7: QEMU fresh-install validation harness

As the repo owner,
I want a repeatable QEMU/KVM harness that fresh-installs Arch and runs the bootstrap,
So that bootstrap and manifest changes are validated in a disposable VM before they are trusted on metal.

Issue: [#46](https://github.com/amasover/dotfiles/issues/46) · Design input: [decision-bootstrap-architecture.md](./decision-bootstrap-architecture.md) (validation strategy). `qemu-desktop` + `virt-manager` are already installed (Story 2.2 decision D6).

**Acceptance criteria:**

- Given a bootstrap or manifest change, when the harness runs, then a fresh Arch VM is created (scripted `archinstall` or equivalent) without manual install steps
- Given the bootstrap completes in the VM, when the result is inspected, then it matches expectations: `metapac unmanaged` reports no surprises, expected services are enabled, and the desktop session is reachable
- Given a validation run finishes, when the next one is needed, then the VM can be reset or recreated disposably (snapshot or rebuild)
- Given the harness exists, when documented, then a runbook covers creating, running, inspecting, and resetting the VM

**Evidence artifact:** Harness scripts + a runbook under `docs/`

---

### Story 2.8: Adopt metapac on the live workstation

As the repo owner,
I want the current workstation's packages declared in metapac groups and reconciled,
So that the package manifest is executable and complete — the base for any future bootstrap.

Issue: [#48](https://github.com/amasover/dotfiles/issues/48) · Design input: [decision-bootstrap-architecture.md](./decision-bootstrap-architecture.md) (package layer design; adoption on the live machine). Subsumes the open Story 2.2 follow-up "generate the grouped manifests from live state".

**Acceptance criteria:**

- Given metapac is not yet installed, when the story starts, then metapac is installed through yay (it is itself an AUR package) with explicit approval
- Given the Story 2.2 inventory, when groups are authored, then `.config/metapac/config.toml` sets `package_manager = "yay"` and `[hostname_groups]` maps this host to its purpose groups (including its own `inbox-<hostname>`), all YADM-tracked
- Given groups are authored, when adoption iterates, then `metapac unmanaged` comes back (near-)empty — the acceptance test for adoption
- Given adoption is incomplete, when reconciling, then `metapac clean` is not run (off-limits until `unmanaged` is clean)
- Given the groups replace them, when adoption completes, then the legacy flat manifests under `.config/dotfiles/arch-packages/` are retired (archived or deleted with a pointer)

**Evidence artifact:** Tracked metapac config + group files; adoption notes.

---

### Story 2.9: Steady-state capture loop (inbox + drift report)

As the repo owner,
I want ad-hoc installs auto-captured into a per-host inbox and drift reported on every update,
So that the declared groups stay honest without manual bookkeeping.

Issue: [#49](https://github.com/amasover/dotfiles/issues/49) · Depends on Story 2.8 (groups must exist to check declarations against). Design input: [decision-bootstrap-architecture.md](./decision-bootstrap-architecture.md) (auto-capture; drift loop).

**Acceptance criteria:**

- Given an explicit `yay -S` of a package not declared in any group, when the install succeeds, then a yay `PostInstall` Lua hook appends it to this host's `groups/inbox-<hostname>.toml` (upgrades — non-empty `local_version` — are skipped)
- Given a package is already declared in any group, when it is installed or synced, then it is not appended to the inbox
- Given `setup/update` finishes, when the run ends, then a read-only drift report (`metapac unmanaged` + declared-but-missing) prints, ending with the copy-paste `metapac sync` command — no auto-mutation
- Given raw `pacman -S` installs bypass yay hooks, when documented, then `metapac unmanaged` is the named backstop

**Evidence artifact:** Hook addition (`.config/yay/init.lua` or companion), `setup/update` changes, docs.

---

### Story 2.10: AUR install-time gating + portable trust baseline

As the repo owner,
I want fresh AUR installs gated like upgrades and the trust baseline portable across machines,
So that a fresh-machine bootstrap doesn't install freshly-weaponized AUR packages ungated.

Issue: [#50](https://github.com/amasover/dotfiles/issues/50) · Prerequisite for the first real-metal `bootstrap` run (Story 2.3); disposable 2.7 VM runs are exempt. Promotes the un-ticketed Story 2.6 follow-up (`AURPostDownload` gating); origin: 2026-07-02 grill of the 2.5 decision. Design input: [aur-malware-mitigation.md](../knowledge/reference/aur-malware-mitigation.md).

**Acceptance criteria:**

- Given an AUR package is being installed for the first time, when it is too new / orphaned / maintainer-changed vs the baseline, then an `AURPostDownload` hook warns and aborts, with an explicit bypass
- Given the trusted-maintainer baseline is machine-local state today, when this story lands, then the baseline is portable to a new machine (mechanism decided in-story: YADM-tracked, encrypted, or seeded from the repo) so the bootstrap can restore trust state before first use
- Given the 2.7 harness exists, when a fresh VM bootstrap installs the AUR set, then install-time holds behave as designed
- Given the gate ships, when documented, then the coverage table in `aur-malware-mitigation.md` is updated (the "malicious new package" row becomes covered)

**Evidence artifact:** Hook changes + baseline portability mechanism + updated threat-model doc.

---

## Acceptance Criteria (Epic Level)

- Setup scripts are classified by safety and currentness
- Local installed packages are inventoried or blocked with reason
- Package manifests are classified by purpose
- Ambiguous packages are queued for targeted questions to Aaron
- Minimum viable bootstrap is defined
- Dry-run or checkpoint behavior is specified
- Future bootstrap architecture decision is documented

---

## Dependencies

Per-story blockers live on the linked GitHub issues. Cross-cutting dependencies: see [prd.md](./prd.md) §17. Key gate: Phase 1 safety inventory must complete before modernizing.

---

## Risks

### Risk: Bootstrap script mutates the live machine during testing

**Likelihood:** Medium
**Impact:** High
**Mitigation:** Treat setup scripts as inspect-only until dry-run/checkpoint behavior exists.

### Risk: Package list modernization becomes a full distro migration

**Likelihood:** Medium
**Impact:** Medium
**Mitigation:** Confirm target OS before refactoring manifests deeply.

### Risk: Package triage becomes too noisy

**Likelihood:** Medium
**Impact:** Medium
**Mitigation:** Ask questions by package group first, then only ask about individual packages when the group is ambiguous.

### Risk: Minimum bootstrap becomes too large

**Likelihood:** High
**Impact:** Medium
**Mitigation:** Separate core productivity from desktop customization and optional apps.

---

## Done When

This epic is complete when the repo has a safe, documented path from fresh machine to useful workstation, even if full automation remains deferred.
