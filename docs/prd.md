# Product Requirements Document (PRD)
## Dotfiles — Personal Workstation Platform

**Owner:** Aaron
**Status:** Draft v0.1
**Version:** 0.1
**Last Updated:** 2026-06-20
**Audience:** Aaron, future maintainers, AI coding agents

> **Scope boundary:** This PRD covers the `dotfiles` repository and its relationship to the live home directory at `$HOME`. It does not require immediate replacement of the operating system, desktop environment, editor stack, or package manager.

---

## 1. Overview

This PRD defines the next stage of the `dotfiles` repository as a **personal workstation platform**.

The product being improved is the ability to:

1. Keep the current daily workstation correct, understandable, and recoverable
2. Preserve useful local customizations without accidentally committing secrets
3. Rebuild a familiar environment on a fresh Linux machine
4. Separate current behavior from stale historical configuration
5. Make future cleanup safe for both humans and AI coding agents
6. Document enough context that old decisions can be understood without archaeology

The repo should remain personal and pragmatic. The goal is not to create a generic public dotfiles framework. The goal is to make Aaron's actual environment maintainable again.

---

## 2. Background and Context

The repo appears to have started as an Arch Linux + i3 workstation setup managed by YADM. Current evidence includes:

- `README.md` — older product framing around an i3 desktop environment and automatic setup
- `install.md` — old first-install and first-login guide
- `.yadm/encrypt` — encrypted-file manifest for sensitive local files
- `.zshrc` — large interactive shell configuration with duplicated aliases and machine-specific assumptions
- `.local/bin/setup/install` — older bootstrap script with stale package/tooling assumptions
- `.config/dotfiles/arch-packages/` — historical Arch package manifests
- `.config/i3/`, `.config/polybar/`, `.config/rofi/`, `.config/dunst/` — desktop environment configuration surfaces
- `.spacemacs`, `.vimrc`, `.config/nvim/`, `.config/Code/` — editor configuration surfaces

The repo has not been actively maintained for several years, while the live machine has continued to evolve. Therefore, the live home directory at `$HOME` is a required source of current-state truth.

---

## 3. Problem Statement

### Current State

The current state has several risks:

- The repo may not match the actual workstation at `$HOME`
- Local changes may be unsynced, unstaged, or uncommitted
- Some tracked configuration may be obsolete or broken
- Some scripts may mutate the system unsafely if run today
- Some package lists include old or deprecated Arch/AUR assumptions
- Local installed packages have not yet been inventoried or triaged against what should remain in bootstrap
- Shell configuration contains duplication and machine-specific paths
- Sensitive files are partially governed by YADM encryption, but coverage needs review
- Documentation reflects the older product more than the current desired product

### Why This Matters

If the repo remains untidy, the owner keeps paying these costs:

- Fear of syncing changes because secret exposure or breakage is unclear
- Loss of confidence in bootstrapping a new machine
- Harder recovery after workstation failure
- Repeated rediscovery of old scripts, aliases, and desktop behaviors
- More risk when AI agents edit files without understanding YADM and live-home mapping
- Inability to distinguish valuable legacy config from junk

### Desired State

The desired state is a dotfiles repo where:

- The repo is safely reconciled with `$HOME`
- Sensitive files are encrypted or excluded intentionally
- The default workflow is inspect, compare, document, then change
- Bootstrap scripts are idempotent or clearly marked legacy
- Local package inventory is used to decide what packages are still needed, optional, stale, or missing from install scripts
- Shell/editor/desktop config is modular enough to maintain
- Old Arch/i3 assets are either supported, archived, or removed with rationale
- Docs explain what the product is, how to change it, and how to validate changes

---

## 4. Product Vision

The product vision is to make `dotfiles` a reliable personal workstation control plane: one place to understand, reproduce, and safely evolve Aaron's working environment.

In practical terms, the repo should help Aaron:

- Know what is actually active on the current machine
- Commit useful local changes with confidence
- Keep secrets out of plaintext Git history
- Rebuild core shell/editor/tooling on a new machine
- Preserve desktop customizations without letting stale assets dominate the repo
- Use AI assistance safely through explicit repo instructions and validation rules

---

## 5. Goals

### Primary Goals

