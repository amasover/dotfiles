# Epic 3: Shell, Editor, and Desktop Cleanup

**Priority:** High
**Status:** Draft
**Phase:** Phase 3 — shell, editor, tooling, and desktop cleanup
**PRD Reference:** [prd.md](./prd.md)
**FR Alignment:** FR-1 (Repo and Live-Home Inventory), FR-4 (Product Documentation), FR-5 (Safe Commit and Sync Workflow)
**Outcome Type:** Maintainability + daily workflow quality

---

## Objective

Make the active shell, editor, tool, and desktop configuration understandable, current, and safe to change while preserving useful legacy context.

## Why This Matters

These files shape the actual daily workstation experience. They also carry the highest risk of accidental breakage because they affect shell startup, PATH, aliases, editor startup, desktop sessions, keybindings, and helper scripts.

Cleanup should improve daily use without erasing old knowledge prematurely.

---

## Current Repo Evidence

- `.zshrc` is the main interactive shell file and contains duplicated aliases/functions.
- `.bashrc`, `.profile`, and `.zprofile` may still influence login or non-zsh contexts.
- `.spacemacs`, `.vimrc`, `.config/nvim/`, and `.config/Code/` define editor behavior.
- `.config/i3/`, `.config/polybar/`, `.config/rofi/`, `.config/dunst/`, `.Xresources`, `.xinitrc`, and `.screenlayout/` define desktop/session behavior.
- `.local/bin/tools/` contains many personal helper scripts of unknown currentness.

---

## Problem Statement

The repo needs to distinguish active workstation behavior from historical configuration. Without that distinction:

- Shell startup may remain slow, duplicated, or machine-specific
- PATH and environment variables may point to stale locations
- Editor configs may install or expect obsolete plugins
- Desktop configs may reflect old monitor/layout assumptions
- Helper scripts may remain undiscoverable or unsafe

---

## Scope

### In Scope

- Compare shell/editor/desktop files against `$HOME`
- Reduce duplication in `.zshrc`
- Separate portable shell config from local/secret config
- Review editor configs and classify active versus legacy
- Review desktop configs and classify active versus legacy
- Inventory helper scripts under `.local/bin/tools/`
- Create documentation for supported daily workflows

### Out of Scope

- Switching shells, editors, or desktop environments without a separate decision
- Deleting uncertain configs without live-home and usage review
- Running desktop session restart commands
- Installing editor plugins or desktop packages automatically
- Publishing private machine details

---

## Stories

### Story 3.1: Clean and structure shell config

As the repo owner,
I want shell config to be readable and intentional,
So that startup behavior and aliases are easy to maintain.

**Acceptance criteria:**

- Given `.zshrc` differs from `$HOME/.zshrc`, when cleanup is proposed, then the live difference is reviewed first
- Given duplicated aliases or functions exist, when cleanup is performed, then duplicate definitions are removed or consolidated
- Given environment variables are secret or machine-local, when shell config is updated, then they are moved to encrypted/local handling rather than plaintext shared config
- Given PATH entries are stale, when updated, then the rationale is documented or the entry is removed

**Evidence artifact:** `.zshrc` diff, shell validation notes

---

### Story 3.2: Classify editor configs

As the repo owner,
I want editor configs marked current or legacy,
So that active editors are supported and old configs do not cause confusion.

**Acceptance criteria:**

- Given `.spacemacs`, `.vimrc`, `.config/nvim/`, and `.config/Code/` exist, when reviewed, then each is classified as current, legacy-supported, archive-candidate, or unknown
- Given an editor config references plugins or tools, when classified, then outdated or missing dependencies are noted
- Given multiple editor configs remain, when docs are updated, then the primary editor path is named

**Evidence artifact:** Editor config inventory

---

### Story 3.3: Classify desktop configs

As the repo owner,
I want desktop environment config classified by currentness,
So that old i3/polybar/rofi assets are preserved or cleaned up intentionally.

**Acceptance criteria:**

- Given desktop config files exist, when reviewed, then each major surface is classified as current, legacy-supported, archive-candidate, or unknown
- Given monitor or machine-specific layout config exists, when retained, then it is documented as machine-specific
- Given screenshots or themes exist, when retained, then they support documentation, active usage, or historical context

**Evidence artifact:** Desktop config inventory

---

### Story 3.4: Inventory helper scripts

As the repo owner,
I want personal helper scripts categorized,
So that useful tools are discoverable and risky scripts are labeled.

**Acceptance criteria:**

- Given scripts exist under `.local/bin/tools/`, when reviewed, then each is categorized by purpose and safety level
- Given a script touches credentials, SSH, cloud accounts, packages, or system services, when documented, then it is marked high-risk
- Given a script is obsolete, when cleanup is proposed, then it is archived or deleted with rationale

**Evidence artifact:** Tool script inventory

---

### Story 3.5: Document daily workflows

As future Aaron,
I want the repo to document supported daily workflows,
So that important aliases and scripts are not just tribal memory.

**Acceptance criteria:**

- Given shell aliases or helper scripts are retained, when docs are updated, then the highest-value workflows are documented
- Given a workflow depends on secrets or local-only files, when documented, then secret values are not exposed
- Given a workflow is legacy, when documented, then it is labeled legacy rather than current

**Evidence artifact:** Workflow docs under `docs/` or README refresh

---

## Acceptance Criteria (Epic Level)

- Shell config has been compared to live-home and cleaned safely
- Editor configs are classified
- Desktop configs are classified
- Helper scripts are inventoried
- Daily workflows are documented without exposing secrets

---

## Dependencies

| Dependency | Owner | Due Date | Status | Blocked Story | Mitigation if Late |
| --- | --- | --- | --- | --- | --- |
| Phase 1 live-home inventory | Aaron | Phase 3 start | Open | All | Do not edit high-impact configs before comparison |
| Primary shell/editor/desktop choices confirmed | Aaron | Phase 3 | Open | 3.1, 3.2, 3.3 | Mark unknown rather than delete |
| Secret handling reviewed | Aaron | Phase 3 | Open | 3.1, 3.4, 3.5 | Avoid touching sensitive scripts/config |

---

## Risks

### Risk: Shell cleanup breaks interactive use

**Likelihood:** Medium
**Impact:** High
**Mitigation:** Use small diffs, syntax checks, and live-home comparison.

### Risk: Legacy desktop config is deleted too early

**Likelihood:** Medium
**Impact:** Medium
**Mitigation:** Classify and archive before deletion unless dead usage is proven.

### Risk: Helper scripts leak sensitive workflow details

**Likelihood:** Medium
**Impact:** High
**Mitigation:** Secret-scan script content and avoid publishing private values.

---

## Done When

This epic is complete when the repo clearly explains which shell, editor, desktop, and tool surfaces are active, which are legacy, and how to change them safely.
