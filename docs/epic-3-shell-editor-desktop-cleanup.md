# Epic 3: Shell, Editor, and Desktop Cleanup

**Priority:** High
**Status:** Draft
**Phase:** Phase 3 — shell, editor, tooling, and desktop cleanup
**PRD Reference:** [prd.md](./prd.md)
**FR Alignment:** FR-1 (Repo and Live-Home Inventory), FR-4 (Product Documentation), FR-5 (Safe Commit and Sync Workflow)
**Outcome Type:** Maintainability + daily workflow quality

---

## Objective

Make the active shell, editor, tool, and desktop configuration understandable, current, and safe to change while preserving useful legacy context.

## Context

Shell (`.zshrc`, `.bashrc`, `.profile`, `.zprofile`), editor (`.spacemacs`, `.vimrc`, `.config/nvim/`, `.config/Code/`), desktop (`.config/{i3,polybar,rofi,dunst}/`, `.Xresources`, `.xinitrc`, `.screenlayout/`), and helper scripts (`.local/bin/tools/`) shape the daily workstation and carry the highest breakage risk. This epic distinguishes active behavior from historical config — reducing `.zshrc` duplication, fixing stale PATH/env, and classifying editor/desktop/helper surfaces — without erasing old knowledge prematurely. Background: [prd.md](./prd.md) §2–3. Depends on the Phase 1 live-home comparison before editing high-impact configs.

---

## Scope

### In Scope

- Compare shell/editor/desktop files against `$HOME`
- Reduce duplication in `.zshrc`
- Separate portable shell config from local/secret config
- Review editor configs and classify active versus legacy
- Review desktop configs and classify active versus legacy
- Inventory helper scripts under `.local/bin/tools/`
- Create documentation for supported daily workflows

### Out of Scope

- Switching shells, editors, or desktop environments without a separate decision
- Deleting uncertain configs without live-home and usage review
- Running desktop session restart commands
- Installing editor plugins or desktop packages automatically
- Publishing private machine details

---

## Stories

### Story 3.1: Clean and structure shell config

As the repo owner,
I want shell config to be readable and intentional,
So that startup behavior and aliases are easy to maintain.