1. Reconcile tracked dotfiles with the live home directory at `$HOME`
2. Establish secret-safe YADM workflows for encrypted files
3. Create current product documentation and cleanup epics
4. Modernize bootstrap/install guidance around safe dry runs and staged setup
5. Inventory local packages and use guided triage to decide what belongs in install scripts
6. Make shell/editor/desktop configuration easier to understand and change
6. Preserve useful legacy context while removing or archiving dead config
7. Enable future AI-assisted maintenance through `.github/copilot-instructions.md`

### Secondary Goals

1. Reduce duplicated aliases, functions, and machine-specific assumptions
2. Improve package list organization through current-machine inventory and targeted package questions
3. Create a fresh-machine validation path
4. Make personal scripts discoverable and categorized
5. Keep public-facing docs safe and sanitized

---

## 6. Non-Goals

1. This project is not a generic dotfiles framework for all users
2. This project does not require switching away from YADM immediately
3. This project does not require replacing the current desktop environment
4. This project does not require a complete rewrite of install scripts in Release 1
5. This project does not require deleting all historical Arch/i3/Spacemacs assets
6. This project does not require publishing private workstation details
7. This project does not require running destructive setup scripts during planning

---

## 7. MVP Scope — Release 1

### In Scope

| FR | Capability | Notes |
| --- | --- | --- |
| FR-1 | Repo and Live-Home Inventory | Compare key tracked files to `$HOME` |
| FR-2 | Secret Safety and YADM Encryption | Review `.yadm/encrypt`, encrypted payload handling, and secret hotspots |
| FR-3 | Copilot Instructions | Codify AI agent rules for safe dotfiles work |
| FR-4 | Product Documentation | Create PRD, epics, and validation workflow docs |
| FR-5 | Safe Commit Plan | Define staged commit sequence before syncing changes |
| FR-6 | Local Package Inventory and Triage | Compare live installed packages to repo manifests and ask targeted questions before changing install inputs |

### Explicitly Deferred

| Item | Notes |
| --- | --- |
| Full install script rewrite | Phase 2 after inventory and validation model exist |
| Package list modernization | Phase 2 after current machine package reality is known and package groups have been triaged with Aaron |
| Desktop environment redesign | Phase 3 unless current workflow requires it sooner |
| Migration away from YADM | Only if a later decision record justifies it |
| Automated CI for dotfiles | Phase 2+ after validation targets are clearer |

### Exit Criteria for Release 1

Release 1 is complete when all of the following are true:

- [ ] `.github/copilot-instructions.md` exists and covers YADM, secrets, live-home checks, and destructive command safety
- [ ] `docs/prd.md` exists and reflects the product direction
- [ ] Initial epics exist under `docs/`
- [ ] A validation workflow exists for docs, shell scripts, YADM status, secret scans, package inventory, and live-home comparisons
- [ ] Initial read-only local package inventory commands and package triage workflow are documented
- [ ] High-risk secret surfaces are reviewed before staging commits
- [ ] A staged commit plan exists for syncing local changes safely

---

## 8. Users and Stakeholders

### Primary User

- Aaron, as the owner and daily user of the workstation

### Secondary Users

- Future Aaron on a new machine
- AI coding agents assisting with cleanup
- Any trusted collaborator reviewing the repo

### User Needs

Users need to:

- Understand which files are current and which are legacy
- Safely compare repo files to live-home files
- Avoid leaking secrets
- Know which scripts are safe to inspect versus execute
- Rebuild core workstation behavior when needed
- Decide which installed packages are still needed through guided review rather than guesswork
- Make changes in small, reviewable commits

---

## 9. Current Maturity Assessment

### Earlier-Stage Signs

- Documentation is old and references historical setup assumptions
- Bootstrap scripts are large and potentially unsafe to execute today
- Package lists include deprecated or old distro-era entries
- Shell configuration is duplicated and not clearly modular
- Current live-home state is not yet reconciled with repo state

### Later-Stage Signs

- YADM is already in use for Git-backed dotfiles management
- YADM encryption is already configured for sensitive paths
- Many configs and scripts are already versioned
- The repo has enough structure to become maintainable without starting over
- AI-specific instructions now exist to prevent unsafe edits

### Working Interpretation

The repo is not broken beyond repair. It is a valuable personal platform that needs safety rails, inventory, and modernization before large cleanup begins.

---

## 10. Desired Future State

The target future state is a repo where:

