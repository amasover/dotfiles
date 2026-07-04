# Epic 1: Safety Inventory and Live-Home Reconciliation

**Priority:** Critical
**Status:** Done (2026-06-23) — all stories 1.1–1.6 have landed evidence artifacts
**Phase:** Phase 1 — safety, instructions, and planning
**PRD Reference:** [prd.md](./prd.md)
**FR Alignment:** FR-1 (Repo and Live-Home Inventory), FR-2 (Secret Safety and YADM Encryption), FR-5 (Safe Commit and Sync Workflow)
**Outcome Type:** Risk reduction + source-of-truth recovery

---

## Objective

Create a safe, evidence-based inventory of the dotfiles repo and reconcile it against the live home directory at `$HOME` before making broad cleanup commits.

## Context

The repo sat idle for years while the live workstation kept changing, so the first risk is making confident-looking changes against stale assumptions. Before cleanup, the repo needs a verified map of what is tracked, what differs from `$HOME`, what is untracked, what is sensitive, and what is current vs legacy/archived/unknown. Background: [prd.md](./prd.md) §2–3.

---

## Scope

### In Scope

- Capture read-only YADM status and diff summaries
- Identify tracked files with matching live-home paths
- Compare high-impact files against `$HOME`
- Identify likely secret hotspots
- Review `.yadm/encrypt` coverage
- Upgrade YADM v3 legacy data paths after explicit approval
- Create a safe commit sequencing recommendation
- Classify files as current, legacy-supported, archive-candidate, delete-candidate, or unknown

### Out of Scope

- Rewriting shell or install scripts
- Running setup/install/update commands
- Decrypting or printing secret material
- Committing `.yadm/files.gpg` changes without explicit encrypted-file intent
- Migrating away from YADM

---

## Stories

### Story 1.1: Capture YADM current state ✅

As the repo owner,
I want a read-only summary of YADM status and diffs,
So that I can understand unsynced work before staging anything.

