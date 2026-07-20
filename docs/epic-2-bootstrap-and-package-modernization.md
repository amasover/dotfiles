# Epic 2: Bootstrap and Package Modernization

**Priority:** High
**Status:** Draft
**Phase:** Phase 2 — inventory and bootstrap stabilization
**PRD Reference:** [prd.md](./prd.md)
**FR Alignment:** FR-1 (Repo and Live-Home Inventory), FR-4 (Product Documentation), FR-5 (Safe Commit and Sync Workflow)
**Outcome Type:** Recoverability + maintainability

---

## Objective

Turn the old install/update flow into a safe, staged, and documented bootstrap model for rebuilding a useful workstation without blindly executing stale scripts.

## Context

The bootstrap material (`install.md`, `.local/bin/setup/install` + `update`, `.config/dotfiles/arch-packages/{pacman,aur}`) encodes years of useful setup knowledge but carries old Arch/AUR assumptions and may mutate the system unsafely. The repo can't be trusted as a fresh-machine bootstrap until scripts are classified (current/legacy/unsafe/unknown), package lists are triaged against the live machine with Aaron, destructive ops are gated, and a dry-run path exists. Package cleanup is collaborative: inventory first, then ask targeted questions before changing install inputs. Background: [prd.md](./prd.md) §2–3, FR-6.

---

## Scope

### In Scope

- Review bootstrap scripts without executing them
- Classify package lists into core, shell, editor, desktop, development, cloud, media, gaming, optional, unknown, and legacy groups
- Inventory explicitly installed native packages and foreign/AUR packages from the local machine
- Ask Aaron targeted questions about ambiguous packages or package groups
- Identify stale tools such as old AUR helpers or deprecated distro packages
- Create a dry-run/checklist bootstrap runbook
- Define the minimum viable fresh-machine setup
- Identify which scripts should be rewritten, retained, archived, or deleted

### Out of Scope

- Running full bootstrap on the live machine
- Installing or removing packages automatically
- Rewriting the entire setup system in one pass
- Migrating to a new dotfile manager
- Building cross-platform support beyond the chosen Linux target

---

## Stories

### Story 2.1: Classify setup scripts ✅

As the repo owner,
I want every setup script classified by safety and currentness,
So that I know what can be inspected, tested, rewritten, or archived.