Issue: [#28](https://github.com/amasover/dotfiles/issues/28)

**Acceptance criteria:**

- Given `.zshrc` differs from `$HOME/.zshrc`, when cleanup is proposed, then the live difference is reviewed first
- Given duplicated aliases or functions exist, when cleanup is performed, then duplicate definitions are removed or consolidated
- Given environment variables are secret or machine-local, when shell config is updated, then they are moved to encrypted/local handling rather than plaintext shared config
- Given PATH entries are stale, when updated, then the rationale is documented or the entry is removed

**Evidence artifact:** `.zshrc` diff, shell validation notes

---

### Story 3.2: Classify editor configs

As the repo owner,
I want editor configs marked current or legacy,
So that active editors are supported and old configs do not cause confusion.

Issue: [#29](https://github.com/amasover/dotfiles/issues/29)

**Acceptance criteria:**

- Given `.spacemacs`, `.vimrc`, `.config/nvim/`, and `.config/Code/` exist, when reviewed, then each is classified as current, legacy-supported, archive-candidate, or unknown
- Given an editor config references plugins or tools, when classified, then outdated or missing dependencies are noted
- Given multiple editor configs remain, when docs are updated, then the primary editor path is named

**Evidence artifact:** Editor config inventory

---

### Story 3.3: Classify desktop configs

As the repo owner,
I want desktop environment config classified by currentness,
So that old i3/polybar/rofi assets are preserved or cleaned up intentionally.

Issue: [#30](https://github.com/amasover/dotfiles/issues/30)

**Acceptance criteria:**

- Given desktop config files exist, when reviewed, then each major surface is classified as current, legacy-supported, archive-candidate, or unknown
- Given monitor or machine-specific layout config exists, when retained, then it is documented as machine-specific
- Given screenshots or themes exist, when retained, then they support documentation, active usage, or historical context

**Evidence artifact:** Desktop config inventory

---

### Story 3.4: Inventory helper scripts

As the repo owner,
I want personal helper scripts categorized,
So that useful tools are discoverable and risky scripts are labeled.

Issue: [#31](https://github.com/amasover/dotfiles/issues/31)

**Acceptance criteria:**

- Given scripts exist under `.local/bin/tools/`, when reviewed, then each is categorized by purpose and safety level
- Given a script touches credentials, SSH, cloud accounts, packages, or system services, when documented, then it is marked high-risk
- Given a script is obsolete, when cleanup is proposed, then it is archived or deleted with rationale

**Evidence artifact:** [bootstrap-inventory.md](./bootstrap-inventory.md) (§ Story 3.4 — tool triage executed)

---

### Story 3.5: Document daily workflows

As future Aaron,
I want the repo to document supported daily workflows,
So that important aliases and scripts are not just tribal memory.

Issue: [#32](https://github.com/amasover/dotfiles/issues/32)

**Acceptance criteria:**

- Given shell aliases or helper scripts are retained, when docs are updated, then the highest-value workflows are documented
- Given a workflow depends on secrets or local-only files, when documented, then secret values are not exposed
- Given a workflow is legacy, when documented, then it is labeled legacy rather than current

**Evidence artifact:** Workflow docs under `docs/` or README refresh

---

### Story 3.6: Triage stale test-laptop drift for salvage

**Issue:** [#10](https://github.com/amasover/dotfiles/issues/10)

As the repo owner,
I want the archived test-laptop drift triaged file-by-file,
So that intentional changes are salvaged and genuinely stale config is dropped without guessing.

**Acceptance criteria:**

- Given local `main` was undiverged from the test-laptop lineage, when triage runs, then the stale lineage is preserved (`archive/stale-test-laptop-main` + tag) and each differing file is classified salvage/drop/decision
- Given a diff cannot distinguish stale from deliberate, when a removal is classified drop, then it is confirmed with Aaron before acting
- Given a salvage item contains a secret (e.g. an API key), when salvaged, then it is encrypted via `.config/yadm/encrypt`, never tracked as plaintext

**Evidence artifact:** [Stale drift triage (2026-06-23)](./stale-drift-triage-2026-06-23.md)

---

### Story 3.7: Fix xidlehook not starting on boot

**Issue:** [#14](https://github.com/amasover/dotfiles/issues/14)

As the repo owner,
I want xidlehook to start automatically at boot,
So that idle-lock / screen-off works without starting it by hand.

**Acceptance criteria:**

- Given the machine boots, when the desktop session starts, then xidlehook starts automatically (i3 `exec`, systemd `--user` service, or `.xprofile`)
- Given xidlehook replaces the old bespoke lock/DPMS logic, when configured, then its behavior is documented and the retired logic is confirmed gone

**Evidence artifact:** xidlehook autostart config + notes

---

### Story 3.8: Support switching from zsh to fish

As the repo owner,
I want the option to migrate my interactive shell from zsh to fish,
So that I can move to fish in the future without an all-or-nothing rewrite.

Issue: [#37](https://github.com/amasover/dotfiles/issues/37)

**Acceptance criteria:**

- Given the current zsh setup (oh-my-zsh, `.zsh_plugins.sh`, vi-mode, plugins), when migration is scoped, then portable vs zsh-specific config is identified
- Given fish is chosen, when a migration path is defined, then it does not break the working zsh setup until cutover (parallel config is acceptable)
- Given bootstrap installs the shell (Story 2.3), when fish is supported, then shell choice is reflected there and in Story 3.1 cleanup

**Evidence artifact:** Shell migration notes or parallel fish config under `docs/`

---

### Story 3.9: Reconcile iwd vs wpa_supplicant NetworkManager backend

As the repo owner,
I want exactly one Wi-Fi backend enabled and the choice documented,
So that NetworkManager isn't running a redundant `iwd.service` it doesn't use.

Issue: [#41](https://github.com/amasover/dotfiles/issues/41)

Found during Story 2.2 inventory: NM is provided by `networkmanager-iwd` but its
backend is set to `wpa_supplicant` (`/etc/NetworkManager/conf.d/wifi_backend.conf`),
while `iwd.service` is still enabled + active and unused. Likely an iwd→wpa_supplicant
switch (corp Wi-Fi) that left iwd enabled. See [package-inventory.md](./package-inventory.md) § Networking (N1).

**Acceptance criteria:**

- Given the active backend is confirmed, when reconciled, then only one Wi-Fi backend is enabled (disable `iwd.service`, or switch NM to iwd) — not both
- Given the choice is made, when documented, then the resulting package set (`networkmanager-iwd` vs `networkmanager` + `wpa_supplicant`) is fed back into the Story 2.2 network-vpn group

**Evidence artifact:** Service/config reconciliation notes + manifest update

---

### Story 3.10: Consolidate screen recorders (evaluate kooha)

As the repo owner,
I want one or two screen-capture tools instead of five,
So that screen recording is reliable and not a pile of overlapping legacy apps.

Issue: [#42](https://github.com/amasover/dotfiles/issues/42)

Deferred from Story 2.2: `peek` + `byzanz` + `kazam` + `simplescreenrecorder` + `guvcview`
all installed. Aaron wants to evaluate **kooha**. Recording libs reportedly broken until a
reboot — verify post-reboot first. See [package-inventory.md](./package-inventory.md) (D7).

**Acceptance criteria:**

- Given the recorders are evaluated (incl. kooha) after the pending reboot, when one/two keepers are chosen, then the rest are marked remove-candidates and fed into the Story 2.2 media group
- Given Wayland/X11 + PipeWire, when the keeper is chosen, then capture is confirmed working

**Evidence artifact:** Screen-recorder decision notes + manifest update

---

### Story 3.11: Restore cbeams as a custom optional toy

As the repo owner,
I want cbeams working again without the dead AUR package,
So that the terminal toy survives the package cleanup instead of silently disappearing.

Issue: [#52](https://github.com/amasover/dotfiles/issues/52)

Origin: Story 2.8 adoption — `python-cbeams-git` (AUR, python2-era, last touched 2021) was
uninstalled per inventory decision D9. Aaron wants the functionality back via a custom
install (e.g. `pipx` from upstream git, a python3-compatible fork, or a vendored script)
rather than the stale AUR build.

**Acceptance criteria:**

- Given the AUR package is gone, when an install method is chosen (pipx / git fork / vendored), then cbeams runs on python3 on the live machine
- Given the install is custom (not pacman), when it lands, then the method is captured in bootstrap docs or an optional setup script — not in metapac groups
- Given metapac owns pacman state, when this lands, then `metapac unmanaged` stays exactly empty

**Evidence artifact:** Working cbeams + documented install method.

---

### Story 3.12: Replace 2019 Go audio tools (dot, volume-go) with wpctl

As the repo owner,
I want the volume keys and the polybar output switcher talking to PipeWire directly,
So that the audio stack stops depending on unmaintained 2019 Go binaries that no bootstrap can rebuild.

Issue: [#59](https://github.com/amasover/dotfiles/issues/59)

Origin: Story 3.4 follow-ups, sharpened by the 2026-07-03 old-install audit. Live consumers
of the two 2019 binaries in `~/code/go/bin/`:

- `tools/polybar_alsa_module` (the `alsa-switch` module of the **active** nord-arrow theme)
  polls `dot sound port` every 0.5s — the read works, but the click-to-switch path uses
  `pacmd` (PulseAudio), gone under PipeWire, so switching is likely already broken.
- The i3 `XF86AudioRaise/LowerVolume` bindings run `volume up/down 3` +
  `volnoti-show $(volume get)` ([config:353](../.config/i3/config#L353)) — volume-go.
  Mute already migrated to `wpctl` in Story 3.4.
- Neither binary is rebuildable in practice: `go get -u` stopped installing binaries in
  Go 1.18, and `patrick-motard/dot` last saw a push in December 2019.

**Acceptance criteria:**

- Given the polybar switcher, when rewritten against `wpctl`/`pamixer`, then the current-output icon and click-to-switch both work on the live machine and no `dot`/`pacmd` calls remain
- Given the i3 volume keys, when rebound to `wpctl` (or `pamixer`), then volume up/down and the volnoti OSD still work
- Given no consumers remain (grep repo + live `$HOME`), when the story lands, then `tools/dot-update` is deleted, the duplicate `dot-src` aliases go (with or ahead of the 3.1 dedupe), and the 2019 binaries are retired from `~/code/go/bin/`
- Given `pulseaudio-tail.sh` already speaks PipeWire, when the audio modules are touched, then it is renamed to match (folds in the cosmetic 3.4 follow-up)
- Given Story 2.13 excludes audio Go tools from the bootstrap, when this lands, then a fresh machine needs no Go audio artifacts at all — the last old-install audio gap closes

**Evidence artifact:** Working volume keys + output switcher on the live machine; updated follow-ups in the bootstrap inventory.

---

## Acceptance Criteria (Epic Level)

- Shell config has been compared to live-home and cleaned safely
- Editor configs are classified
- Desktop configs are classified
- Helper scripts are inventoried
- Daily workflows are documented without exposing secrets

---

## Dependencies

Per-story blockers live on the linked GitHub issues. Cross-cutting dependencies: see [prd.md](./prd.md) §17. Key gate: Phase 1 live-home inventory before editing high-impact configs.

---

## Risks

### Risk: Shell cleanup breaks interactive use

**Likelihood:** Medium
**Impact:** High
**Mitigation:** Use small diffs, syntax checks, and live-home comparison.

### Risk: Legacy desktop config is deleted too early

**Likelihood:** Medium
**Impact:** Medium
**Mitigation:** Classify and archive before deletion unless dead usage is proven.

### Risk: Helper scripts leak sensitive workflow details

**Likelihood:** Medium
**Impact:** High
**Mitigation:** Secret-scan script content and avoid publishing private values.

---

## Done When

This epic is complete when the repo clearly explains which shell, editor, desktop, and tool surfaces are active, which are legacy, and how to change them safely.
