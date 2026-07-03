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

**Story 2.5 — bootstrap architecture decision** ([#27](https://github.com/amasover/dotfiles/issues/27)): **merged** ([PR #47](https://github.com/amasover/dotfiles/pull/47), 2026-07-02). Post-merge the record was **grilled** (same day) — five sharpenings amended into [decision-bootstrap-architecture.md](./decision-bootstrap-architecture.md): (1) quarantine gates *upgrades only*; install-time gating + baseline portability is now **Story 2.10** ([#50](https://github.com/amasover/dotfiles/issues/50)), a prerequisite for metal bootstrap; (2) per-machine `inbox-<class>.toml` (a shared inbox would auto-install untriaged packages on every machine; class-named because tracked filenames are public); (3) steady state = read-only **drift report** at the end of `setup/update`, `sync`/`clean` stay manual; (4) bootstrap gains a **profile guard** (hard-fail if hostname has no `[hostname_groups]` entry); (5) live adoption rules — `clean` off-limits until `unmanaged` is exactly empty (undecided packages park in the inbox). New `CONTEXT.md` glossary at repo root captures the vocabulary. Verified against sources: yay `PostInstall`/`AURPostDownload` events + metapac config keys all real. **Amendments landed direct to main** (Aaron's call, 2026-07-02: docs-only, each decision reviewed live during the grill; commit `6e7990b` reached main via a mis-resolved push — see `knowledge/errors/git-push-default-upstream-footgun.md` — and was accepted rather than force-reverted).

Implementation now split across: **2.8** ([#48](https://github.com/amasover/dotfiles/issues/48)) metapac adoption on the live workstation (subsumes the 2.2 grouped-manifests follow-up) → **2.9** ([#49](https://github.com/amasover/dotfiles/issues/49)) inbox hook + drift report → **2.3** ([#25](https://github.com/amasover/dotfiles/issues/25), narrowed) thin `bootstrap` + runbook → **2.7** ([#46](https://github.com/amasover/dotfiles/issues/46)) QEMU validation harness; **2.10** before metal; **2.11** ([#51](https://github.com/amasover/dotfiles/issues/51)) org-package review, anytime.

**2.8 was grilled too (2026-07-02, second session):** tracked config = `config.toml##template` (yadm template; `yadm.class` = machine profile selector + inbox name — no hostname in the repo); org-internal D10 packages → machine-local absolute-path group (metapac has no ignore concept) pending 2.11; the 2.2 inventory's ~16-group taxonomy is normative (core-system→`base`, cloud-infra→`work`); working agreement: inert `~/.config/metapac/*` edits blanket-authorized in-story, all mutations individually gated; acceptance sharpened to **exactly empty** `unmanaged`.

Backlog reminders: **3.9** ([#41](https://github.com/amasover/dotfiles/issues/41)) iwd vs wpa_supplicant; **3.10** ([#42](https://github.com/amasover/dotfiles/issues/42)) screen recorders; **3.1** ([#28](https://github.com/amasover/dotfiles/issues/28)) `.zshrc` cleanup queue. Not yet ticketed from 2.6: clean-chroot AUR builds, popularity-aware holds, paru rebuild (broken: libalpm.so.15) — fresh-install gating is now ticketed as 2.10 (#50). Not yet ticketed from 2.5: the interim `/etc` apply script (known gap in the decision doc).

## Last session (2026-07-01 → 02)

- **Merged Story 2.6** ([#45](https://github.com/amasover/dotfiles/pull/45), closes #40): AUR update quarantine — yay `UpgradeSelect` Lua hook (`.config/yay/init.lua`) holds too-new / orphaned / maintainer-changed AUR upgrades on every `yay -Syu`; `aur-quarantine` CLI (seed/accept/auto + manual version-stepping via pinned AUR-git builds); `setup/update` simplified with `--aur-now` bypass. Threat model + validation record in [aur-malware-mitigation.md](../knowledge/reference/aur-malware-mitigation.md). **Live and active on the workstation** (hook + CLI + update script reverse-tested; 106-package trusted baseline seeded); live-validated end-to-end incl. a pinned build installed via polkit.
- Technique discovered: **pkexec for root actions** from the agent shell (polkit GUI dialog; sudo can't prompt there).
- Started **Story 2.5** (see In flight): tool landscape researched, decision record drafted, Story 2.7 ticketed (#46).

- **2026-07-02 (later):** **2.5 merged** ([PR #47](https://github.com/amasover/dotfiles/pull/47)); then grilled the decision record (`/grill-with-docs`) — five design holes found and amended (see In flight); stories **2.8/2.9/2.10** ticketed (#48–#50) and 2.3 narrowed to bootstrap-script-only; created root `CONTEXT.md` glossary.
- **2026-07-02 (later still):** `.gitconfig` `push.default` → `simple` landed via reverse-test (yadm `b7a7f67`) after a push mis-routed to main; then **grilled Story 2.8** (second `/grill-with-docs`) — six decisions (see In flight), **2.11 ticketed** ([#51](https://github.com/amasover/dotfiles/issues/51)), stale `validation-and-release-workflow.md` §8 fixed (board/issue tracking is current; explicit-refspec push).

**Heads-up for next session:**
- Implementation order: **2.8 → 2.9 → 2.3 → 2.7**, with **2.10** before any metal run.
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
- **Privacy pass:** work email / `wts*` refs in public `.gitconfig`/`.profile`/`.zshrc` (incl. `cgbb` alias's `wtsdevops` path); scrub `WTSDevOps` from git **history** (BFG). (`.gitconfig` also still carries the Amadeus/Navitaire work refs.)
- **Story 2.2:** evaluate `aconfmgr` for package/system-state inventory; generate the grouped manifests from live state (incl. optional `work` split).
- **Story 2.3:** install oh-my-zsh via the official installer (replaces the deleted vendored `install_oh_my_zsh`).
- From Story 3.6 triage leftovers: decide `.config/yadm/encrypt` removals; encrypt-only salvage of `settings.json` (has a key).
- Prune stale remote branches (`add-ntp`, `locker`, `polybar-*`, `merge-test`, `old-master`, `test-*`).
- Optionally promote the Story 2.2 private redaction note (`docs/private/`) to YADM-encrypted storage (durable/portable vs machine-local).