- Core files match intentional live-home behavior
- Secrets are encrypted or excluded
- Setup scripts can be run in dry-run or staged mode
- Package manifests are categorized, current, and derived from both repo history and live package inventory
- Desktop/editor/shell configs are documented and modular
- Legacy assets are clearly labeled as current, archived, or deprecated
- A fresh-machine bootstrap can be tested without guesswork
- AI agents can assist without exposing secrets or mutating the machine unexpectedly

---

## 11. Functional Requirements

### FR-1: Repo and Live-Home Inventory

**Priority:** Critical
**Release:** v1
**Description:** The repo must be reconciled against the actual live home directory before cleanup decisions are made.

**Acceptance Criteria:**

- Given a tracked dotfile exists in the repo, when it maps to a live path under `$HOME`, then the cleanup process checks whether the live file differs before editing
- Given repo and live-home versions differ, when a change is proposed, then the decision states whether the repo version, live version, or a merged version should win
- Given a file is machine-specific, when it is retained, then its machine-specific nature is documented or isolated

**Evidence artifact:** Inventory notes, PR description, or decision record

---

### FR-2: Secret Safety and YADM Encryption

**Priority:** Critical
**Release:** v1
**Description:** Sensitive files must be protected through YADM encryption or excluded from plaintext tracking.

**Acceptance Criteria:**

- Given a file contains credentials, tokens, SSH material, cloud config, private hostnames, or publishing credentials, when it is considered for tracking, then it is either covered by `.yadm/encrypt` or explicitly excluded
- Given `.yadm/files.gpg` changes, when it is staged, then the change is tied to an intentional encrypted-file update
- Given an AI agent inspects the repo, when it encounters encrypted paths, then it must not print decrypted contents

**Evidence artifact:** `.yadm/encrypt` review, secret scan output, PR checklist

---

### FR-3: AI Maintenance Instructions

**Priority:** Critical
**Release:** v1
**Description:** The repo must include Copilot instructions that constrain AI-assisted edits.

**Acceptance Criteria:**

- Given an AI agent works in the repo, when it reads `.github/copilot-instructions.md`, then it understands YADM, live-home checks, secret handling, and destructive command restrictions
- Given an edit touches shell, editor, desktop, script, package, or encrypted surfaces, when the AI proposes a change, then it includes validation guidance and risk notes

**Evidence artifact:** `.github/copilot-instructions.md`

---

### FR-4: Product Documentation

**Priority:** High
**Release:** v1
**Description:** The repo must define the product, cleanup phases, and backlog structure.

**Acceptance Criteria:**

- Given the repo is being cleaned up, when planning starts, then `docs/prd.md` defines goals, non-goals, MVP, risks, dependencies, and open questions
- Given implementation begins, when work is decomposed, then epics under `docs/` describe shippable cleanup slices
- Given a future maintainer reads the docs, then they can distinguish current, legacy-supported, archived, and unknown surfaces

**Evidence artifact:** `docs/prd.md`, epic docs, runbooks

---

### FR-5: Safe Commit and Sync Workflow

**Priority:** High
**Release:** v1
**Description:** Local changes must be staged and committed in a safe order.

**Acceptance Criteria:**

- Given local changes exist, when commits are prepared, then secret scan and YADM status are reviewed first
- Given a large cleanup is proposed, when commits are created, then docs/instructions, inventory, secret hygiene, shell cleanup, bootstrap cleanup, and desktop/editor cleanup are separated where practical
- Given encrypted files change, when commits are staged, then `.yadm/files.gpg` is committed only with a clear explanation

**Evidence artifact:** Commit plan, PR/checklist, `yadm status` summary

---

### FR-6: Local Package Inventory and Triage

**Priority:** High
**Release:** v1/v2
**Description:** The repo must use the actual installed package set as evidence before changing package manifests or install scripts.

**Acceptance Criteria:**

- Given local package inventory commands are available, when package cleanup begins, then explicitly installed repo packages and foreign/AUR packages are exported or summarized before package manifests are edited
- Given a package exists on the live machine but not in repo manifests, when reviewed, then it is classified as add-to-bootstrap, machine-local, optional, unknown, or remove-candidate
- Given a package exists in repo manifests but not on the live machine, when reviewed, then it is classified as legacy, stale, optional, or fresh-machine-only
- Given a package purpose is ambiguous, when triage reaches it, then Aaron is asked a targeted question about that package or package group before it is removed from install inputs
- Given a package manager helper or distro-specific package is deprecated, when retained, then the docs explain whether it is legacy context or still part of the target bootstrap