Issue: [#19](https://github.com/amasover/dotfiles/issues/19) (closed)

**Acceptance criteria:**

- Given the repo is managed by YADM, when `yadm status` is reviewed, then modified, deleted, untracked, and staged files are summarized
- Given local changes exist, when `yadm diff --stat` is reviewed, then high-impact areas are identified before detailed diffs are opened
- Given a changed file may contain secrets, when diff review is needed, then the file is handled through a secret-safe review path

**Evidence artifact:** Inventory note or PR/commit checklist summary

---

### Story 1.2: Build the live-home reconciliation list ✅

As the repo owner,
I want tracked files mapped to `$HOME`,
So that cleanup decisions reflect the actual workstation.

Issue: [#20](https://github.com/amasover/dotfiles/issues/20) (closed)

**Acceptance criteria:**

- Given a tracked file maps to `$HOME/<path>`, when the file exists live, then repo and live versions are compared or marked for comparison
- Given a tracked file has no live equivalent, when reviewed, then it is classified as archive-candidate, bootstrap-only, or unknown
- Given a live file differs from the repo version, when a decision is made, then the chosen source of truth is documented

**Evidence artifact:** Reconciliation inventory

---

### Story 1.3: Review YADM encryption coverage ✅

As the repo owner,
I want sensitive paths covered by YADM encryption,
So that local secrets can be backed up without plaintext exposure.

Issue: [#21](https://github.com/amasover/dotfiles/issues/21) (closed)

**Acceptance criteria:**

- Given `.yadm/encrypt` exists, when it is reviewed, then all listed patterns are documented as sensitive surfaces
- Given a file contains cloud credentials, SSH material, API tokens, package publishing credentials, or private machine data, when it is considered for tracking, then it is covered by `.yadm/encrypt` or excluded
- Given `.yadm/files.gpg` changes, when the change is considered for commit, then it is linked to an intentional encrypted-file update

**Evidence artifact:** Encryption coverage notes and secret-safety checklist

---

### Story 1.4: Run or select a secret scan process ✅

As the repo owner,
I want a repeatable secret scan before commits,
So that historical cleanup does not accidentally publish sensitive material.

**Acceptance criteria:**

- Given a secret scanning tool is available, when it runs, then findings are reviewed before commits are staged
- Given no scanner is installed, when Release 1 finishes, then a recommended scanner and manual fallback process are documented
- Given a finding is likely a false positive, when it is dismissed, then the reason is documented

**Issue:** [#5](https://github.com/amasover/dotfiles/issues/5) (closed, PR [#6](https://github.com/amasover/dotfiles/pull/6)) — status on the [board](https://github.com/users/amasover/projects/1/views/1)

**Evidence artifact:** [Secret scan recipe](../knowledge/recipes/secret-scan.md) (includes scan evidence and manual fallback)

---

### Story 1.5: Create the first safe commit sequence ✅

As the repo owner,
I want cleanup commits ordered by risk,
So that syncing changes is reviewable and reversible.

Issue: [#22](https://github.com/amasover/dotfiles/issues/22) (closed)

**Acceptance criteria:**

- Given docs-only safety changes exist, when commits are planned, then they are separated from shell/script/secret changes
- Given encrypted files are involved, when commits are planned, then encrypted payload changes are isolated and explained
- Given large cleanup work remains, when the first commit sequence is created, then later modernization work is deferred into separate epics

**Evidence artifact:** Commit plan or PR description

---

### Story 1.6: Upgrade YADM legacy paths and establish local tracking ✅

As the repo owner,
I want YADM's legacy data paths upgraded and cleanup work committed locally in small steps,
So that future reconciliation can use normal YADM commands and the repo has recoverable checkpoints before any remote workflow is formalized.

Issue: [#23](https://github.com/amasover/dotfiles/issues/23) (closed)

**Acceptance criteria:**

- Given YADM 3.5.0 reports legacy path detection, when the upgrade is approved, then `yadm upgrade` is run only after current status, diff-stat, branch, remote, and encrypted archive locations are recorded
- Given the upgrade changes YADM data paths, when it completes, then normal `yadm status` and `yadm diff --stat` are verified against the pre-upgrade read-only baseline
- Given `.yadm/files.gpg` or encrypted metadata changes, when commits are planned, then those changes are isolated from docs and normal config cleanup
- Given docs-only safety artifacts exist, when local Git commits are made, then they exclude unrelated live-home drift such as the current polybar change
- Given the local branch is merged into `main`, when the merge is performed, then the merge scope is checked first and no YADM push or GitHub PR workflow is assumed
- Given high-impact changed files remain after the upgrade, when reconciliation resumes, then shell startup files and polybar are reviewed before editor, desktop, helper-script, and package surfaces

**Evidence artifact:** [YADM legacy upgrade and local Git runbook](./yadm-legacy-upgrade-and-local-git-runbook.md), commit log, and post-upgrade status summary

---

### Story 1.7: Audit live home for untracked configs worth adopting

As the repo owner,
I want a sweep of config files that exist on the live machine but are not tracked by YADM,
So that useful real-workstation configuration is deliberately adopted instead of silently lost on a rebuild.

This is the inverse of Story 1.2 (which maps tracked files → live). Here the direction is
live → tracked: find untracked config under `$HOME` and decide adopt / encrypt / ignore.

Issue: [#17](https://github.com/amasover/dotfiles/issues/17)

**Acceptance criteria:**

- Given config files exist under `$HOME` (e.g. `.config/`, dotfiles, `.local/`) that YADM does not track, when the sweep runs, then untracked candidates are listed with their purpose
- Given an untracked file is found, when reviewed, then it is classified as adopt-to-yadm, encrypt-then-adopt, machine-local-only, or ignore
- Given a candidate contains secrets or machine-specific/private data, when adoption is considered, then it routes through `.yadm/encrypt` or is excluded — never committed as plaintext
- Given a file is selected for adoption, when the decision is recorded, then the rationale and target (tracked vs encrypted) is documented; actual `yadm add` happens only with explicit approval

**Evidence artifact:** Untracked-config adoption inventory under `docs/`

---

### Story 1.8: Privacy scrub — de-work the tracked configs and rewrite history

As the repo owner,
I want work identifiers removed from tracked files and from git history,
So that the public repo stops naming my employer, work email domain, and internal paths.

Issue: [#55](https://github.com/amasover/dotfiles/issues/55) · Promotes the long-standing "privacy pass / BFG scrub" backlog item
(STATUS known follow-ups). Literal target strings live only in the gitignored private
note (`docs/private/`); tracked files and this spec use neutral placeholders.

**Acceptance criteria:**

- Given the tracked `.gitconfig`, when restructured, then the default work identity and the employer URL-rewrite move to an untracked `~/.gitconfig-local` (joining the existing untracked `-personal`/`-production` includes; scoped includeIfs keep winning for their repos), and a machine without the local file fails loudly on commit rather than mis-attributing
- Given `.zshrc`, when cleaned, then the work-path alias moves to an untracked local rc (a `~/.zshrc.local` source-if-exists hook is added) and the dead python2-powerline block is dropped (adopts the live-home state)
- Given docs mention literal work strings, when neutralized, then placeholders replace them and the literals are preserved only in the gitignored private note
- Given current files are clean and merged, when history is rewritten, then BFG `--replace-text` (replacements file generated from the private note) rewrites all refs on a fresh `--mirror` clone and force-pushes only with explicit approval; stale remote branches are pruned first; binary assets (fonts, screenshots) are protected from byte-level replacement
- Given the rewrite lands, when clones reconcile, then this machine's working repo and yadm repo are reset with approval, and a documented reset procedure covers other machines (work machine included)
- Given GitHub retains caches, when the scrub completes, then residual exposure (cached views, old PR diffs, possible forks) is documented — accepted or escalated to GitHub support

**Evidence artifact:** Clean sweep (gitleaks + per-family grep over HEAD and full history) + a history-rewrite runbook under `knowledge/recipes/`.

---

## Acceptance Criteria (Epic Level)

- `yadm status` and `yadm diff --stat` have been reviewed or requested from the local terminal
- High-impact repo files have a live-home comparison plan
- Sensitive path handling is documented
- `.yadm/encrypt` coverage is reviewed
- YADM legacy-path upgrade has either been completed with post-upgrade verification or remains explicitly deferred
- A secret scan process is selected or a manual fallback is documented
- Initial cleanup commits are sequenced safely

---

## Dependencies

Per-story blockers live on the linked GitHub issues. Cross-cutting dependencies: see [prd.md](./prd.md) §17.

---

## Risks

### Risk: Secret material appears in diffs

**Likelihood:** Medium
**Impact:** High
**Mitigation:** Use diff-stat first, avoid printing sensitive diffs, check `.yadm/encrypt`, and run a secret scan.

### Risk: Live-home changes are accidentally overwritten

**Likelihood:** Medium
**Impact:** High
**Mitigation:** Compare repo files to `$HOME` before changing high-impact config.

### Risk: Inventory becomes too broad

**Likelihood:** Medium
**Impact:** Medium
**Mitigation:** Start with high-impact files: shell, profile, setup scripts, package lists, editor config, desktop session config, YADM metadata.

### Risk: YADM upgrade obscures the reconciliation baseline

**Likelihood:** Medium
**Impact:** High
**Mitigation:** Record pre-upgrade status and diff-stat, avoid encrypted operations during the upgrade, verify normal YADM commands afterward, and keep the first docs commit separate from YADM metadata changes.

---

## Done When

This epic is complete when there is enough evidence to make the first cleanup commit without guessing about repo state, live-home drift, or secret exposure.
