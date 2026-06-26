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

**Story 2.6** (AUR-update quarantine, [#40](https://github.com/amasover/dotfiles/issues/40)) is the **active build** on branch `story/2.6-aur-update-quarantine`: hold AUR upgrades ~14 days (June 2026 AUR malware) with an override flag; anchor is `setup/update`.

**Story 2.2** (package-manifest triage, [#24](https://github.com/amasover/dotfiles/issues/24)) — **PR [#43](https://github.com/amasover/dotfiles/pull/43) open for review**: inventory + triage artifact in [docs/package-inventory.md](./package-inventory.md); decisions resolved with Aaron (yay+paru+brew; optional `work` group; drop docker/virtualbox; keep VPNs/browsers). Org-internal AUR names redacted → gitignored private note. After merge: generate the grouped manifests (plain files vs `metapac` is the **2.5** call), then **2.3** bootstrap rewrite.

**Repo housekeeping** — `chore/retire-master` PR: `master` is dead and now **deleted** (remote branch removed; local `origin/HEAD`→main; master refs in `.gitconfig`/`setup/install`→main). Advances Story 4.2 (#33); `old-master` still pending the stale-branch prune.

New backlog from 2.2 discovery: **Story 3.9** ([#41](https://github.com/amasover/dotfiles/issues/41)) — iwd vs wpa_supplicant NM backend; **Story 3.10** ([#42](https://github.com/amasover/dotfiles/issues/42)) — consolidate screen recorders (kooha). `.zshrc` cleanup queued on **Story 3.1** ([#28](https://github.com/amasover/dotfiles/issues/28)): cat-alias repo promotion, dead `homelab-*`/docker-plugin lines, python2→daemon powerline.

Recently landed on `main`: copilot-instructions now require a **manual privacy pass** (not just gitleaks) and a **STATUS.md update after each chunk of work**.

Recently merged: **3.4 helper-script triage (#38)**, **2.1 classify setup scripts (#18)**, 1.4 secret scan (#6), Epic 4 workflow adoption (#9), 3.6 stale-drift triage (#10). `main` was undiverged from the test-laptop lineage (preserved as `archive/stale-test-laptop-main`).

**Board now fully populated:** every story across epics 1–4 has a GitHub issue (#5–#37) on the [board](https://github.com/users/amasover/projects/1/views/1); each epic `.md` back-links its issue.

## Last session (2026-06-24)

- Merged Story **2.1** (script classification + `docs/bootstrap-inventory.md` + `docs/bootstrap-architecture-notes.md`).
- Walked **every** `setup/` + `tools/` script with Aaron and executed **Story 3.4**: deleted 17 dead scripts + `.fehbg`, kept 12, with cascading edits to `.zshrc` / i3 / polybar / `.profile` (details in bootstrap-inventory.md § Story 3.4).
- Removed the live dot-ansible hook (`.profile` no longer sources its `shell-imports.sh`; lastpass no longer used).
- Created all backlog issues (#19–#37) incl. new **Story 3.8 fish-shell (#37)**.

**Heads-up for next session:**
- **Live `$HOME` sync:** after 3.4 merges, run `yadm pull` to drop the deleted files + apply config edits live. If it complains about local `.zshrc`, `yadm checkout -- .zshrc` then pull (the live update-alias edit already matches `main`).
- **Architecture decision pending (2.3/2.5):** bash-now → aconfmgr **or** fresh Ansible repo; home-manager/Nix left on the table. See bootstrap-architecture-notes.md.

## Epics

| Epic | Scope | Phase |
| --- | --- | --- |
| [1](./epic-1-safety-inventory-live-home.md) | Safety inventory & live-home reconciliation | 1 |
| [2](./epic-2-bootstrap-and-package-modernization.md) | Bootstrap & package modernization | 2 |
| [3](./epic-3-shell-editor-desktop-cleanup.md) | Shell / editor / desktop cleanup | 3 |
| [4](./epic-4-workflow-and-governance.md) | Workflow & governance (operating model) | 1 |

## Known follow-ups (not yet ticketed)

_Backlog stories 4.2–4.5 are now ticketed (#33–#36); the items below are smaller, mostly folding into existing Epic 3 / Epic 2 stories._

- **From Story 3.4 (Epic 3 cleanup):** fix `polybar_alsa_module` switch (`pacmd`→`wpctl`); retire `volume-go` (`~/code/go/bin/volume`)→`wpctl`/`pamixer`; rename `pulseaudio-tail.sh` (it's PipeWire); dead desktop config — termite dropdown (i3 `config:166`), stale polybar `*.bak`/non-active themes; `.zshrc` dedupe (duplicate `dot-src` etc.).
- **Privacy pass:** work email / `wts*` refs in public `.gitconfig`/`.profile`/`.zshrc` (incl. `cgbb` alias's `wtsdevops` path); scrub `WTSDevOps` from git **history** (BFG).
- **Story 2.2:** evaluate `aconfmgr` for package/system-state inventory.
- **Story 2.3:** install oh-my-zsh via the official installer (replaces the deleted vendored `install_oh_my_zsh`).
- From Story 3.6 triage leftovers: decide `.config/yadm/encrypt` removals; encrypt-only salvage of `settings.json` (has a key).
- Prune stale remote branches (`add-ntp`, `locker`, `polybar-*`, `merge-test`, `old-master`, `test-*`).
