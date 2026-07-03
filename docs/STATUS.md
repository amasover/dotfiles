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

**Story 2.8 — metapac adoption** ([#48](https://github.com/amasover/dotfiles/issues/48)): **merged** ([PR #54](https://github.com/amasover/dotfiles/pull/54), 2026-07-03). **2.12 ticketed** ([#53](https://github.com/amasover/dotfiles/issues/53)): non-pacman metapac backends (uv/brew/npm/vscode dispositions; cargo empty; pipx→uv consolidation candidate). 2.9 not yet started — **1.8 jumped the queue** (Aaron's call: the leak ages badly).

**Story 1.8 — privacy scrub** ([#55](https://github.com/amasover/dotfiles/issues/55)): **in flight** on `story/1.8-privacy-scrub`. Phase 1 done on-branch: `.gitconfig` de-worked (default identity → untracked `~/.gitconfig-local`, already created live with the current identity; employer URL-rewrite removed — live had it commented out anyway), `.zshrc` cleaned (work alias out, dead python2-powerline block out matching live, `~/.zshrc.local` source-hook added), three docs neutralized to placeholders, BFG replacements file generated into gitignored `docs/private/` from actual historical case variants. Phase 2 (after phase-1 merges; every step gated): prune stale remote branches → BFG `--replace-text` on a fresh mirror clone (**protect binaries** — fonts/PNG match short tokens as coincidental bytes) → force-push all refs → reset this machine's working repo + yadm repo → **Aaron manually resets the work machine's yadm clone**, which also needs its own `~/.gitconfig-local` (work identity + URL-rewrite) and `~/.zshrc.local` (cgbb alias) **before pulling phase 1**, or its git identity breaks → record GitHub cache residue (old PR diffs may persist; support ticket optional). **`metapac unmanaged` is exactly empty** — 378 explicit = 375 declared in 17 tracked groups (16 purpose groups + empty `inbox-workstation`) + 3 org names in the untracked machine-local group (`~/.local/share/metapac/machine-local.toml`). Tracked config is `config.toml##template` (class `workstation` set live via `yadm config local.class`). Gated mutations executed with approval: D5/D6 drops (docker×2, virtualbox×2 + orphans), `python-cbeams-git` (→ **Story 3.11** [#52](https://github.com/amasover/dotfiles/issues/52), custom cbeams restore), `python2-bin` (C4: live `.zshrc` was already clean), `ipw2100/2200-fw`, and `--asdeps` re-marks (harfbuzz, pango). **D9 amended: `lsdesktopf` KEPT** (Aaron). Legacy flat manifests retired (pointer README). Evidence: [metapac-adoption-notes.md](./metapac-adoption-notes.md). Decision doc corrected: metapac 0.9.4 *does* have a `--hostname` CLI flag (template still wins). ⚠️ 2.11 note: the three org package names got echoed into the working chat once (unfiltered `unmanaged` output) — they remain out of all tracked files/issues; treat chat transcripts as sensitive.

Next per implementation order: **2.9** ([#49](https://github.com/amasover/dotfiles/issues/49)) inbox hook + drift report → **2.3** ([#25](https://github.com/amasover/dotfiles/issues/25), narrowed) thin `bootstrap` + runbook (must pre-create `machine-local.toml` — metapac hard-errors on a missing group file — and add the profile guard) → **2.7** ([#46](https://github.com/amasover/dotfiles/issues/46)) QEMU harness; **2.10** ([#50](https://github.com/amasover/dotfiles/issues/50)) before metal; **2.11** ([#51](https://github.com/amasover/dotfiles/issues/51)) org-package review, anytime.

**2.5 record** (merged [PR #47](https://github.com/amasover/dotfiles/pull/47) + grill amendments direct to main, 2026-07-02) lives in [decision-bootstrap-architecture.md](./decision-bootstrap-architecture.md); vocabulary in root `CONTEXT.md`.

Backlog reminders: **3.9** ([#41](https://github.com/amasover/dotfiles/issues/41)) iwd vs wpa_supplicant; **3.10** ([#42](https://github.com/amasover/dotfiles/issues/42)) screen recorders; **3.1** ([#28](https://github.com/amasover/dotfiles/issues/28)) `.zshrc` cleanup queue. Not yet ticketed from 2.6: clean-chroot AUR builds, popularity-aware holds, paru rebuild (broken: libalpm.so.15) — fresh-install gating is now ticketed as 2.10 (#50). Not yet ticketed from 2.5: the interim `/etc` apply script (known gap in the decision doc).

## Last session (2026-07-01 → 02)

- **Merged Story 2.6** ([#45](https://github.com/amasover/dotfiles/pull/45), closes #40): AUR update quarantine — yay `UpgradeSelect` Lua hook (`.config/yay/init.lua`) holds too-new / orphaned / maintainer-changed AUR upgrades on every `yay -Syu`; `aur-quarantine` CLI (seed/accept/auto + manual version-stepping via pinned AUR-git builds); `setup/update` simplified with `--aur-now` bypass. Threat model + validation record in [aur-malware-mitigation.md](../knowledge/reference/aur-malware-mitigation.md). **Live and active on the workstation** (hook + CLI + update script reverse-tested; 106-package trusted baseline seeded); live-validated end-to-end incl. a pinned build installed via polkit.
- Technique discovered: **pkexec for root actions** from the agent shell (polkit GUI dialog; sudo can't prompt there).
- Started **Story 2.5** (see In flight): tool landscape researched, decision record drafted, Story 2.7 ticketed (#46).

- **2026-07-02 (later):** **2.5 merged** ([PR #47](https://github.com/amasover/dotfiles/pull/47)); then grilled the decision record (`/grill-with-docs`) — five design holes found and amended (see In flight); stories **2.8/2.9/2.10** ticketed (#48–#50) and 2.3 narrowed to bootstrap-script-only; created root `CONTEXT.md` glossary.
- **2026-07-02 (later still):** `.gitconfig` `push.default` → `simple` landed via reverse-test (yadm `b7a7f67`) after a push mis-routed to main; then **grilled Story 2.8** (second `/grill-with-docs`) — six decisions (see In flight), **2.11 ticketed** ([#51](https://github.com/amasover/dotfiles/issues/51)), stale `validation-and-release-workflow.md` §8 fixed (board/issue tracking is current; explicit-refspec push).
- **2026-07-02/03:** **executed Story 2.8** (see In flight) — groups authored from the 2.2 inventory, live adoption reached exactly-empty `unmanaged`, 9 packages removed / 2 re-marked under individual gates, class set, legacy manifests retired, 3.11 ticketed (#52). **Merged same day (PR #54)**; 2.12 ticketed (#53) after a backend inventory (7 backends live, ~6 real non-pacman packages).
- **2026-07-03:** started **Story 1.8** (#55, see In flight) — privacy scrub promoted from the backlog on Aaron's call, ahead of 2.9. Phase 1 (tracked-file cleanup) done on-branch; phase 2 (BFG rewrite) pending phase-1 merge.

**Heads-up for next session:**
- Implementation order: **1.8 phase 2 → 2.9 → 2.3 → 2.7**, with **2.10** before any metal run.
- ⚠️ Before the work machine pulls phase-1 of 1.8: create its `~/.gitconfig-local` (work identity + employer URL-rewrite) and `~/.zshrc.local` (cgbb alias) or its git identity breaks. This machine's `~/.gitconfig-local` already exists.
- ~~metapac `config.toml` hostname privacy~~ **resolved (2026-07-02 grill of 2.8):** the tracked artifact is `config.toml##template` (yadm template; hostname rendered at checkout, group list selected by `yadm.class`) — no hostname reaches the repo. Inboxes are class-named for the same reason.

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
- **Privacy pass → Story 1.8 ([#55](https://github.com/amasover/dotfiles/issues/55)):** tracked-config work refs removed (gitconfig identity/URL-rewrite → untracked `~/.gitconfig-local`; work alias → `~/.zshrc.local`); BFG history scrub is 1.8 phase 2. Literal strings preserved only in the gitignored private note.
- **Story 2.2:** evaluate `aconfmgr` for package/system-state inventory; generate the grouped manifests from live state (incl. optional `work` split).
- **Story 2.3:** install oh-my-zsh via the official installer (replaces the deleted vendored `install_oh_my_zsh`).
- From Story 3.6 triage leftovers: decide `.config/yadm/encrypt` removals; encrypt-only salvage of `settings.json` (has a key).
- Prune stale remote branches (`add-ntp`, `locker`, `polybar-*`, `merge-test`, `old-master`, `test-*`).
- Optionally promote the Story 2.2 private redaction note (`docs/private/`) to YADM-encrypted storage (durable/portable vs machine-local).
