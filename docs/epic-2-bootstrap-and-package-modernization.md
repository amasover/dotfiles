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

### Story 2.3: Define minimum viable bootstrap

As future Aaron on a new machine,
I want a minimal setup path,
So that I can become productive before restoring every desktop customization.

Design input: [bootstrap-architecture-notes.md](./bootstrap-architecture-notes.md) — Bash vs Ansible vs Go, idempotency, "not NixOS."

Issue: [#25](https://github.com/amasover/dotfiles/issues/25)

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

### Story 2.7: QEMU fresh-install validation harness

As the repo owner,
I want a repeatable QEMU/KVM harness that fresh-installs Arch and runs the bootstrap,
So that bootstrap and manifest changes are validated in a disposable VM before they are trusted on metal.

Issue: [#46](https://github.com/amasover/dotfiles/issues/46) · Design input: [decision-bootstrap-architecture.md](./decision-bootstrap-architecture.md) (validation strategy). `qemu-desktop` + `virt-manager` are already installed (Story 2.2 decision D6).

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

### Story 2.10: AUR install-time gating + portable trust baseline

As the repo owner,
I want fresh AUR installs gated like upgrades and the trust baseline portable across machines,
So that a fresh-machine bootstrap doesn't install freshly-weaponized AUR packages ungated.

Issue: [#50](https://github.com/amasover/dotfiles/issues/50) · Prerequisite for the first real-metal `bootstrap` run (Story 2.3); disposable 2.7 VM runs are exempt. Promotes the un-ticketed Story 2.6 follow-up (`AURPostDownload` gating); origin: 2026-07-02 grill of the 2.5 decision. Design input: [aur-malware-mitigation.md](../knowledge/reference/aur-malware-mitigation.md).

**Acceptance criteria:**

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
