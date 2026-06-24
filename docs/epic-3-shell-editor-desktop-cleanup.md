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
