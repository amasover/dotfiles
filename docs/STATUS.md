# Status — session entry point

Read this first. It's the cheap way to learn the current state without re-reading the PRD and every epic.

- **Trunk branch:** `main`
- **Tracking source of truth:** [GitHub Projects board](https://github.com/users/amasover/projects/1/views/1) (status) + issues (discussion). Epic `.md` files hold the spec only.
- **Secret scanning:** `gitleaks` is standard — see [secret scan recipe](../knowledge/recipes/secret-scan.md). Run before every commit/PR.

## How to start a session

1. Read this file + the relevant epic's **Stories** section (not the whole epic).
2. Check the board / `gh issue list` for what's in flight.
3. Open the issue for the story you're picking up; consult `knowledge/` for related recipes.
4. Branch `story/<n>-<slug>`, work, scan, PR against `main`, link the issue.

Avoid re-reading `prd.md` end-to-end unless changing product direction.

## In flight

| Story | Issue | PR | Status |
| --- | --- | --- | --- |
| 3.6 Triage stale test-laptop drift | [#10](https://github.com/amasover/dotfiles/issues/10) | — | In progress |

Recently merged: 1.4 secret scan (#6), Epic 4 workflow adoption (#9). `main` was undiverged from the test-laptop lineage (preserved as `archive/stale-test-laptop-main`).

## Epics

| Epic | Scope | Phase |
| --- | --- | --- |
| [1](./epic-1-safety-inventory-live-home.md) | Safety inventory & live-home reconciliation | 1 |
| [2](./epic-2-bootstrap-and-package-modernization.md) | Bootstrap & package modernization | 2 |
| [3](./epic-3-shell-editor-desktop-cleanup.md) | Shell / editor / desktop cleanup | 3 |
| [4](./epic-4-workflow-and-governance.md) | Workflow & governance (operating model) | 1 |

## Known follow-ups (not yet ticketed)

- Story 4.2: retire `master`, repoint local `origin/HEAD` to `main`.
- Story 4.3: reconcile remaining stale `.yadm/encrypt` / `.yadm/files.gpg` references in `prd.md` and runbooks.
- Story 4.4: pre-commit `gitleaks` hook.
- Story 4.5: install/adopt `shellcheck` + `shfmt`.
- Codify in copilot-instructions §8: always PR to `main`, no stacked PRs.
- From Story 3.6 triage: salvage `update` sudo-keepalive, `.gitignore` patterns, package-manifest additions; decide `.config/yadm/encrypt` removals; encrypt-only salvage of `settings.json` (has a key).
- Prune stale remote branches (`add-ntp`, `locker`, `polybar-*`, `merge-test`, `old-master`, `test-*`).
- Privacy pass: work email / `[work-ref]*` refs in public `.gitconfig`/`.profile`/`.zshrc`.