**Evidence artifact:** Local package inventory, package triage notes, updated package manifests or bootstrap docs

---

## 12. Non-Functional Requirements

### NFR-1: Safety

**Description:** Cleanup must not risk secret exposure or accidental workstation mutation.
**Target:** 100% of changes touching sensitive or executable surfaces include a safety review.
**Verification:** PR checklist or commit notes.
**Priority:** Critical

### NFR-2: Recoverability

**Description:** The repo should help recover or rebuild the workstation.
**Target:** Core shell/editor/bootstrap docs are sufficient to restore a usable environment on a fresh Linux machine.
**Verification:** Fresh-machine or container/VM walkthrough.
**Priority:** High

### NFR-3: Maintainability

**Description:** Configuration should be understandable without relying on memory.
**Target:** High-impact files have either clear structure or companion docs explaining their role.
**Verification:** Review of `.zshrc`, setup scripts, package lists, and docs.
**Priority:** High

### NFR-4: Idempotence

**Description:** Bootstrap steps should be safe to rerun or clearly marked as one-time/manual.
**Target:** Any Release 2 install/update script work includes dry-run or checkpoint behavior.
**Verification:** Script review and dry-run output.
**Priority:** Medium

### NFR-5: Portability

**Description:** Machine-specific configuration should not block use on another machine.
**Target:** Machine-specific paths, monitors, hostnames, and credentials are isolated or documented.
**Verification:** Live-home comparison and fresh-machine checklist.
**Priority:** Medium

---

## 13. Success Metrics

| Metric | Baseline | Target | Window | Data Source |
| --- | --- | --- | --- | --- |
| High-impact files reconciled against `$HOME` | TBD | 100% for Release 1 list | Release 1 | Inventory notes |
| Secret hotspots reviewed before commit | TBD | 100% | Every cleanup batch | Secret scan + checklist |
| Docs created for product direction and cleanup | 0 | PRD + initial epics + validation runbook | Release 1 | `docs/` |
| Bootstrap scripts marked safe, unsafe, or legacy | TBD | 100% of setup scripts | Phase 2 | Script inventory |
| Local packages inventoried and triaged | TBD | 100% of explicitly installed packages categorized or deferred with reason | Phase 2 | Package inventory |
| Fresh-machine bootstrap confidence | Unknown | Documented walkthrough completed | Phase 2 | Runbook evidence |

---

## 14. Governance and Decision Rights

Aaron is both product owner and primary user.

| Decision | Owner | Evidence |
| --- | --- | --- |
| Adopt live-home change into repo | Aaron | Inventory/commit notes |
| Archive or delete old config | Aaron | Decision record or PR note |
| Add encrypted file path | Aaron | `.yadm/encrypt` diff |
| Run destructive setup command | Aaron | Explicit approval |
| Install a package needed for cleanup tooling | Aaron | Explicit approval |
| Remove or omit a package from bootstrap | Aaron | Package triage note |
| Change product direction | Aaron | PRD update |

---

## 15. Proposed Phases

### Phase 1: Safety, Instructions, and Planning

**Deliverables:**

- `.github/copilot-instructions.md`
- `docs/prd.md`
- Initial epic docs
- Validation and commit sequencing runbook
- Initial secret and live-home inventory plan

**Exit criteria:**

- [ ] Copilot instructions exist
- [ ] PRD exists
- [ ] Initial epics exist
- [ ] Validation workflow exists
- [ ] First safe commit plan exists

---

### Phase 2: Inventory and Bootstrap Stabilization

**Deliverables:**

- Live-home reconciliation inventory
- YADM status and diff summary
- Secret scan results
- Setup script safety classification
- Read-only local package inventory
- Guided package triage questions for ambiguous packages
- Package list classification

**Exit criteria:**

- [ ] High-impact files reconciled
- [ ] Setup scripts marked current, legacy, or unsafe
- [ ] Local package inventory captured or blocked with reason
- [ ] Package lists classified into core/shell/editor/desktop/development/cloud/media/gaming/optional/unknown/legacy
- [ ] Ambiguous package groups reviewed with Aaron before removal from bootstrap

---

### Phase 3: Shell, Editor, and Tooling Cleanup

**Deliverables:**

- Cleaned shell configuration
- Separated local/secret environment handling
- Editor config review
- Tool script inventory and cleanup

**Exit criteria:**

- [ ] `.zshrc` duplication reduced
- [ ] local-only settings isolated
- [ ] active editor configs documented
- [ ] dead helper scripts archived or removed

