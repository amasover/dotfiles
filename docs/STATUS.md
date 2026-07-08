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
- **2.20 agnoster custom theme** ([#71](https://github.com/amasover/dotfiles/issues/71)):
  [PR #72](https://github.com/amasover/dotfiles/pull/72) open; detail in the PR.
  ⚠️ Before this machine yadm-pulls the merge: `rm ~/.config/dotfiles/oh-my-zsh-custom/themes/agnoster.zsh-theme`
  (untracked, identical content — checkout collision). Leftover to delete: `~/.oh-my-zsh/themes/agnoster.zsh-theme.bak`.
- **1.8 privacy scrub** ([#55](https://github.com/amasover/dotfiles/issues/55)): rewrite executed and
  verified; open only for the work-machine steps — its `~/.gitconfig-local` and `~/.zshrc.local` must
  exist **before** it pulls anything, then hard-reset its clones. Full wrap-up record: comment on #55.
- **2.24 update script: sync batch Spacemacs update** ([#79](https://github.com/amasover/dotfiles/issues/79)):
  branch `story/2.24-update-script-sync-emacs`, PR pending. Root-caused today's lsp-mode startup
  breakage (half-installed package after interrupted update); live elpa repair already done in place.
  Detail: issue + [error note](../knowledge/errors/spacemacs-half-installed-package.md).
- Queue: **2.10** ([#50](https://github.com/amasover/dotfiles/issues/50)) gates any metal bootstrap run;
  everything else lives on the board.

## Standing warnings

- **Chat transcripts are sensitive.** Org package names and the work email have each leaked into a
  session transcript (the repo stayed clean). Filter package listings before echoing them, and never
  inline `~/.local/share/metapac/machine-local.toml` contents into tracked files or issues.

## Last session (2026-07-05)

**Story 2.7 — QEMU harness** ([#46](https://github.com/amasover/dotfiles/issues/46)): **MERGED** ([PR #61](https://github.com/amasover/dotfiles/pull/61), 2026-07-04). Full acceptance passed the same day: fresh VM → unattended archinstall → `bootstrap --unattended` → **`metapac unmanaged` exactly empty in the VM**, graphical.target active, sshd enabled; the 2.9 inbox hook even captured the repo's redis→valkey replacement live in-VM (**pending triage:** host group still declares `redis`; host runs AUR redis — migrate-to-valkey is Aaron's call). **13 findings** fixed along the way, all committed to bootstrap/harness/groups + runbook: hostname-binary absent on minimal installs; multilib disabled; 9 rotted manifest names; AUR clone-burst throttling (retry loop); rustup-before-AUR ordering; 80G disk sizing; corrupt-archive purge after disk-full; interrupted-sync scars (repo providers filling AUR-family deps; requirer-less explicit orphans); makepkg `!debug` (colliding .build-id files across Electron -debug splits) + `!check` (abandoned upstreams fail own tests); `file://`-source PKGBUILDs can't unattended-install (uplink → machine-local, with openconnect-service, colorpicker, gnu-netcat, netmask — build-rot relics with modern equivalents already declared); install-reason normalization post-sync; archinstall explicits declared (`base`/`base-devel`/`mkinitcpio` — NOTE: host lacks the 2019 `base` meta → one drift line until synced). Desktop-session polish observed in the VM UI → **Story 2.17** ([#65](https://github.com/amasover/dotfiles/issues/65), placeholder — Aaron enumerates at pickup). **Recommended before closing #46:** one clean gold-run (`destroy→create→install→bootstrap→check`, uninterrupted, everything committed) as the final evidence. Earlier record: fully unattended `create → install` (cloud-init → archinstall 4.4) → `boot` from disk (OVMF → systemd-boot → sshd) → **key-based ssh with NOPASSWD sudo verified**. Six debugging iterations — release-vs-master archinstall schema skew + partition overlap + missing `esp` flag — recorded in the [runbook's schema-skew section](./runbook-vm-validation.md); serial markers + a root-ssh debug seed are permanent harness features. **Harness is libvirt-native** (Aaron's ask): domain `arch-harness` on `qemu:///system`, visible/attachable in virt-manager (confirmed), default-pool volumes, NAT IP (`vm-harness ip`), media auto-eject; install success asserted via volume allocation (serial log is virtlogd/root-owned). VM accommodations: chsh + zsh at install-time (harness seed); secrets skip is now native — `bootstrap --unattended` skips decrypt by design (the `~/.zshenv` touch hack is gone). **Remaining for full AC:** in-VM `vm-harness bootstrap` + `check` (unblocked — #58 merged; AUR builds make it multi-hour, attended). **Disk prep executed (approved):** +~101G freed — win10 VM deleted (67G; config learnings in the runbook), dead `/var/lib/docker`+`containerd` purged (22G), pacman cache pruned (997 pkgs), yay cache 17G→13G, 5 dead work containers + dangling images; kept: running kind node + recent exited work containers. `update` gained a cache-clean step (paccache + `yay -Sc`). **Pre-merge review pass (2026-07-04, on-branch):** full line-by-line review with Aaron; every finding applied — bootstrap: purpose/usage header + `-h`, unknown args die, unattended-on-metal dies at the gate, `--unattended` skips secret decrypt natively (harness `touch ~/.zshenv` hack deleted), profile-guard comment rewritten + tight `[hostname_groups]` match, machine-local step de-generalized to the one well-known path, **new mirrors step** (reflector when the list is >7 days stale; steady state = Story 2.18 [#66](https://github.com/amasover/dotfiles/issues/66)), makepkg step deleted (**overrides now tracked** at `.config/pacman/makepkg.conf`: `!debug !check`, `-j$(nproc)`, `PKGEXT='.pkg.tar'`), rustup step deleted (**repo `rust` declared instead** — no Rust dev; live swap executed, unmanaged still exactly empty); vm-harness: fetch now verifies the ISO checksum *before* the rename (real bug), guest install driver is a readable `run-install.sh`, `exec` polls to completion (bounded, `VM_HARNESS_EXEC_TIMEOUT`), env-overridable RAM/CPUS/DISK, missing-pubkey warning, rot-proof usage. ⚠️ **Before `yadm pull` of this branch on any machine:** remove the untracked `~/.config/pacman/makepkg.conf` first (checkout collision with the newly tracked file). **Post-merge:** Story 2.19 ticketed ([#70](https://github.com/amasover/dotfiles/issues/70)) from the observability grill — host-side per-phase logs, `--detach`, `vm-harness up`, `tail`/`status`; design decisions D1–D11 in [vm-harness-observability-notes.md](./vm-harness-observability-notes.md), vocabulary in [CONTEXT.md](./CONTEXT.md).

**Story 2.20 — agnoster custom theme** ([#71](https://github.com/amasover/dotfiles/issues/71)): **implemented on `story/2.20-agnoster-custom-theme`, [PR #72](https://github.com/amasover/dotfiles/pull/72) open** (2026-07-05). Aaron's patched agnoster prompt (segment bar printed by a `precmd` hook so long input lines wrap without smearing segment colors) is now tracked at `.config/dotfiles/oh-my-zsh-custom/themes/agnoster.zsh-theme`; bootstrap step 8b symlinks it into `~/.oh-my-zsh/custom/themes/` (shadows the bundled theme by name; gitignored by omz — tracked *outside* `~/.oh-my-zsh` on purpose, or yadm clone would pre-create the dir and the install step would skip). **Live machine already converted:** tracked file + symlink in place, bundled theme restored to upstream (omz checkout clean; verified the custom copy is the one sourced — it defines `agnoster_precmd`, upstream doesn't). ⚠️ **Before this machine's yadm pulls the merged branch:** remove the untracked `~/.config/dotfiles/oh-my-zsh-custom/themes/agnoster.zsh-theme` first (checkout collision, same pattern as the 2.7 makepkg.conf note; contents identical so removal is safe). Leftover for Aaron: untracked `~/.oh-my-zsh/themes/agnoster.zsh-theme.bak` (an earlier fix iteration) — delete candidate. Custom plugin clones remain Story 2.13 (#60). Session note: the shared checkout was sitting on the 2.19 branch when 2.20 branched — caught at push-time by checking `origin/main..HEAD`, fixed with `git rebase --onto main`.

Then: **2.10** ([#50](https://github.com/amasover/dotfiles/issues/50)) before metal; **2.11** ([#51](https://github.com/amasover/dotfiles/issues/51)) org-package review, anytime; **2.12** ([#53](https://github.com/amasover/dotfiles/issues/53)) non-arch backends, anytime.

**2.5 record** (merged [PR #47](https://github.com/amasover/dotfiles/pull/47) + grill amendments direct to main, 2026-07-02) lives in [decision-bootstrap-architecture.md](./decision-bootstrap-architecture.md); vocabulary in root `CONTEXT.md`.

Backlog reminders: **3.9** ([#41](https://github.com/amasover/dotfiles/issues/41)) iwd vs wpa_supplicant; **3.10** ([#42](https://github.com/amasover/dotfiles/issues/42)) screen recorders; **3.1** ([#28](https://github.com/amasover/dotfiles/issues/28)) `.zshrc` cleanup queue; **3.13** ([#67](https://github.com/amasover/dotfiles/issues/67)) atuin shell history (sync half blocked on the homelab atuin server); **3.14** ([#68](https://github.com/amasover/dotfiles/issues/68)) Atuin Desktop runbook app (may transfer to the work tracker). Not yet ticketed from 2.6: clean-chroot AUR builds, popularity-aware holds, paru rebuild (broken: libalpm.so.15) — fresh-install gating is now ticketed as 2.10 (#50). Not yet ticketed from 2.5: the interim `/etc` apply script (known gap in the decision doc).

## Last session (2026-07-01 → 02)

- **Merged Story 2.6** ([#45](https://github.com/amasover/dotfiles/pull/45), closes #40): AUR update quarantine — yay `UpgradeSelect` Lua hook (`.config/yay/init.lua`) holds too-new / orphaned / maintainer-changed AUR upgrades on every `yay -Syu`; `aur-quarantine` CLI (seed/accept/auto + manual version-stepping via pinned AUR-git builds); `setup/update` simplified with `--aur-now` bypass. Threat model + validation record in [aur-malware-mitigation.md](../knowledge/reference/aur-malware-mitigation.md). **Live and active on the workstation** (hook + CLI + update script reverse-tested; 106-package trusted baseline seeded); live-validated end-to-end incl. a pinned build installed via polkit.
- Technique discovered: **pkexec for root actions** from the agent shell (polkit GUI dialog; sudo can't prompt there).
- Started **Story 2.5** (see In flight): tool landscape researched, decision record drafted, Story 2.7 ticketed (#46).

- **2026-07-02 (later):** **2.5 merged** ([PR #47](https://github.com/amasover/dotfiles/pull/47)); then grilled the decision record (`/grill-with-docs`) — five design holes found and amended (see In flight); stories **2.8/2.9/2.10** ticketed (#48–#50) and 2.3 narrowed to bootstrap-script-only; created root `CONTEXT.md` glossary.
- **2026-07-02 (later still):** `.gitconfig` `push.default` → `simple` landed via reverse-test (yadm `b7a7f67`) after a push mis-routed to main; then **grilled Story 2.8** (second `/grill-with-docs`) — six decisions (see In flight), **2.11 ticketed** ([#51](https://github.com/amasover/dotfiles/issues/51)), stale `validation-and-release-workflow.md` §8 fixed (board/issue tracking is current; explicit-refspec push).
- **2026-07-02/03:** **executed Story 2.8** (see In flight) — groups authored from the 2.2 inventory, live adoption reached exactly-empty `unmanaged`, 9 packages removed / 2 re-marked under individual gates, class set, legacy manifests retired, 3.11 ticketed (#52). **Merged same day (PR #54)**; 2.12 ticketed (#53) after a backend inventory (7 backends live, ~6 real non-pacman packages).
- **2026-07-03:** **Story 1.8 executed end-to-end** (#55, see In flight) — phase 1 (tracked-file de-work, PR #56) merged same day; phase 2 rewrote history with BFG and force-pushed, both local clones reset, local residue purged (stale local branches/tags/stash refs in both repos — see the [recipe](../knowledge/recipes/bfg-history-rewrite.md)). ⚠️ Two transcript-only leaks this session (org package names via unfiltered `metapac unmanaged`; work email via `git config user.email` from `$HOME`) — repo clean, transcripts sensitive.

**Heads-up for next session:**
- Implementation order: **1.8 phase 2 → 2.9 → 2.3 → 2.7**, with **2.10** before any metal run.
- ⚠️ Before the work machine pulls phase-1 of 1.8: create its `~/.gitconfig-local` (work identity + employer URL-rewrite) and `~/.zshrc.local` (cgbb alias) or its git identity breaks. This machine's `~/.gitconfig-local` already exists.
- ~~metapac `config.toml` hostname privacy~~ **resolved (2026-07-02 grill of 2.8):** the tracked artifact is `config.toml##template` (yadm template; hostname rendered at checkout, group list selected by `yadm.class`) — no hostname reaches the repo. Inboxes are class-named for the same reason.

- **2.19 built, live-shaken-down, merged** ([PR #74](https://github.com/amasover/dotfiles/pull/74)):
  per-phase state logs, `--quiet`/`--detach`, `up`/`tail`/`status`, `wait_ssh`, full serial visibility
  (direct-kernel-boot with no boot menu, streamed install/boot, NTP gates skipped, spinner-spam and
  getty-vhangup bugs fixed) — five live fix rounds, each diagnosed from the feature's own logs; record
  in the notes doc's implementation deltas. Ride-along hotfix: tracked makepkg.conf carried a fatal
  `!check` in OPTIONS → moved to BUILDENV.
- **2.20** implemented by a parallel session → PR #72 (open).
- Follow-ups ticketed: **2.21** ([#73](https://github.com/amasover/dotfiles/issues/73)) vm-harness
  progress mode, **2.22** ([#75](https://github.com/amasover/dotfiles/issues/75)) AUR download hygiene,
  **2.23** ([#76](https://github.com/amasover/dotfiles/issues/76)) redis→valkey triage,
  **3.15** ([#77](https://github.com/amasover/dotfiles/issues/77)) encrypt-manifest leftovers.
  Scope notes filed on open issues: #28 (.zshrc dedupe, credential-helper unification),
  #30 (termite dropdown, polybar `*.bak`), #50 (2.6 leftovers), #55 (1.8 wrap-up record).
- STATUS rewritten to the format contract above; all archived narrative rehomed (this file's git
  history is the map).

## Epics

| Epic | Scope | Phase |
| --- | --- | --- |
| [1](./epic-1-safety-inventory-live-home.md) | Safety inventory & live-home reconciliation | 1 |
| [2](./epic-2-bootstrap-and-package-modernization.md) | Bootstrap & package modernization | 2 |
| [3](./epic-3-shell-editor-desktop-cleanup.md) | Shell / editor / desktop cleanup | 3 |
| [4](./epic-4-workflow-and-governance.md) | Workflow & governance (operating model) | 1 |
