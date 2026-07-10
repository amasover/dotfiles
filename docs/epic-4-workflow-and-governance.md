# Epic 4: Workflow and Governance

**Priority:** High
**Status:** Draft
**Phase:** Phase 1 — safety, instructions, and planning
**PRD Reference:** [prd.md](./prd.md)
**FR Alignment:** FR-2 (Secret Safety), FR-3 (AI Maintenance Instructions), FR-4 (Product Documentation), FR-5 (Safe Commit and Sync Workflow)
**Outcome Type:** Operating model + risk reduction
**GitHub Project:** [Kanban board](https://github.com/users/amasover/projects/1/views/1)

---

## Objective

Establish the repo's operating model — how work is tracked, where the trunk
lives, how secret scanning is enforced, and what tooling validates changes — so
that cleanup work is consistent, reviewable, and hard to drift.

## Why This Matters

Epics 1–3 are about cleaning up *config*. This epic is about cleaning up *how we
work*. Several governance gaps surfaced during Epic 1 that aren't config issues
and don't belong in the cleanup epics:

- Story tracking lived only in `.md` files and drifted from the real branches
  (1.7/1.8/1.9 existed as branches but were never in any epic).
- `main` vs `master` was ambiguous, risking PRs against the wrong base.
- The secret scan from Story 1.4 only runs if a human or agent remembers to.
- Shell scripts have never been linted; `shellcheck`/`shfmt` aren't installed.

The recurring failure mode is **the same fact tracked in two places that
disagree** (e.g. the stale `.yadm/` paths after the 1.6 upgrade). This epic
fixes the operating model so that each fact has exactly one home.

## Operating model: one fact, one home

| Fact | Source of truth |
| --- | --- |
| Story status (todo / in-progress / done), dates, discussion | GitHub issue + [Kanban board](https://github.com/users/amasover/projects/1/views/1) |
| Story spec (objective, acceptance criteria, scope) | Epic `.md` under `docs/` |
| Code / live-home current state | The files themselves |
| Target direction / product intent | `docs/prd.md` |

The epic `.md` and the issue **link** to each other; they do not duplicate each
other. Status does not live in the `.md`; the spec does not live in the issue.

---

## Scope

### In Scope

- Adopt GitHub Projects as the status source of truth, with one issue and one PR per story.
- Reconcile existing in-flight branches (1.7/1.8/1.9) into tracked issues or close them.
- Consolidate on `main` as the trunk and retire `master`.
- Reconcile stale YADM path references across planning docs.
- Enforce secret scanning automatically via a pre-commit hook.
- Install and adopt `shellcheck`/`shfmt` for script validation.
- Update `.github/copilot-instructions.md` to reflect the new workflow.

### Out of Scope

- Config/shell/desktop cleanup (Epics 1–3).
- CI/CD automation beyond a local pre-commit hook (defer to a later phase).
- Migrating away from YADM.

---

## Stories

### Story 4.1: Adopt GitHub Projects as the tracking source of truth ✅

As the repo owner,
I want work tracked on a GitHub Projects board with an issue and PR per story,
So that the board is the single source of truth for status instead of `.md` files drifting.

Issue: [#8](https://github.com/amasover/dotfiles/issues/8) (closed, PR [#9](https://github.com/amasover/dotfiles/pull/9))

**Acceptance criteria:**

- Given a story is about to be started, when work begins, then a GitHub issue is opened, added to the board, and linked from the matching epic `.md` story (one-line `Issue: #N` pointer).
- Given an issue exists for a story, when the story's status changes, then status is updated on the board/issue, not duplicated as status text in the `.md`.
- Given existing in-flight branches (`story/1.7`, `story/1.8`, `story/1.9`) are not tracked, when this story runs, then each is either turned into an issue on the board or closed with a reason.
- Given a story's work is ready, when it is submitted, then it goes through a PR that references its issue.

**Evidence artifact:** Board populated, issues linked from epic `.md` files

---

### Story 4.2: Consolidate on `main` as trunk and retire `master`

As the repo owner,
I want a single, unambiguous trunk branch,
So that PRs and syncs cannot target the wrong base.

Issue: [#33](https://github.com/amasover/dotfiles/issues/33)

**Acceptance criteria:**

- Given GitHub already defaults to `main`, when this story runs, then local `origin/HEAD` is repointed to `main` (`git remote set-head origin main`).
- Given `master` is 0 commits ahead of `main` and stale, when it is retired, then it is archived (e.g. kept as `origin/old-master`) and removed as an active branch with a note.
- Given `.github/copilot-instructions.md` references merging to `main`, when the trunk decision is recorded, then the wording is consistent with `main` being trunk.
- Given the decision is non-obvious later, when it is made, then a short `docs/decision-*.md` or PRD note records why `main` won.

**Evidence artifact:** Decision note, updated branch state

---

### Story 4.3: Reconcile stale YADM path references in planning docs

As the repo owner,
I want planning docs to reference the post-1.6 YADM paths,
So that the docs and copilot-instructions match the real YADM layout.

Issue: [#34](https://github.com/amasover/dotfiles/issues/34)

**Acceptance criteria:**

- Given the 1.6 upgrade moved `.yadm/encrypt` to `.config/yadm/encrypt`, when docs are reconciled, then references are updated across `prd.md`, `epic-1`, and the runbooks.
- Given the upgrade moved `.yadm/files.gpg` to `.local/share/yadm/archive`, when docs are reconciled, then payload references are corrected or clarified as the historical path.
- Given a reference describes historical state intentionally, when it is kept, then it is labelled as the pre-upgrade path rather than silently left wrong.

**Evidence artifact:** Doc reconciliation PR

---

### Story 4.4: Enforce secret scanning with a pre-commit hook ✅

As the repo owner,
I want the Story 1.4 secret scan to run automatically before each commit,
So that secret hygiene does not depend on anyone remembering to run it.

Issue: [#35](https://github.com/amasover/dotfiles/issues/35) (closed, PR #90)

**Acceptance criteria:**

- Given `gitleaks` is the standard scanner, when a commit is attempted, then a pre-commit hook runs `gitleaks protect --staged --redact` and blocks on findings.
- Given the repo maps into `$HOME` through YADM, when the hook is added, then it is repo-local and does not interfere with unrelated home-directory Git work.
- Given a contributor lacks `gitleaks`, when they commit, then the hook fails clearly and points to the install step rather than silently passing.
- Given the hook approach is chosen, when it is documented, then [knowledge/recipes/secret-scan.md](../knowledge/recipes/secret-scan.md) is updated to describe it.

**Evidence artifact:** Working pre-commit hook, updated recipe

---

### Story 4.5: Adopt shellcheck and shfmt for script validation ✅

As the repo owner,
I want shell scripts linted and formatted with standard tools,
So that Epic 2/3 script cleanup has an objective validation signal.

Issue: [#36](https://github.com/amasover/dotfiles/issues/36) (closed, PR #91)

**Acceptance criteria:**

- Given `shellcheck` and `shfmt` are not installed, when this story runs, then Aaron is asked to install them and the validation runbook records them as the standard shell tooling.
- Given the bootstrap and helper scripts are unlinted, when the tools are available, then a baseline `shellcheck` pass is captured for `.local/bin/setup/` and `.local/bin/tools/` without yet rewriting scripts.
- Given a script has findings, when they are recorded, then they feed Epic 2 (script classification) and Epic 3.4 (helper script inventory) rather than being fixed blindly here.

**Evidence artifact:** Baseline shellcheck output, updated validation runbook

---

### Story 4.6: Codify always-PR-to-main rule and add CLAUDE.md ✅

**Issue:** [#12](https://github.com/amasover/dotfiles/issues/12) (closed, PR [#13](https://github.com/amasover/dotfiles/pull/13))

As the repo owner,
I want the PR-to-main rule codified and the instructions auto-loaded,
So that the stacked-PR mistake cannot recur and an agent always reads the rules.

**Acceptance criteria:**

- Given stacked PRs caused work to merge into a dead branch, when §8 is updated, then it requires PRs to always target `main` and forbids stacked PRs
- Given Claude Code auto-loads `CLAUDE.md`, when the repo is set up, then `CLAUDE.md` symlinks to `.github/copilot-instructions.md` (single source)
- Given the pre-PR privacy pass should be enforced, when §8 is reviewed, then the privacy/sensitivity pass remains codified

**Evidence artifact:** copilot-instructions §8 diff, `CLAUDE.md` symlink

---

## Acceptance Criteria (Epic Level)

- The GitHub board is the status source of truth, with issues linked from epic `.md` files.
- Existing in-flight branches are tracked or closed.
- `main` is the unambiguous trunk and `master` is retired.
- Stale YADM path references are reconciled.
- Secret scanning runs automatically pre-commit.
- `shellcheck`/`shfmt` are adopted as standard shell validation tooling.
- `.github/copilot-instructions.md` reflects the new workflow.

## Dependencies

| Dependency | Owner | Status | Blocked Story | Mitigation if Late |
| --- | --- | --- | --- | --- |
| GitHub Issues enabled on the repo | Aaron | Done | 4.1 | — |
| `gh` token has `project` scope (`gh auth refresh -s project`) | Aaron | Open | 4.1 | Open issues without board linkage, add to board later |
| Approval to retire `master` / change remote branches | Aaron | Open | 4.2 | Local `origin/HEAD` fix only until approved |
| `gitleaks` installed | Aaron | Done | 4.4 | — |
| `shellcheck`/`shfmt` installed | Aaron | Open | 4.5 | Defer baseline lint |

## Risks

### Risk: Four trackers (board, issues, PRs, `.md`) disagree

**Likelihood:** Medium
**Impact:** Medium
**Mitigation:** Enforce "one fact, one home" — status on the board, spec in the `.md`, linked but not duplicated.

### Risk: Pre-commit hook blocks unrelated `$HOME` Git work

**Likelihood:** Low
**Impact:** Medium
**Mitigation:** Keep the hook repo-local and scoped to this checkout, not a global Git hook.

## Done When

The repo has a single trunk, a board-backed issue/PR workflow, automatic secret
scanning, standard shell validation tooling, and copilot-instructions that match
how work actually happens.
