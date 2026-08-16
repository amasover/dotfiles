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

### Story 4.7: Minimal CI — lint, tests, secret scan

As the repo owner,
I want every PR checked by CI against the repo's documented validation standards,
So that validation is enforced instead of remembered — the 4.4 move (automate the scan), applied to the rest of the validation expectations, across parallel human/agent sessions.

Issue: [#94](https://github.com/amasover/dotfiles/issues/94) · One GitHub Actions workflow on an `archlinux:latest` container (matches the real tooling; pacman-native). Origin: 2026-07-10 discussion after 2.28 landed 43 tracked test cases with only conventions enforcing that they run.

**Acceptance criteria:**

- Given a PR (and pushes to `main`), when CI runs, then a lint job covers the tracked scripts: `shellcheck`, `shfmt -i 4 -bn -ci -d` (the canonical flags from [runbook-script-validation.md](./runbook-script-validation.md)), `bash -n`, and `luac -p`
- Given the tracked suites (`.config/yay/hook-harness.lua`, `.config/dotfiles/tests/chaotic-quarantine-gate-test`), when CI runs, then both execute and any case failure fails the check
- Given the local pre-commit hook (4.4) can be absent (another machine, GitHub web edits), when CI runs, then gitleaks scans the pushed range as the second net
- Given CI's scope, nothing in it installs to or mutates a live system, and no bootstrap/VM execution happens in CI — `vm-harness` remains the home for behavior validation
- Given the runbook documents validation, when CI lands, then the runbook points to the workflow as the enforced form of the same checks

**Evidence artifact:** the workflow file + a green run on a real PR.

---

### Story 4.8: betterleaks replaces gitleaks as the standard secret scanner ✅

As the repo owner,
I want the secret-scan gate to run betterleaks — gitleaks' successor from the
same maintainers — with gitleaks kept as a transition fallback,
So that the scan standard follows the maintained tool and works on the Windows
machine, without breaking the Linux workstation's existing gitleaks setup.

Issue: [#117](https://github.com/amasover/dotfiles/issues/117) (closed, PR #118) · Origin:
2026-08-09 — gitleaks was absent on the Windows machine during the 2.36/2.37
docs push; Aaron installed betterleaks (winget, 1.7.1) and called the swap.
Compat: betterleaks reads gitleaks configs and `.gitleaksignore`; same
`dir`/`git` scan syntax. Parity gap: no `protect` subcommand, so the staged
scan becomes `git diff --staged | betterleaks stdin`. **Out of scope:**
`security.toml` keeps declaring gitleaks — betterleaks is not in the official
Arch repos (checked 2026-08-09; AUR unverified), so the Linux package swap
waits for confirmed packaging; the hook's fallback keeps that machine green
meanwhile, and Story 2.9's drift loop will surface the swap when it happens.

**Acceptance criteria:**

- Given betterleaks is installed, when a commit is attempted with the hook enabled, then the staged diff is scanned via `betterleaks stdin` (redacted, no banner) and findings block the commit
- Given betterleaks is absent but gitleaks present (the Linux workstation today), when a commit is attempted, then the hook falls back to `gitleaks protect --staged` unchanged; given neither scanner, it fails loudly naming both install routes
- Given the hook now contains selection logic, when the story lands, then clitest cases cover scanner preference, fallback, and the neither-installed failure using stubbed scanners on PATH (no host-state dependency)
- Given docs name a standard scanner, when the story lands, then [knowledge/recipes/secret-scan.md](../knowledge/recipes/secret-scan.md), the copilot-instructions/CLAUDE.md, [validation-and-release-workflow.md](./validation-and-release-workflow.md), and STATUS facts say betterleaks first with gitleaks as the documented fallback (historical docs stay untouched)
- Given the Windows clone had no hook enabled, when the story lands, then `core.hooksPath .githooks` is set there and the story's own commits pass through the new hook

**Evidence artifact:** the reworked hook, a green clitest run of its cases, and this story's commits made with the hook enabled.

---

### Story 4.9: `pre_push` guard — the encrypted archive can't silently go stale ✅

As the repo owner,
I want a yadm `pre_push` hook that refuses the push when a file listed in
`.config/yadm/encrypt` is newer than the encrypted archive,
So that declaring a path encrypted actually gets it into the archive, instead of
the manifest and the archive drifting apart unnoticed for weeks.

Issue: [#122](https://github.com/amasover/dotfiles/issues/122) (closed, PR #123) · Origin: 2026-08-11 —
`.local/state/aur-quarantine/{maintainers.tsv,exempt.txt}` joined the manifest on
2026-07-09 (`9f5e7d3`), but `.local/share/yadm/archive` was last regenerated
2026-06-20 (`03e4f1b`), so the AUR trust baseline has been declared-but-not-archived
ever since: a fresh machine's decrypt restores no trust state at all. Mechanism (read
from `/usr/bin/yadm`): hooks are `~/.config/yadm/hooks/{pre,post}_<command>`, separate
from `.githooks/`; a non-zero `pre_*` exit aborts the command; hooks receive the
expanded manifest list as `YADM_ENCRYPT_INCLUDE_FILES`. **Rejected at design time:**
auto-running `yadm encrypt` from the hook — encryption is symmetric today
(`yadm.gpg-recipient` unset → `gpg -c`) so it needs a TTY for the passphrase, and gpg
output is non-deterministic so every run would commit a fresh ~49k binary blob even
with nothing changed. Non-interactive encryption is available (keypair via
`yadm.gpg-recipient`, or a passphrase-file wrapper via `yadm.gpg-program`) but a
keypair makes fresh-machine recovery depend on transporting a private key — out of
scope. The guard warns; Aaron encrypts deliberately.

**Acceptance criteria:**

- Given a file listed in `.config/yadm/encrypt` is newer than `.local/share/yadm/archive`, when `yadm push` runs, then the hook aborts naming the stale paths and the fix (`yadm encrypt`)
- Given the archive is newer than every listed file, when `yadm push` runs, then the hook exits 0 without output
- Given a listed pattern matches nothing on this machine (another machine's path), when the check runs, then it is skipped rather than failing the push
- Given the check is mtime-based and a fresh clone can produce a false positive, then a documented env override skips it — and the hook never runs `yadm encrypt`, never reads the listed files' contents, and never prints anything from them
- Given hooks are machine-local until installed, when the story lands, then the hook is tracked at `.config/yadm/hooks/pre_push` and its enable step is documented next to the existing `yadm gitconfig core.hooksPath .githooks` step
- Given the test contract ([runbook-script-validation.md](./runbook-script-validation.md)), then the staleness comparison is an invokable seam with clitest coverage over fixture directories — no yadm, no gpg, no real archive
- Given the drift that motivated the story, then the pending attended `yadm encrypt` for the AUR trust baseline is run as part of validation, so the guard's first real push passes for the right reason

**Evidence artifact:** the hook + a green clitest run + a transcript showing the guard blocking a stale push and passing after `yadm encrypt`.

---

### Story 4.10: the vm-harness PowerShell driver has no automated tests

As the repo owner,
I want the host-side seams of `vm-harness-vmware.ps1` under automated tests,
So that the driver — ~600 lines carrying the resume decision, the phase-log
contract, and every ssh guard — stops being the one untested seam in the
harness.

Issue: [#133](https://github.com/amasover/dotfiles/issues/133) · Origin: the PR #128
review. `break` inside `Usage`'s `ForEach-Object` had no loop to leave, so it unwound
the whole script and `vm-harness-vmware frobnicate` exited 0 instead of 2 — the
rc contract the harness's own tooling keys on, broken on `main` and caught only by a
manual exit-code check. The same review found four more driver defects only host-side
tests would catch (a negative resume index running the pipeline in the wrong order,
`Wait-Ssh`'s key-refused downgrade leaving unattended phases at a password prompt,
env overrides interpolated unquoted into a remote shell string, `exec` trusting a
DHCP lease that outlives its VM). Slice 4 of Story 2.36 lists the arg-handling-tests
decision; close this as a duplicate if slice 4 absorbs the work.

Testable without VMware, VMs, or network: subcommand dispatch and exit codes (bad
usage rc 2, `help` rc 0); usage/help rendering off the header comment; guards that
run before any `vmrun` call (`exec` with no VM, `up`'s unreadable-resume-point
refusal, the destroy-first refusal when create cannot proceed);
`ConvertTo-ShellQuoted` round-tripping quotes and injection payloads; `Get-TrustDir`
honouring `VM_HARNESS_TRUST_DIR`.

**Decisions owed:** the runner (Pester, the native fit, vs clitest driven under
`pwsh`, one test vocabulary for the repo), and gating — the tests need `pwsh`,
which the Linux workstation lacks, so where they run (locally, CI, or both)
interacts with Story 4.7 (#94) the same way the `lua5.1`/`setsid` gap already
does.

**Acceptance criteria:**

- Given the listed host-side seams, then each is covered by automated tests needing no VMware, no VM, and no network
- Given the rc contract, then an unknown subcommand exiting 2 is a regression test
- Given the runner and gating decisions, then both are made and recorded (issue + validation runbook), consistent with Story 4.7's CI direction

**Evidence artifact:** a green driver-test run + the recorded runner/gating
decisions.

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
