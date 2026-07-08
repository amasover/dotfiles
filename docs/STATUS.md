# Status — session entry point

Read this first: it's the cheap way to orient without re-reading the PRD and every epic.

**Format contract — keep this file cheap.** This is a disposable handoff note between
agent-assisted sessions, not an archive:

- **In flight** holds one entry per story actually moving: status, where the detail
  lives (issue / PR / epic spec / notes doc / runbook), and what's next or blocking.
  1–3 lines each.
- Nothing may live *only* here. If a detail has no other home, move it to the story's
  issue, an epic spec, or a notes doc — or open an issue — and keep at most a pointer.
- Merged/closed work leaves this file at the next update; the epic ✅ and git history
  are the record. Keep a single **Last session** digest and delete older ones.
- If this file outgrows roughly one screen, it's wrong: trim it, don't append.

Facts:

- **Trunk branch:** `main` (`master` is retired and deleted; never diff/PR against it).
- **Tracking source of truth:** [GitHub Projects board](https://github.com/users/amasover/projects/1/views/1)
  (status) + issues (discussion). Epic `.md` files hold specs only; ✅ on a story heading = issue closed.
- **Secret scanning:** `gitleaks` before every commit/PR ([recipe](../knowledge/recipes/secret-scan.md)),
  always paired with a manual privacy pass by eye — gitleaks misses employer/personal/host details.

## How to start a session

1. Read this file, then the relevant epic's **Stories** section (not the whole epic).
2. Pick up work via its GitHub issue; check `knowledge/` for related recipes.
3. Branch `story/<n>-<slug>` off `main`; one story per branch and PR; PRs against `main` only (never stacked).
4. When a chunk lands, update this file *per the format contract above*.

## In flight

- **2.19 vm-harness observability** ([#70](https://github.com/amasover/dotfiles/issues/70)):
  [PR #74](https://github.com/amasover/dotfiles/pull/74) **merged 2026-07-05**; issue stays open
  until the evidence lands — one green detached `up` with its full log set (the final fix stack
  hasn't completed a run yet). Detail: epic spec, [observability notes](./vm-harness-observability-notes.md)
  (grill D1–D11 + implementation deltas), [VM runbook](./runbook-vm-validation.md).
- **2.15 package-removal hook** ([#63](https://github.com/amasover/dotfiles/issues/63)):
  [PR #81](https://github.com/amasover/dotfiles/pull/81) open, live-validated (evidence on #63) —
  alpm hook (yay Lua has no removal event), /etc symlink installed, gnu-netcat removal exercised it.
  ⚠️ Live yadm is on the story branch for validation: after merge, `yadm checkout main && yadm pull`.
- **1.8 privacy scrub** ([#55](https://github.com/amasover/dotfiles/issues/55)): rewrite executed and
  verified; open only for the work-machine steps — its `~/.gitconfig-local` and `~/.zshrc.local` must
  exist **before** it pulls anything, then hard-reset its clones. Full wrap-up record: comment on #55.
- Queue: **2.10** ([#50](https://github.com/amasover/dotfiles/issues/50)) gates any metal bootstrap run;
  everything else lives on the board.

## Standing warnings

- **Chat transcripts are sensitive.** Org package names and the work email have each leaked into a
  session transcript (the repo stayed clean). Filter package listings before echoing them, and never
  inline `~/.local/share/metapac/machine-local.toml` contents into tracked files or issues.

## Last session (2026-07-06 → 07)

- **2.24 merged** ([PR #80](https://github.com/amasover/dotfiles/pull/80), closes #79): `setup/update`
  now runs the Spacemacs package update synchronously in batch mode. Root cause of the lsp-mode
  breakage recorded in [the error note](../knowledge/errors/spacemacs-half-installed-package.md);
  live elpa repair was already done in place.
- **2.20 merged** ([PR #72](https://github.com/amasover/dotfiles/pull/72), closes #71): patched agnoster
  theme tracked + bootstrap symlink step. This machine already pulled the merge via yadm — collision
  file handled, tracked theme + `~/.oh-my-zsh/custom/themes` symlink verified live.
- The #72 merge-conflict resolution had re-added STATUS narrative that PR #78 already rehomed;
  re-trimmed to the format contract (nothing lost — git history has it).

## Epics

| Epic | Scope | Phase |
| --- | --- | --- |
| [1](./epic-1-safety-inventory-live-home.md) | Safety inventory & live-home reconciliation | 1 |
| [2](./epic-2-bootstrap-and-package-modernization.md) | Bootstrap & package modernization | 2 |
| [3](./epic-3-shell-editor-desktop-cleanup.md) | Shell / editor / desktop cleanup | 3 |
| [4](./epic-4-workflow-and-governance.md) | Workflow & governance (operating model) | 1 |