---

### Phase 4: Desktop and Fresh-Machine Readiness

**Deliverables:**

- Desktop config status labels
- Fresh-machine bootstrap runbook
- Dry-run capable install/update flow or replacement plan

**Exit criteria:**

- [ ] Current desktop assets identified
- [ ] stale desktop assets archived or documented
- [ ] fresh-machine walkthrough completed or blockers documented

---

## 16. Risk Register

### Risk 1: Secret Exposure During Cleanup

**Likelihood:** Medium
**Impact:** High
**Mitigation:** Use `.yadm/encrypt`, secret scans, and no decrypted content in docs/chat.
**Contingency:** Rotate exposed credentials and purge Git history if needed.

### Risk 2: Live Workstation Behavior Is Accidentally Broken

**Likelihood:** Medium
**Impact:** High
**Mitigation:** Compare against `$HOME`, use small commits, avoid destructive commands.
**Contingency:** Revert commit or restore from live-home backup.

### Risk 3: Old Bootstrap Scripts Are Unsafe Today

**Likelihood:** High
**Impact:** Medium
**Mitigation:** Treat setup scripts as inspect-only until classified.
**Contingency:** Replace with staged bootstrap runbook before rewriting automation.

### Risk 4: Over-Cleanup Deletes Useful Legacy Knowledge

**Likelihood:** Medium
**Impact:** Medium
**Mitigation:** Archive or document uncertain assets before deletion.
**Contingency:** Restore from Git history.

### Risk 5: Product Scope Becomes Too Broad

**Likelihood:** Medium
**Impact:** Medium
**Mitigation:** Release 1 focuses on safety, docs, inventory, and commit planning.
**Contingency:** Defer modernization to later phases.

---

## 17. Dependency Register

| Dependency | Owner | Due Date | Status | Blocked Item | Mitigation if Late |
| --- | --- | --- | --- | --- | --- |
| Live home directory accessible at `$HOME` | Aaron | Release 1 | Open | FR-1 | Use repo-only inventory and mark live comparison blocked |
| YADM status available | Aaron | Release 1 | Open | FR-5 | Request command output from local terminal |
| Secret scan tool available or selected | Aaron | Release 1 | Open | FR-2 | Use manual hotspot review until tool is chosen |
| Decision on whether YADM remains long-term | Aaron | Phase 2 | Open | Bootstrap modernization | Continue with YADM for Release 1 |
| Current workstation target OS/package manager confirmed | Aaron | Phase 2 | Open | Package modernization | Keep old package manifests classified as historical until confirmed |

---

## 18. Open Questions

| # | Question | Owner | Decision Deadline | Blocked Item |
| --- | --- | --- | --- | --- |
| OQ-1 | Which files in `$HOME` differ from tracked repo versions and should be adopted? | Aaron | Phase 2 start | FR-1 |
| OQ-2 | Is Arch still the target fresh-machine OS, or should bootstrap become distro-aware? | Aaron | Phase 2 | Bootstrap modernization |
| OQ-3 | Which desktop environment assets are still active? | Aaron | Phase 3 | Desktop cleanup |
| OQ-4 | Should Spacemacs remain supported, be archived, or be replaced by newer editor config? | Aaron | Phase 3 | Editor cleanup |
| OQ-5 | Which secret scan tool should be standard for this repo? | Aaron | Release 1 | FR-2 |
| OQ-6 | Should YADM remain the long-term dotfile manager? | Aaron | Phase 2 | Future architecture |
| OQ-7 | What is the minimum viable fresh-machine bootstrap? | Aaron | Phase 2 | Fresh-machine runbook |

---

## 19. Appendix: Source Inputs

### Repo Evidence

- `README.md`
- `install.md`
- `TODO.org`
- `.github/copilot-instructions.md`
- `.yadm/encrypt`
- `.zshrc`
- `.bashrc`
- `.profile`
- `.spacemacs`
- `.vimrc`
- `.local/bin/setup/install`
- `.local/bin/tools/`
- `.config/dotfiles/arch-packages/`
- `.config/i3/`
- `.config/polybar/`
- `.config/rofi/`
- `.config/Code/`

### External Concepts

- YADM-managed dotfiles
- YADM encryption via `.yadm/encrypt` and `.yadm/files.gpg`
- Fresh-machine workstation bootstrap
- Secret-safe repository hygiene