Issue: [#16](https://github.com/amasover/dotfiles/issues/16) (closed, PR [#18](https://github.com/amasover/dotfiles/pull/18)) · Artifact: [bootstrap-inventory.md](./bootstrap-inventory.md)

**Acceptance criteria:**

- Given a script exists under `.local/bin/setup/`, when reviewed, then it is classified as current, legacy, unsafe, or unknown
- Given a script performs system mutations, when classified, then those mutations are listed at a high level
- Given a script should not be executed, when docs are updated, then the warning is explicit

**Evidence artifact:** Bootstrap inventory or runbook section

---

### Story 2.2: Inventory local packages and split manifests by purpose ✅

As the repo owner,
I want package lists grouped by intent and checked against the actual installed package set,
So that a fresh-machine setup can install only what is needed.

Issue: [#24](https://github.com/amasover/dotfiles/issues/24) (closed, PR [#43](https://github.com/amasover/dotfiles/pull/43)) · Artifact: [package-inventory.md](./package-inventory.md)

**Acceptance criteria:**

- Given historical package lists exist, when reviewed, then packages are grouped into core, shell, editor, desktop, development, cloud, media, gaming, optional, unknown, and legacy categories
- Given the local package manager can report explicitly installed packages, when inventory runs, then native repo packages and foreign/AUR packages are captured separately
- Given a package is installed locally but missing from repo manifests, when reviewed, then it is classified as add-to-bootstrap, machine-local, optional, unknown, or remove-candidate
- Given a package is in repo manifests but not installed locally, when reviewed, then it is classified as legacy, stale, optional, or fresh-machine-only
- Given a package is deprecated or distro-specific, when retained, then it is marked as requiring verification
- Given a package purpose is ambiguous, when package triage reaches it, then Aaron is asked a targeted question before it is removed from install inputs

**Evidence artifact:** Package inventory docs, triage notes, or refactored package manifests

---

### Story 2.3: Define minimum viable bootstrap ✅

As future Aaron on a new machine,
I want a minimal setup path,
So that I can become productive before restoring every desktop customization.

Design input: [bootstrap-architecture-notes.md](./bootstrap-architecture-notes.md) — Bash vs Ansible vs Go, idempotency, "not NixOS."

Issue: [#25](https://github.com/amasover/dotfiles/issues/25) (closed, PR [#58](https://github.com/amasover/dotfiles/pull/58))

**Acceptance criteria:**

- Given a fresh Linux machine, when minimum bootstrap is followed, then shell, Git/YADM, editor basics, and core tools are installed or configured
- Given desktop customization is optional, when minimal bootstrap runs, then it does not require i3/polybar/rofi unless explicitly selected
- Given secrets are needed, when bootstrap reaches secret restore, then it uses YADM encryption guidance without printing secrets

**Evidence artifact:** Fresh-machine bootstrap runbook

---

### Story 2.4: Add dry-run/checkpoint behavior

As the repo owner,
I want bootstrap work to show what it would do before doing it,
So that I can avoid accidental system mutation.

Issue: [#26](https://github.com/amasover/dotfiles/issues/26)

**Acceptance criteria:**

- Given a setup command would install packages or change services, when dry-run mode is used, then it prints planned actions without executing them
- Given dry-run cannot be implemented immediately, when bootstrap docs are updated, then manual checkpoints are documented
- Given a script lacks safety gates, when reviewed, then it is not promoted as current

**Evidence artifact:** Script changes or runbook checklist

---

### Story 2.5: Decide future bootstrap architecture ✅

As the repo owner,
I want a clear decision on the future bootstrap model,
So that cleanup does not drift into multiple half-supported approaches.

Issue: [#27](https://github.com/amasover/dotfiles/issues/27) (closed, PR [#47](https://github.com/amasover/dotfiles/pull/47))

**Acceptance criteria:**

- Given current bootstrap options include Bash, YADM, package manifests, and possible Ansible, when reviewed, then a decision record documents the preferred direction
- Given YADM remains in use, when the bootstrap model is defined, then it explains what YADM owns versus what scripts own the bootstrap model is defined, then it explains what YADM owns versus what scripts own
- Given a future rewrite is deferred, when the decision is made, then the interim safe path is documented

**Evidence artifact:** Decision record under `docs/`

---

### Story 2.6: Quarantine AUR updates by a default delay ✅

As the repo owner,
I want AUR package upgrades held back by a default delay (~2 weeks),
So that a freshly compromised AUR package (cf. the June 2026 AUR malware incident) is less likely to land on my machine immediately.

Issue: [#40](https://github.com/amasover/dotfiles/issues/40) (closed, PR [#45](https://github.com/amasover/dotfiles/pull/45)) · Implementation anchor: existing TODO at `.local/bin/setup/update:32` (line 33 runs `yay -Syu --devel --noconfirm ...`).

**Acceptance criteria:**

- Given `setup/update` upgrades AUR packages, when an AUR package's latest version is newer than a configurable threshold (default ~14 days), then it is skipped this run
- Given an AUR update is older than the threshold, when update runs, then it is upgraded normally
- Given native pacman/repo packages (signed Arch repos), when update runs, then they are NOT subject to the AUR delay
- Given I want to upgrade a held package (or everything) now, when I pass an override flag/env, then the delay is bypassed
- Given `-git`/`--devel` packages always build latest upstream, when the design is settled, then their handling under quarantine is decided and documented (the time-based delay means less for them)
- Given the mechanism ships, when documented, then the rationale (June 2026 AUR malware) and the override are recorded

**Notes / approach:**

- Likely approach: read `yay -Qua`, look up each AUR package's Last-Modified date via the AUR RPC, and skip updates newer than the threshold.
- Complementary control: consider running a scanner such as [`aur-malware-check`](https://github.com/lenucksi/aur-malware-check) over to-be-upgraded PKGBUILDs as a second layer, independent of the time delay.

**Evidence artifact:** Changes to `.local/bin/setup/update` (or a helper) + notes; resolves the `setup/update:32` TODO.

---

### Story 2.7: QEMU fresh-install validation harness ✅

As the repo owner,
I want a repeatable QEMU/KVM harness that fresh-installs Arch and runs the bootstrap,
So that bootstrap and manifest changes are validated in a disposable VM before they are trusted on metal.

Issue: [#46](https://github.com/amasover/dotfiles/issues/46) (closed, PR [#61](https://github.com/amasover/dotfiles/pull/61)) · Design input: [decision-bootstrap-architecture.md](./decision-bootstrap-architecture.md) (validation strategy). `qemu-desktop` + `virt-manager` are already installed (Story 2.2 decision D6).

**Acceptance criteria:**

- Given a bootstrap or manifest change, when the harness runs, then a fresh Arch VM is created (scripted `archinstall` or equivalent) without manual install steps
- Given the bootstrap completes in the VM, when the result is inspected, then it matches expectations: `metapac unmanaged` reports no surprises, expected services are enabled, and the desktop session is reachable
- Given a validation run finishes, when the next one is needed, then the VM can be reset or recreated disposably (snapshot or rebuild)
- Given the harness exists, when documented, then a runbook covers creating, running, inspecting, and resetting the VM

**Evidence artifact:** Harness scripts + a runbook under `docs/`

---

### Story 2.8: Adopt metapac on the live workstation ✅

As the repo owner,
I want the current workstation's packages declared in metapac groups and reconciled,
So that the package manifest is executable and complete — the base for any future bootstrap.

Issue: [#48](https://github.com/amasover/dotfiles/issues/48) (closed, PR [#54](https://github.com/amasover/dotfiles/pull/54)) · Design input: [decision-bootstrap-architecture.md](./decision-bootstrap-architecture.md) (package layer design; adoption on the live machine). Subsumes the open Story 2.2 follow-up "generate the grouped manifests from live state".

**Working agreement (grill 2026-07-02):** the metapac config layer is inert — placing/editing `~/.config/metapac/*` (including rendering `config.toml##template`) is blanket-authorized for this story's duration. Every *mutating* command (`metapac sync`, `metapac clean`, any package install/removal, `pacman -D` re-marking) stays individually gated; `metapac unmanaged` is read-only and runs freely.

**Acceptance criteria:**

- Given metapac is not yet installed, when the story starts, then metapac is installed through yay (it is itself an AUR package) with explicit approval
- Given the Story 2.2 inventory, when groups are authored, then the tracked artifact is `.config/metapac/config.toml##template` (yadm template: hostname key rendered from `{{ yadm.hostname }}`, group list selected by `yadm.class`) setting `package_manager = "yay"`, and the rendered `config.toml` stays untracked — no hostname reaches the repo
- Given a machine needs a profile, when adoption configures it, then `yadm config local.class <class>` selects the group list, and the class (public-safe, unique per machine by convention) also names the machine's inbox group
- Given groups are authored, when adoption iterates, then `metapac unmanaged` comes back **exactly empty** — the acceptance test for adoption (undecided packages are parked in the inbox; mis-marked explicits get gated `pacman -D --asdeps` re-marking)
- Given adoption is incomplete, when reconciling, then `metapac clean` is not run (off-limits until `unmanaged` is exactly empty)
- Given the groups replace them, when adoption completes, then the legacy flat manifests under `.config/dotfiles/arch-packages/` are retired (archived or deleted with a pointer)

**Evidence artifact:** Tracked metapac config + group files; adoption notes.

---

### Story 2.9: Steady-state capture loop (inbox + drift report) ✅

As the repo owner,
I want ad-hoc installs auto-captured into a per-host inbox and drift reported on every update,
So that the declared groups stay honest without manual bookkeeping.

Issue: [#49](https://github.com/amasover/dotfiles/issues/49) (closed, PR [#57](https://github.com/amasover/dotfiles/pull/57)) · Depends on Story 2.8 (groups must exist to check declarations against). Design input: [decision-bootstrap-architecture.md](./decision-bootstrap-architecture.md) (auto-capture; drift loop).

**Acceptance criteria:**

- Given an explicit `yay -S` of a package not declared in any group, when the install succeeds, then a yay `PostInstall` Lua hook appends it to this machine's `groups/inbox-<class>.toml` (upgrades — non-empty `local_version` — are skipped)
- Given a package is already declared in any group, when it is installed or synced, then it is not appended to the inbox
- Given `setup/update` finishes, when the run ends, then a read-only drift report (`metapac unmanaged` + declared-but-missing) prints, ending with the copy-paste `metapac sync` command — no auto-mutation
- Given the inbox holds untriaged packages, when the drift report prints, then it includes an **inbox-triage section** (count, names, file to edit) — the periodic review nudge; inboxed packages are declared, so `unmanaged` alone would never surface them (amended 2026-07-03, Aaron's question during 2.9 kickoff)
- Given raw `pacman -S` installs bypass yay hooks, when documented, then `metapac unmanaged` is the named backstop

**Evidence artifact:** Hook addition (`.config/yay/init.lua` or companion), `setup/update` changes, docs.

---

### Story 2.10: AUR install-time gating + portable trust baseline ✅

As the repo owner,
I want fresh AUR installs gated like upgrades and the trust baseline portable across machines,
So that a fresh-machine bootstrap doesn't install freshly-weaponized AUR packages ungated.

Issue: [#50](https://github.com/amasover/dotfiles/issues/50) (closed, PR #92) · Prerequisite for the first real-metal `bootstrap` run (Story 2.3); disposable 2.7 VM runs are exempt. Promotes the un-ticketed Story 2.6 follow-up (`AURPostDownload` gating); origin: 2026-07-02 grill of the 2.5 decision. Design input: [aur-malware-mitigation.md](../knowledge/reference/aur-malware-mitigation.md).

**Acceptance criteria:**
how do you recommend making it portable
- Given an AUR package is being installed for the first time, when it is too new / orphaned / maintainer-changed vs the baseline, then an `AURPostDownload` hook warns and aborts, with an explicit bypass
- Given the trusted-maintainer baseline is machine-local state today, when this story lands, then the baseline is portable to a new machine (mechanism decided in-story: YADM-tracked, encrypted, or seeded from the repo) so the bootstrap can restore trust state before first use
- Given the 2.7 harness exists, when a fresh VM bootstrap installs the AUR set, then install-time holds behave as designed
- Given the gate ships, when documented, then the coverage table in `aur-malware-mitigation.md` is updated (the "malicious new package" row becomes covered)

**Evidence artifact:** Hook changes + baseline portability mechanism + updated threat-model doc.

---

### Story 2.11: Review the org-internal AUR packages

As the repo owner,
I want the three org-internal AUR packages (Story 2.2 D10) given a real disposition,
So that the last unexplained packages on the machine stop hiding in a needs-verify bucket.

Issue: [#51](https://github.com/amasover/dotfiles/issues/51)

**Redaction rule:** the package names are org-internal — they live only in the gitignored private note (`docs/private/package-inventory-private.md`) and must never appear in tracked files, issues, or chat. Aaron reviews these packages himself, later.

**Acceptance criteria:**

- Given the three D10 packages, when Aaron reviews them, then each gets a disposition: uninstall (gated) or keep-with-reason
- Given a package is kept, when 2.8's machine-local group is updated, then it stays declared there (or is promoted to a YADM-encrypted group if durability is wanted) — never in tracked plaintext
- Given a package is uninstalled, when removed, then it leaves the machine-local group and `metapac unmanaged` stays clean

**Evidence artifact:** Updated private note + a redacted disposition line in the inventory doc.

---

### Story 2.12: Declare non-pacman packages via additional metapac backends

As the repo owner,
I want the tools installed through cargo/uv/pipx/npm/brew declared alongside the pacman groups,
So that a rebuild restores the forgettable one-off installs, not just the OS packages.

Issue: [#53](https://github.com/amasover/dotfiles/issues/53) · Depends on Story 2.8 (config + groups exist; `enabled_backends = ["arch"]` was 2.8's deliberate scope). Design input: [decision-bootstrap-architecture.md](./decision-bootstrap-architecture.md) (reconcile vs update loop).

2026-07-03 inventory of the non-arch surface (tiny but high-forgettability): uv holds 3
tools (aider + cecli), pipx holds 1 (dbt-core), npm -g holds 1 real global
(@github/copilot; corepack/npm ship with node), brew holds 1 leaf from a custom tap
(env0/terratag/terratag), cargo holds 0 user crates, VS Code holds 15 extensions.
Backend entries live in the existing purpose-group files (per-backend sections in the
same TOML), not new groups.

**Acceptance criteria:**

- Given each detected backend, when adoption decides, then each gets an explicit disposition with Aaron: enable + declare, leave to the update loop, or consolidate away (e.g. migrate the lone pipx tool to uv rather than enabling a fourth python-tool manager)
- Given nvm owns node (update loop; 2.8 adoption notes), when the npm backend is considered, then the nvm ordering problem is resolved deliberately — a fresh `metapac sync` runs before nvm/node exist; verify how metapac handles an enabled-but-absent backend before enabling it
- Given brew's tap-qualified name (`env0/terratag/terratag`), when the brew backend is enabled, then tap handling is verified against metapac 0.9.4 (taps may need install hooks or documentation)
- Given VS Code extensions may already ride Settings Sync, when the vscode backend is considered, then only one mechanism is chosen as the source of truth
- Given a backend is enabled, when adoption completes, then `metapac unmanaged` is exactly empty for that backend too, and the template's `enabled_backends` is updated + re-rendered live
- Given crates/npm/PyPI installs have no quarantine analog (Story 2.6 covers AUR only), when backends are enabled, then the ungated supply-chain surface of a fresh `metapac sync` is noted in the threat-model doc — accepted or ticketed, not silent

**Evidence artifact:** Updated `config.toml##template` + group files with per-backend sections; disposition table in the adoption notes.

---

### Story 2.13: Close non-package bootstrap gaps (cloned shell/editor artifacts)

As the repo owner,
I want the git-cloned artifacts that `.zshrc` and the editors depend on placed by the bootstrap (or explicitly runbook'd),
So that a fresh machine boots into a working shell and editors, not just the right package set.

Issue: [#60](https://github.com/amasover/dotfiles/issues/60) · Blocked on Story 2.3
([#25](https://github.com/amasover/dotfiles/issues/25), PR [#58](https://github.com/amasover/dotfiles/pull/58))
merging — it owns `setup/bootstrap`; branch off `main` afterwards (no stacked PRs).

Origin: 2026-07-03 audit of the retired 2019 `install` script against the live machine
("what did the old script install that survives and nothing reinstalls?"). metapac covers
every package (2.8) and Story 2.12 covers backend-managed tools; what's left is git-clone
artifacts that are live and load-bearing but installed by nothing:

- **oh-my-zsh custom plugins** — `~/.oh-my-zsh/custom/plugins/{zsh-autosuggestions,zsh-nvm}`;
  both are in `.zshrc` `plugins=(…)`, and zsh-nvm is what provides nvm/node at all. On a
  fresh machine the bootstrap's oh-my-zsh step leaves plugin-not-found warnings and no nvm.
- **Vundle** — `~/.vim/bundle/Vundle.vim`, required by `.vimrc`. `tools/vendor_repos`
  clones it idempotently, but nothing calls vendor_repos. (Its other entry — polybar-scripts
  community-modules — is dead: not cloned live, referenced by no polybar config.)
- **Spacemacs** — `~/.emacs.d` is a live clone and `setup/update` still pulls it, but only
  the deleted 2019 installer ever created it. Needs a disposition (bootstrap / runbook /
  retire with the Story 3.2 editor call), not silence.

Deliberately out of scope: the 2019 Go audio binaries (`dot`, `volume`) — Story 3.12
([#59](https://github.com/amasover/dotfiles/issues/59)) retires them in favor of wpctl
instead of teaching the bootstrap to rebuild them; the python3.7–3.10-era
`pip install --user` leftovers stay dead; one-time niceties (default browser via
`xdg-settings`) are runbook material at most.

**Acceptance criteria:**

- Given a fresh machine after `bootstrap`, when an interactive zsh starts, then both custom plugins are present, no plugin-not-found warnings appear, and nvm resolves
- Given `vendor_repos` half-overlaps this story, when it lands, then vendored clones have exactly one owner (bootstrap absorbs or calls vendor_repos) and the dead polybar-scripts entry is dropped or justified
- Given Spacemacs is legacy-era, when this story lands, then `~/.emacs.d` has an explicit disposition with Aaron rather than an implicit gap
- Given the fresh-machine runbook is the operator contract, when gaps close, then its step list reflects the new coverage and the remaining manual one-times
- Given Story 2.7's harness exists, when this lands, then a VM run (or at minimum `--check`) demonstrates the added steps

**Evidence artifact:** Updated `setup/bootstrap` + fresh-machine runbook; disposition notes here or in the bootstrap inventory.

---

### Story 2.14: Vendor the openconnect-service PKGBUILD into dotfiles

As the repo owner,
I want the dead-upstream VPN service package rebuildable from my own repo,
So that the work-VPN stack survives a fresh machine instead of living only as an orphaned install.

Issue: [#62](https://github.com/amasover/dotfiles/issues/62) · Origin: Story 2.7 VM validation caught `openconnect-service` as AUR-deleted while its socket unit is live infrastructure (the untracked `~/.local/bin/tools/vpn` script drives it). Upstream PKGBUILD source: [WarheadsSE/PKGs](https://github.com/WarheadsSE/PKGs/tree/master/openconnect-service) (Aaron's original source).

**Acceptance criteria:**

- Given the upstream PKGBUILD, when vendored, then it lives at a yadm-tracked path with provenance and license recorded
- Given a machine needs the VPN stack, when setup runs, then the package builds/installs via `makepkg -si` as a (class-gated if work-only) setup step
- Given metapac ≥0.10 validates group names against repos/AUR, when the locally-built package is declared, then it lives in the machine's machine-local group (or a cleaner mechanism found in-story) — never a tracked group
- Given the live `vpn` script references the work VPN hostname, when adopted, then the hostname is externalized to an untracked or YADM-encrypted file — never tracked plaintext
- Given the site config in `/etc/openconnect/`, when handled, then it stays machine-local or YADM-encrypted

**Evidence artifact:** Vendored PKGBUILD + setup step + adopted `vpn` script with externalized config.

---

### Story 2.15: package-removal hook — auto-update group TOMLs on uninstall ✅

As the repo owner,
I want package removals to update my group declarations the way installs update the inbox,
So that uninstalling doesn't leave landmines (sync reinstalling it, or dead names aborting validation).

Issue: [#63](https://github.com/amasover/dotfiles/issues/63) (closed, PR #81) · Companion to Story 2.9's `PostInstall` capture. Origin: 2.7 close-out — today a removal leaves the declaration behind; tracked groups would get re-synced back in, and stale machine-local entries for AUR-deleted names abort `metapac sync` under ≥0.10 name validation.

**Mechanism (decided 2026-07-07 on #63):** an alpm hook, not a yay Lua hook — yay's
Lua API has no removal event (verified against v13.0.1 and master `doc/lua.md`).
`.config/dotfiles/pacman-hooks/metapac-dedeclare.hook`, symlinked into
`/etc/pacman.d/hooks/` by bootstrap step 6c, runs `tools/metapac-dedeclare`
PostTransaction on every removal — `yay -R` and raw `pacman -R` alike, so the
2.9-style bypass caveat disappears for removals.

**Acceptance criteria:**

- Given a package removal (yay or raw pacman), when the package is declared in a machine-scoped file (`inbox-<class>`, machine-local), then the hook deletes the line silently
- Given it's declared in a tracked purpose group, when removed, then the hook edits the group and the change surfaces as normal yadm/git drift for review at commit time
- Given the hook file lives in `/etc` (outside yadm), when a machine hasn't run bootstrap step 6c, then the drift report's declared-but-missing section is the documented backstop
- Given the hook lands, when the drift report runs after a hooked removal, then no declared-but-missing line appears for that package

**Evidence artifact:** Hook + script + a live validation removal (e.g. the gnu-netcat → openbsd-netcat swap).

---

### Story 2.16: Automate Uplink (the game) install on the work machine

As the repo owner,
I want my purchased copy of Uplink installable by setup on the machines I play it on,
So that feeling like a hacker survives a machine rebuild.

Issue: [#64](https://github.com/amasover/dotfiles/issues/64) · Origin: 2.7 VM validation — the AUR-era PKGBUILD needs the purchased `uplink.zip` supplied locally (`file://` source), so it can never unattended-install; currently parked machine-local.

**Acceptance criteria:**

- Given the purchased zip can't be distributed, when storage is decided (YADM-encrypted payload / private fetch / documented drop-point), then the zip is never plaintext-committed to the public repo
- Given a machine should have the game, when the (class-gated) setup step runs with the zip available, then the package builds and installs via the vendored PKGBUILD (Story 2.14 pattern)
- Given fresh unattended installs skip it, when declared, then it lives machine-local on machines that have it — never in tracked groups

**Evidence artifact:** Vendored PKGBUILD + automated step + zip provenance/storage doc.

---

### Story 2.17: Fix the issues observed in the first fully-bootstrapped VM

As the repo owner,
I want the UI-level issues I saw in the first fully-bootstrapped VM's session fixed,
So that a fresh machine boots into a desktop that's actually right, not just package-complete.

Issue: [#65](https://github.com/amasover/dotfiles/issues/65) · Tracking story so 2.7 closes on its own acceptance (exactly-empty `unmanaged` + reachable session). **Specifics enumerated by Aaron at pickup** — observed via the virt-manager console after the 2026-07-04 acceptance run; the issue holds working notes (reproduction, likely fix destinations, overlap check with Story 2.13's known cloned-artifact gaps).

**Acceptance criteria:**

- Given Aaron's observed-issue list, when triaged, then each is fixed here or explicitly routed to its owning story (2.13 gaps, group membership, service-enablement hooks, desktop config)
- Given fixes land, when a VM session is re-inspected (revived or fresh run), then the observed issues are gone

**Evidence artifact:** Triaged issue list + fixes + re-validated VM session.

---

### Story 2.18: Keep pacman mirrors fresh (reflector.timer)

As the repo owner,
I want mirror ranking to happen on a schedule on live machines,
So that pacman/yay traffic doesn't crawl because the mirrorlist quietly rotted.

Issue: [#66](https://github.com/amasover/dotfiles/issues/66) · Origin: 2.7 pre-merge review — bootstrap step 3b now re-ranks a stale (>7 days) mirrorlist at bootstrap/re-run time, but between bootstraps the list rots; Aaron re-runs reflector by hand today (US, https, fastest/latest 20, rate-sorted, age 3).

**Acceptance criteria:**

- Given the `reflector` package ships `reflector.timer` and `/etc/xdg/reflector/reflector.conf`, when this lands, then reflector is declared in a tracked group and the timer is enabled by a declared hook (same pattern as the other service hooks)
- Given the conf lives under `/etc` (outside yadm's `$HOME` worktree), when a fresh machine bootstraps, then the chosen reflector args apply without hand-editing (hook-written conf or an equivalently reproducible mechanism)
- Given the timer is the steady-state owner, when it's active, then `systemctl is-enabled reflector.timer` passes on the live machine and in a bootstrapped VM

**Evidence artifact:** Group + hook change; `systemctl list-timers` showing reflector.timer.

---

### Story 2.19: vm-harness observability — host logs, `--detach`, and `up`

As the repo owner,
I want harness runs logged on the host, detachable, and runnable end-to-end with one command,
So that multi-hour VM validations survive a closed terminal and leave evidence I can read afterwards.

Issue: [#70](https://github.com/amasover/dotfiles/issues/70) · Design input: [vm-harness-observability-notes.md](./vm-harness-observability-notes.md) (2026-07-04 grill, decisions D1–D11) + [CONTEXT.md](./CONTEXT.md) vocabulary. Branch off `main`.

**Acceptance criteria:**

- Given any phase produces output, when it runs, then a per-phase timestamped log lands in `~/.local/state/bootstrap-harness/logs/` (survives `destroy`), ANSI-stripped, ending in a result line; the default tees to stdout with colors intact, and `--quiet`/`VM_HARNESS_QUIET` suppresses stdout
- Given `--detach`, when a command starts, then it runs under `systemd-run --user`, returns immediately, notifies on completion (`notify-send`), and `vm-harness status` / `tail` can find it
- Given `vm-harness up`, when invoked, then fetch-if-missing → create → install → boot → wait_ssh → bootstrap → check run in order; it dies if a domain already exists (never auto-destroys), and on failure stops, leaves the VM intact, and names the phase, rc, and next options
- Given `wait_ssh`, when `bootstrap` runs (inside `up` or manually), then it proceeds only once an authenticated shell succeeds (bounded poll)
- Given `tail`, bare invocation follows the newest log; `tail install` sudo-follows the serial log; completed installs copy the serial log into the run's state logs

**Evidence artifact:** Script changes + a detached `up` run's complete log set.

---

### Story 2.20: Track the patched agnoster theme as an oh-my-zsh custom theme ✅

As the repo owner,
I want my patched agnoster prompt tracked in this repo and placed by the bootstrap,
So that the wrap fix survives oh-my-zsh updates and lands on a fresh machine automatically.

Issue: [#71](https://github.com/amasover/dotfiles/issues/71) (closed, PR #72) · Origin: the live
`~/.oh-my-zsh/themes/agnoster.zsh-theme` carries a local patch (the segment bar is
printed by a `precmd` hook instead of living in `PROMPT`, so long input lines wrap
without smearing segment colors; plus git ahead/behind and hg prompt-latency fixes).
It sits in the omz checkout's own tracked tree, so `setup/update`'s omz pull fights
it, and nothing recreates it on a fresh machine.

Design constraint: the theme cannot be yadm-tracked inside `.oh-my-zsh/` — yadm clone
runs before bootstrap, so the pre-existing directory would make the oh-my-zsh step
skip the real install (and the official installer refuses an existing dir anyway).
So the file lives at `.config/dotfiles/oh-my-zsh-custom/themes/agnoster.zsh-theme`
(yadm-mapped, outside the omz checkout) and bootstrap symlinks it into
`~/.oh-my-zsh/custom/themes/`, which shadows the bundled theme by name and is
gitignored by the omz checkout. The custom *plugin* clones (zsh-autosuggestions,
zsh-nvm) stay with Story 2.13 ([#60](https://github.com/amasover/dotfiles/issues/60)).

**Acceptance criteria:**

- Given the theme is tracked at `.config/dotfiles/oh-my-zsh-custom/themes/agnoster.zsh-theme`, when bootstrap runs past the oh-my-zsh step, then `~/.oh-my-zsh/custom/themes/agnoster.zsh-theme` is a symlink to it (idempotent; `--check` prints the step)
- Given the live machine, when this lands, then the bundled theme is restored to upstream (clean omz checkout) and an interactive zsh still gets the patched prompt (the custom theme defines `agnoster_precmd`; upstream's doesn't — so the function existing proves the custom file is the one sourced)
- Given the fresh-machine runbook is the operator contract, when this lands, then its step list names the symlink step

**Evidence artifact:** Tracked theme + bootstrap step; live verification that the custom theme is the one sourced.

### Story 2.21: vm-harness progress mode — compact stage display instead of raw logs

As the repo owner,
I want a mode that shows a compact live status (phase, current stage, elapsed) instead of streaming raw output,
So that I can watch a run's health at a glance without the serial/ssh firehose, while failures still stop the run loudly.

Issue: [#73](https://github.com/amasover/dotfiles/issues/73) · Follow-up to Story 2.19 ([#70](https://github.com/amasover/dotfiles/issues/70)): a hybrid between fully-attached (raw stream) and `--detach` (no terminal). Branch off `main`.

**Acceptance criteria:**

- Given the progress flag (name decided at pickup grill), when a phase runs, then the terminal shows a compact live-updating status — phase (n of 6), a stage derived from the underlying stream (HARNESS-* markers, archinstall/pacstrap/yay milestones), and elapsed time — instead of raw output
- Given progress mode, the state logs are unchanged — the full scrubbed capture is still written and `vm-harness tail` remains the drill-down
- Given a phase fails in progress mode, the run stops exactly as today (phase, rc, options) and the tail of the failing phase's log is printed, so the error is visible without switching commands
- Given `--detach` or `--quiet` combined with progress mode, the behavior is explicit (rejected or defined), not accidental

**Evidence artifact:** a progress-mode `up` transcript + its unchanged full log set.

---

### Story 2.22: AUR download hygiene for VM runs

As the repo owner,
I want VM bootstrap runs to stop tripping AUR's clone-burst throttling,
So that full-profile validations run fast without hammering shared infrastructure.

Issue: [#75](https://github.com/amasover/dotfiles/issues/75) · Options recorded on the issue (host-cache seed excluding built packages / GitHub AUR-mirror pre-seed / gentler retry backoff); decide at pickup grill. From the 2.19 sessions; bootstrap's retry loop is the current band-aid.

**Acceptance criteria:**

- Given a fresh VM `up`, when the AUR set installs, then a normal run completes without throttling-induced retries
- Given cache warming (decided 2026-07-10 at pickup: unattended bootstrap pre-clones each declared AUR pkgbase into yay's cache, one gentle clone at a time, before the first sync), it seeds **PKGBUILDs only, from the AUR itself** — never built packages or host copies, so the default `up` still proves every AUR package builds from source on a fresh machine
- Given bootstrap's sync retry loop, backoff grows between attempts instead of retrying hot

**Evidence artifact:** a fresh `up` log set showing the AUR phase with no throttle retries.

---

### Story 2.23: Triage redis→valkey

As the repo owner,
I want the repos' redis→valkey replacement decided and reflected in the groups,
So that the standing drift line disappears and installs stop pulling a superseded package.

Issue: [#76](https://github.com/amasover/dotfiles/issues/76) · Captured live by the 2.9 inbox hook during the 2.7 VM acceptance run; the host group still declares `redis` and the host runs AUR redis. Small; Aaron's call.

**Acceptance criteria:**

- Given the decision (migrate to valkey or deliberately pin redis), the group TOML declares the chosen package and the live machine matches it
- Given `metapac unmanaged` and the drift report, no redis/valkey line remains

**Evidence artifact:** the group diff + a clean drift report.

---

### Story 2.24: update script — synchronous batch Spacemacs package update ✅

As the repo owner,
I want the update script to run the Spacemacs package update synchronously and verify the result,
So that an interrupted update can no longer leave a half-installed package that breaks every emacs startup.

Issue: [#79](https://github.com/amasover/dotfiles/issues/79) (closed, PR #80) · Root cause of the 2026-07-06 `lsp-mode` "Cannot open load file" breakage; see [knowledge/errors/spacemacs-half-installed-package.md](../knowledge/errors/spacemacs-half-installed-package.md).

**Acceptance criteria:**

- Given the emacs branch of `.local/bin/setup/update`, both halves of the Spacemacs update (update-packages, then the startup reinstall) run as synchronous batch emacs invocations whose failures are visible in the terminal
- Given a package dir under `elpa/develop` missing its `<pkg>-autoloads.el`, the script warns and names it before relaunching GUI emacs
- Given a clean update, GUI emacs is relaunched automatically

**Evidence artifact:** script diff + a dry-run of the autoloads scan over the live elpa tree.

---

### Story 2.25: dotnet — repo stack replaces the AUR -bin family

As the repo owner,
I want the .NET packages declared from the official repos instead of the AUR -bin family,
So that unattended bootstrap can't deadlock on a repo-vs-AUR provider conflict (and installs stop building 200MB AUR tarballs).

Issue: [#82](https://github.com/amasover/dotfiles/issues/82) · Origin: the 2026-07-05 and 07-08 VM bootstrap runs both died at `metapac sync` — `storageexplorer`'s generic `dotnet-runtime` dep resolves to repo `dotnet-runtime` (extra now ships official .NET), which conflicts the AUR `dotnet-runtime-bin` pulled by the declared `-bin` packages; `--noconfirm` answers the removal prompt N → unresolvable. Same pattern as 2.7's rust swap.

**Acceptance criteria:**

- Given development.toml, the four AUR declarations (`dotnet-sdk-bin`, `dotnet-sdk-9.0-bin`, `aspnet-runtime-bin`, `aspnet-runtime-9.0-bin`) are replaced by their extra equivalents (`dotnet-sdk`, `dotnet-sdk-9.0`, `aspnet-runtime`, `aspnet-runtime-9.0`)
- Given an unattended VM bootstrap from the merged branch, `metapac sync` passes the dotnet layer with no conflict prompt
- Given the host still runs the -bin family, when the gated live swap runs, then `metapac unmanaged` stays exactly empty afterward and the EOL `dotnet-runtime-2.1`/`2.2` relics get an explicit keep/drop decision from Aaron

**Evidence artifact:** Group diff + a passing VM sync + the host-swap record on #82.

---

### Story 2.26: unattended bootstrap determinism — fail fast, pin providers

As the repo owner,
I want unattended bootstrap failures to be fast and its package resolution deterministic,
So that a broken declaration fails in seconds with the real error, and `--noconfirm` never picks arbitrary providers.

Issue: [#83](https://github.com/amasover/dotfiles/issues/83) · Origin: the 2026-07-08 failure burned 5 sync retries (~minutes each) on a deterministic conflict, and auto-answered provider prompts with option 1 (tessdata → Afrikaans, portal → cosmic).

**Acceptance criteria:**

- Given `metapac sync` output containing a known-deterministic pacman error (unresolvable conflicts, target not found), the unattended retry loop dies immediately quoting the decisive line instead of retrying
- Given virtual packages the declared set depends on (`tessdata`, `xdg-desktop-portal-impl`, `oci-runtime`, `qt6-multimedia-backend`), the chosen provider is declared in a group, so unattended runs resolve them without prompts and match the host
- Given transient failures (AUR clone throttling, corrupt cached archives), the existing retry behavior is unchanged

**Evidence artifact:** Bootstrap diff + a VM run log showing either instant deterministic death or a prompt-free sync.

---

### Story 2.27: vm-harness — root partition must fill the disk

As the repo owner,
I want the VM's root partition sized from `DISK_SIZE` instead of a hard-coded 38 GiB,
So that the disk the harness allocates is actually usable and full-profile bootstraps stop dying on ENOSPC.

Issue: [#87](https://github.com/amasover/dotfiles/issues/87) · Origin: the 2026-07-08 unattended bootstrap died mid-AUR-builds with ENOSPC — 2.7's disk-sizing fix bumped the volume to `$DISK_SIZE` (default 80G) but the archinstall seed-config layout still pinned root at 38 GiB, leaving half the disk unallocated; the workstation set's caches (12G yay + 4.8G pacman at death) fill 38G before the sync finishes.

**Acceptance criteria:**

- Given the seed-config heredoc, the root partition size is computed from `DISK_SIZE` (disk minus ESP and tail slack), so `VM_HARNESS_DISK` overrides propagate to the layout
- Given a fresh `create → install`, `df /` reports roughly the full disk size
- Given the already-running VM, an in-place grow (`sfdisk -N 2` expand + `resize2fs`) rescues it without a recreate

**Evidence artifact:** fresh-create `df /` output + the interrupted bootstrap resuming past the ENOSPC point.

---

### Story 2.28: Chaotic-AUR binaries for supported packages — same gating as AUR ✅

As the repo owner,
I want declared AUR packages that [Chaotic-AUR](https://aur.chaotic.cx/) pre-builds installed as binaries from that repo,
So that installs and VM bootstraps skip long local builds without loosening the AUR trust gates.

Issue: [#89](https://github.com/amasover/dotfiles/issues/89) (closed, PR #93) · Chaotic-AUR is an automated build farm for AUR packages (GitLab CI since infra 4.0, GPG-signed, `chaotic-keyring` + `chaotic-mirrorlist` + a `[chaotic-aur]` pacman.conf entry). Trust notes: it auto-builds the same PKGBUILDs, so it inherits AUR's trust model wholesale — a weaponized package ships from chaotic as fast as from AUR, minus even the local build-time inspection moment; it sometimes patches builds ("interferes"), adding the chaotic team as a trusted party; and because pacman/yay prefer a repo hit over AUR, its packages silently stop flowing through the yay Lua quarantine hook. The gate has to follow the packages. Design input: [aur-malware-mitigation.md](../knowledge/reference/aur-malware-mitigation.md); related: 2.22 (AUR clone-burst throttling), 2.10 (install-time gating).

**Acceptance criteria:**

- Given the bootstrap, the chaotic-aur repo is configured (key `3056513887B78AEB` lsigned, keyring + mirrorlist installed, pacman.conf entry after the official repos so core/extra always win) and declared packages chaotic carries install as prebuilt binaries; packages it doesn't carry (its banished list includes e.g. `gst-plugins-bad/ugly`) still build from AUR as today
- Given a chaotic-sourced package, the same quarantine protections apply as for AUR builds (age-out delay, maintainer-change/orphan checks against the trust baseline) even though installs bypass yay — mechanism decided in-story (pacman hook, pre-sync check, or keeping gated packages yay-built)
- Given a package Aaron wants built locally for a given install, `yay -S aur/<pkg>` forces the AUR path, and the threat-model doc records that pacman/yay have no persistent per-package repo pin (a declared package chaotic carries installs as the chaotic binary)
- Given the gate ships, `aur-malware-mitigation.md` documents how chaotic-sourced packages are covered
- Given a fresh VM `up`, the chaotic-provided set installs without local builds and the log shows the gating intact

**Evidence artifact:** bootstrap + pacman.conf diff, updated threat-model doc, and a VM run log showing binary installs with gating applied.

---

### Story 2.29: Scripted metal provisioning — partitions, disk encryption, bootloader

As the repo owner,
I want the pre-bootstrap provisioning of a metal machine (partitions, LUKS disk
encryption, bootloader, user) driven by a tracked, parameterized recipe the official
Arch ISO can consume,
So that a bare-metal install starts from the same declarative recipe philosophy as
everything else, instead of hand-typed disk commands at an ISO prompt.

Issue: [#95](https://github.com/amasover/dotfiles/issues/95) · The vm-harness already proves the pattern: cloud-init on the official ISO drives unattended `archinstall` from a generated seed (Story 2.7). **Primary consumer (amended 2026-07-10, [decision-daily-driver-vm.md](./decision-daily-driver-vm.md)): the daily-driver VM on the Windows machine** — same recipe, LUKS root inside the guest; the spare-laptop metal run (months out) is the later variant and inherits it.

**Acceptance criteria:**

- Given a machine booted from the official Arch ISO (VMware guest or metal), when the recipe runs, then a tracked, parameterized generator produces an archinstall config provisioning GPT partitions (ESP + LUKS-encrypted root sized from the disk), disk encryption, the boot path fitting the target (VM vs refind metal), a user, and sshd
- Given secrets (LUKS passphrase, user password), when the seed is generated, then they are supplied at run time (prompt or env) and never land in tracked files; any generated seed containing them is destroyed after use
- Given vm-harness's seed generation exists, when the generator is built, then shared logic is factored once (harness, daily-VM, metal as consumers) or the divergence is explicitly recorded with reasons
- Given the daily-driver VM is the first real consumer, when the story lands, then its creation run is the primary evidence; the spare-laptop run later revalidates the metal variant

**Evidence artifact:** tracked generator + recipe, the daily-VM creation record, and (later) the metal run record.

---

### Story 2.30: `daily-vm` class — hardware group split + guest tools

As the repo owner,
I want a machine class for the daily-driver VM, with hardware-bound packages split
out of the shared groups,
So that the Windows-hosted VM (the cleanup era's rebuild milestone target —
[decision-daily-driver-vm.md](./decision-daily-driver-vm.md)) reconciles from the
same purpose groups as metal machines instead of forked variants.

Issue: [#96](https://github.com/amasover/dotfiles/issues/96) · Origin: 2026-07-10 repo-direction grill Q4/Q5. Class name `daily-vm` is a working name — finalize in-story (public-safe, lands in the tracked template).

**Acceptance criteria:**

- Given the nine hardware-bound packages (`acpi`, `acpid`, `intel-ucode`, `linux-firmware`, `refind`, `refind-theme-nord`, `xf86-video-{amdgpu,intel,vesa}`), when the split lands, then they move from `base`/`desktop` into a new `hardware` purpose group, and the `workstation` class activates it — a dry-run reconcile on the live machine shows a no-op
- Given the new class, when its template branch renders, then it activates every purpose group except `work` and `hardware`, plus a new guest-tools group (`open-vm-tools`, `xf86-video-vmware`) and its own `inbox-<class>.toml`
- Given the runbook's class table, when the class lands, then the table documents both classes and their group deltas
- Given the vm-harness default class is `workstation`, when the split lands, then harness runs still converge (the hardware group installs harmlessly under QEMU, or the harness class choice is revisited — decided in-story)
- Given harness guests boot with NetworkManager disabled (archinstall's default networking — observed in the 2026-07-19 check-phase service sample), when the daily-vm class lands, then the guest's network stack is decided deliberately: enable NetworkManager to match the declared NM applet/dispatcher stack, or document the alternative

**Evidence artifact:** groups/template diff, a live no-op dry-run, and the updated class table.

---

### Story 2.31: vm-harness — resumable `up`

As the repo owner,
I want a failed `vm-harness up` to be resumable from the first incomplete phase,
So that a bootstrap failure late in the pipeline costs one re-run command instead
of manual phase archaeology or a destroy-and-reinstall.

Issue: [#98](https://github.com/amasover/dotfiles/issues/98) · Origin: the 2026-07-10 detached `up` died in `bootstrap` (displaylink quarantine hold); today `up` dies whenever the domain exists, so resuming means reading `status`/logs, deducing the completed phases, and re-running the rest by hand. Phase-completion evidence already exists: the `=== <phase> done rc=N` log trailers and libvirt domain state.

**Acceptance criteria:**

- Given a previous `up` that failed at some phase, when `up` runs again (or `up --resume` — flag vs. default decided in-story), then it detects the completed phases and continues from the first incomplete one instead of dying on "domain already exists"
- Given resume is impossible from the recorded state (e.g. `install` died partway, leaving a half-provisioned disk), when `up` runs, then it fails fast with the exact next command (`destroy` + fresh `up`) — the never-auto-destroy guarantee stays
- Given an operator asking "where would it resume?", when `status` runs, then it names the next phase a resume would start from
- Given a resumed run, when it finishes, then its logs are distinguishable from (but associated with) the original run's set

**Evidence artifact:** a deliberately interrupted `up` plus a resumed run's log set showing continuation from the failed phase.

---

### Story 2.32: quarantine hold messages misdiagnose the failure

As the repo owner,
I want quarantine hold output to name the actual failure,
So that a held package's remedy can be chosen from the message instead of
re-deriving the cause from raw logs.

Issue: [#100](https://github.com/amasover/dotfiles/issues/100) · Split from #98's grill (decision 7). Observed 2026-07-10: bootstrap's `die_still_held` printed "no aged version exists yet" when the aged displaylink 6.3-1 build actually failed on `evdi<1.15` (gone from repos); the chaotic gate's hold printed `version ?` because the gate never passes the version to the policy.

**Acceptance criteria:**

- Given a second consecutive hold of the same package, when bootstrap dies, then the message distinguishes "stepping found no aged version" from "the aged build failed" and names the decisive error line in the latter case
- Given a chaotic gate hold, when the message prints, then it names the held package's version (or omits the placeholder entirely) instead of `version ?`

**Evidence artifact:** message diff + a reproduced hold showing the corrected output.

---

### Story 2.33: pre-flight quarantine holds — step aged packages before the sync

As the repo owner,
I want bootstrap to evaluate the quarantine policy across the whole declared
non-repo set before the first sync,
So that every hold is known and remediated up front instead of being
discovered one full sync crash at a time.

Issue: [#103](https://github.com/amasover/dotfiles/issues/103) · Origin: Aaron's live 2026-07-10 observation — the sync loop crashes, steps one held package, re-runs the entire multi-minute sync, and crashes on the next hold (that run burned 3 sync attempts to discover 2 age-holds: terraform-ls-bin, wstunnel-bin; earlier runs did the same for evdi-dkms and displaylink). The hold set is computable from one batched AUR RPC call — the pass/fail verdict for every package is knowable before the installer starts.

**Acceptance criteria:**

- Given the declared set contains N age-held packages, when unattended bootstrap runs, then all N are identified before the first sync and stepped in one pass — a hold no longer costs a full sync attempt to discover
- Given identity holds (orphan / maintainer-change / RPC failure), when pre-flight runs, then bootstrap dies listing ALL of them with their remedies at once, not one per crash
- Given pre-flight exists, when a package flips to held mid-run anyway, then the install-time gates still catch it — pre-flight is an optimization, the gates stay the enforcement
- Given the sync retry loop, when pre-flight lands, then hold remediation no longer consumes retry-budget attempts (retries are for transient AUR throttling again)

**Evidence artifact:** an unattended run log with ≥2 aged packages showing one pre-flight step pass and a first sync with zero hold-triggered crashes.

---

### Story 2.34: bootstrap syncs the system before package work

As the repo owner,
I want bootstrap to run one full system sync (`pacman -Syu`) before any
package installs or AUR builds,
So that a run whose sync DBs have aged — a resumed VM days later, or a real
machine bootstrapped from an old snapshot — doesn't 404 on package files the
mirrors have already purged.

Issue: [#107](https://github.com/amasover/dotfiles/issues/107) · Origin: the 2026-07-19 resumed VM run — DBs dated from Jul 15 (`pacman -Sy` only runs inside the chaotic-enable step, which a resume skips), mesa/svt-av1 had been rebuilt since, every mirror 404'd the superseded filenames, and the pre-build died on missing deps. Reflector considered and rejected: mirror ranking can't resurrect purged files.

**Acceptance criteria:**

- Given any bootstrap run, when the mirror step completes, then a full `pacman -Syu` runs before yay, pre-build, or reconcile — the same step on fresh and resumed runs (no divergence)
- Given `--check`, when the step is reached, then it prints its plan and mutates nothing
- Given the sync, then it is `-Syu`, never bare `-Sy` — no partial-upgrade state

**Evidence artifact:** a resumed unattended run (DBs ≥1 day old) whose package phase completes without `failed retrieving file` errors.

---

### Story 2.35: every package bootstrap installs is declared ✅

As the repo owner,
I want every package that bootstrap or the harness installs to be declared in
a metapac group,
So that the exactly-empty `unmanaged` check stays a strict drift backstop
instead of being weakened with allowlists.

Issue: [#112](https://github.com/amasover/dotfiles/issues/112) (closed, PRs #113/#114) · Origin: the first run to finish bootstrap green (2026-07-19) died at check with four unmanaged packages — chaotic-keyring/chaotic-mirrorlist (installed by the 2.28 enable step, declared nowhere) and qemu-guest-agent/zram-generator (harness guest install; real home is the 2.30 class split, #96).

**Acceptance criteria:**

- Given the chaotic-enable step installs its keyring and mirrorlist, then both are declared in `base.toml` (host drifts as declared-but-missing until chaotic adoption — documented pattern)
- Given a declared package that is AUR-missing but present in the chaotic repo (chaotic-native infrastructure), when pre-flight verdicts it, then it buckets as installable — not a fatal declaration error; true unknown names still die
- Given a harness-created guest, when `cmd_bootstrap` runs, then the guest's `machine-local.toml` is harness-written with the guest hardware set (rewritten every bootstrap; rehomed by 2.30)
- Given both changes, when the check phase runs after a green bootstrap, then `metapac unmanaged` is exactly empty

**Evidence artifact:** a run log with `=== bootstrap done rc=0` followed by `=== check done rc=0`.

---

## Acceptance Criteria (Epic Level)

- Setup scripts are classified by safety and currentness
- Local installed packages are inventoried or blocked with reason
- Package manifests are classified by purpose
- Ambiguous packages are queued for targeted questions to Aaron
- Minimum viable bootstrap is defined
- Dry-run or checkpoint behavior is specified
- Future bootstrap architecture decision is documented

---

## Dependencies

Per-story blockers live on the linked GitHub issues. Cross-cutting dependencies: see [prd.md](./prd.md) §17. Key gate: Phase 1 safety inventory must complete before modernizing.

---

## Risks

### Risk: Bootstrap script mutates the live machine during testing

**Likelihood:** Medium
**Impact:** High
**Mitigation:** Treat setup scripts as inspect-only until dry-run/checkpoint behavior exists.

### Risk: Package list modernization becomes a full distro migration

**Likelihood:** Medium
**Impact:** Medium
**Mitigation:** Confirm target OS before refactoring manifests deeply.

### Risk: Package triage becomes too noisy

**Likelihood:** Medium
**Impact:** Medium
**Mitigation:** Ask questions by package group first, then only ask about individual packages when the group is ambiguous.

### Risk: Minimum bootstrap becomes too large

**Likelihood:** High
**Impact:** Medium
**Mitigation:** Separate core productivity from desktop customization and optional apps.

---

## Done When

This epic is complete when the repo has a safe, documented path from fresh machine to useful workstation, even if full automation remains deferred.
