# Status — session entry point

Read this first. It's the cheap way to learn the current state without re-reading the PRD and every epic.

- **Trunk branch:** `main` (`master` is retired and deleted; never diff/PR against it).
- **Tracking source of truth:** [GitHub Projects board](https://github.com/users/amasover/projects/1/views/1) (status) + issues (discussion). Epic `.md` files hold the spec only.
- **Secret scanning:** `gitleaks` is standard — see [secret scan recipe](../knowledge/recipes/secret-scan.md). Run before every commit/PR, and **always pair it with a manual privacy pass by eye** (gitleaks misses employer/personal/host details).

## How to start a session

1. Read this file + the relevant epic's **Stories** section (not the whole epic).
2. Check the board / `gh issue list` for what's in flight.
3. Open the issue for the story you're picking up; consult `knowledge/` for related recipes.
4. Branch `story/<n>-<slug>`, work, scan, PR against `main`, link the issue.
5. When you finish a chunk of work, **update this file** (In flight / Last session).

Avoid re-reading `prd.md` end-to-end unless changing product direction.

## In flight

**Story 2.6 — AUR-update quarantine** ([#40](https://github.com/amasover/dotfiles/issues/40)), branch `story/2.6-aur-update-quarantine`. **Built + harness-validated; pending a supervised live test, then PR.**

Architecture decided (**hybrid**, after researching yay's Lua hooks): enforcement lives in a **yay `UpgradeSelect` Lua hook** (`.config/yay/init.lua`, yay v13.0.1 supports it; payload already carries `maintainer`+`last_modified`, so no RPC and it protects *every* `yay -Syu`), plus a slim **`aur-quarantine` CLI** for what hooks can't do (they can only *exclude*, not substitute versions): `seed`/`accept` trusted-maintainer baseline, `auto` exemptions, and **manual version-stepping** (`update <pkg>` builds the newest *aged* version at a pinned AUR git commit). `setup/update` simplified: hook gates in-flow, prints the hook-written manual-follow-ups report (AUR links + copy-paste commands) at the end; `--aur-now` bypasses (incl. `--devel`). Full rationale + threat model: [aur-malware-mitigation.md](../knowledge/reference/aur-malware-mitigation.md).

Validated: `luac -p`/`bash -n`/`zsh -n`; Lua harness with stubbed yay API (all hold/allow paths + bypass pass); CLI round-trips in isolated state. **Remaining:** supervised live `yay -Su` to confirm real payload field names + one `aur-quarantine update` build test; then PR. Side-finding: **paru is broken live** (libalpm.so.15 soname bump — rebuild sometime).

New backlog from 2.2 discovery: **Story 3.9** ([#41](https://github.com/amasover/dotfiles/issues/41)) — iwd vs wpa_supplicant NM backend; **Story 3.10** ([#42](https://github.com/amasover/dotfiles/issues/42)) — consolidate screen recorders (kooha). `.zshrc` cleanup queued on **Story 3.1** ([#28](https://github.com/amasover/dotfiles/issues/28)): cat-alias repo promotion, dead `homelab-*`/docker-plugin lines, python2→daemon powerline.

## Last session (2026-06-26)

- Merged **Story 2.2** ([#43](https://github.com/amasover/dotfiles/pull/43)): package inventory + triage artifact (`docs/package-inventory.md`) + `pacman`-provides knowledge note. Org-internal AUR package names **redacted** from the public doc; real names kept in a **gitignored** private note (`docs/private/`, mapped in `.gitignore`). Manual privacy pass caught them; `gitleaks` did not.
- Merged **chore/retire-master** ([#44](https://github.com/amasover/dotfiles/pull/44)): deleted the dead `master` branch (was 0 commits ahead of `main`), pointed the remaining Aaron-owned `master` refs → `main` (`.gitconfig`, `setup/install`), fixed local `origin/HEAD`. Codified two governance rules in copilot-instructions: **manual privacy pass** (not just gitleaks) and **update STATUS.md after each chunk of work**.
- Started **Story 2.6** design (see In flight), then paused on the yay-hooks architecture question.

**Heads-up for next session:**
- **Decide the 2.6 architecture (yay Lua hooks vs bash) before writing more.** Start with the 3 links + `yay --version`.
- **Live `$HOME` sync:** #44 changed yadm-tracked `.gitconfig` (`delete-merged` default) and `setup/install` (`origin/master`→`main`). Live `$HOME` still has the old `master` defaults — `yadm pull` to converge when convenient.
- **Architecture decision still pending (2.3/2.5):** bash-now → aconfmgr **or** fresh Ansible repo; manifest format plain-files vs `metapac`. See bootstrap-architecture-notes.md.

## Epics

| Epic | Scope | Phase |
| --- | --- | --- |
| [1](./epic-1-safety-inventory-live-home.md) | Safety inventory & live-home reconciliation | 1 |
| [2](./epic-2-bootstrap-and-package-modernization.md) | Bootstrap & package modernization | 2 |
| [3](./epic-3-shell-editor-desktop-cleanup.md) | Shell / editor / desktop cleanup | 3 |
| [4](./epic-4-workflow-and-governance.md) | Workflow & governance (operating model) | 1 |

## Known follow-ups (not yet ticketed)

_Backlog stories 4.2–4.5 are ticketed (#33–#36); the items below are smaller, mostly folding into existing Epic 3 / Epic 2 stories._

- **From Story 3.4 (Epic 3 cleanup):** fix `polybar_alsa_module` switch (`pacmd`→`wpctl`); retire `volume-go` (`~/code/go/bin/volume`)→`wpctl`/`pamixer`; rename `pulseaudio-tail.sh` (it's PipeWire); dead desktop config — termite dropdown (i3 `config:166`), stale polybar `*.bak`/non-active themes; `.zshrc` dedupe (duplicate `dot-src` etc.).
- **Privacy pass:** work email / `wts*` refs in public `.gitconfig`/`.profile`/`.zshrc` (incl. `cgbb` alias's `wtsdevops` path); scrub `WTSDevOps` from git **history** (BFG). (`.gitconfig` also still carries the Amadeus/Navitaire work refs.)
- **Story 2.2:** evaluate `aconfmgr` for package/system-state inventory; generate the grouped manifests from live state (incl. optional `work` split).
- **Story 2.3:** install oh-my-zsh via the official installer (replaces the deleted vendored `install_oh_my_zsh`).
- From Story 3.6 triage leftovers: decide `.config/yadm/encrypt` removals; encrypt-only salvage of `settings.json` (has a key).
- Prune stale remote branches (`add-ntp`, `locker`, `polybar-*`, `merge-test`, `old-master`, `test-*`).
- Optionally promote the Story 2.2 private redaction note (`docs/private/`) to YADM-encrypted storage (durable/portable vs machine-local).
