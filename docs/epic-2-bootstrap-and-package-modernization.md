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

## Why This Matters

The existing bootstrap material is valuable, but risky. It encodes years of workstation setup knowledge, package choices, service setup, editor setup, desktop setup, and tool installation. However, it also references old Arch/AUR assumptions and may mutate the system in ways that are no longer safe.

This epic preserves the useful intent while making the bootstrap path safe to inspect, test, and eventually run. Package cleanup should be collaborative: inventory the local machine first, then ask Aaron targeted questions about specific package groups before deciding what belongs in install scripts.

---

## Current Repo Evidence

- `install.md` describes an old YADM-based install process and first-login workflow.
- `.local/bin/setup/install` is a large Bash script that installs packages, changes services, configures YADM remotes, and installs editor/tool dependencies.
- `.local/bin/setup/update` likely contains update behavior that needs classification.
- `.config/dotfiles/arch-packages/pacman` and `.config/dotfiles/arch-packages/aur` contain historical package manifests.
- `.zshrc` contains an `update` alias that points to an Ansible playbook outside this repo.

---

## Problem Statement

The repo cannot be trusted as a fresh-machine bootstrap until:

- Install scripts are classified as current, legacy, unsafe, or unknown
- Package lists are reviewed against the current machine and target OS
- Live installed packages are grouped by purpose and triaged with Aaron before being added, retained, or removed from bootstrap
- Destructive operations are gated behind explicit confirmation
- Dry-run or checklist-based setup exists
- Old assumptions are documented instead of silently executed

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

**Acceptance criteria:**

- Given current bootstrap options include Bash, YADM, package manifests, and possible Ansible, when reviewed, then a decision record documents the preferred direction
- Given YADM remains in use, when the bootstrap model is defined, then it explains what YADM owns versus what scripts own
- Given a future rewrite is deferred, when the decision is made, then the interim safe path is documented

**Evidence artifact:** Decision record under `docs/`

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

| Dependency | Owner | Due Date | Status | Blocked Story | Mitigation if Late |
| --- | --- | --- | --- | --- | --- |
| Phase 1 inventory complete | Aaron | Phase 2 start | Open | All | Do not modernize before safety inventory |
| Target OS/package manager confirmed | Aaron | Phase 2 | Open | 2.2, 2.3 | Keep package lists historical until confirmed |
| Current installed package list available | Aaron | Phase 2 | Open | 2.2 | Use repo-only package review |
| Aaron available for package triage questions | Aaron | Phase 2 | Open | 2.2 | Keep ambiguous packages in `unknown` until reviewed |
| Decision on YADM long-term use | Aaron | Phase 2 | Open | 2.5 | Continue with YADM for interim model |

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
