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

### Story 3.2: Classify editor configs ✅

As the repo owner,
I want editor and agentic-coding surfaces assigned explicit roles and dispositions,
So that active tools are supported without treating every installed editor as a competing default.

Issue: [#29](https://github.com/amasover/dotfiles/issues/29) (closed)

The singular “primary editor” model was rejected. Vim is the terminal editor;
Spacemacs is the workspace editor; OMP is the agentic coding environment; VS Code is a
secondary IDE; Neovim is a Vim compatibility frontend. IntelliJ is an archive/remove
candidate. Full findings and follow-up ownership live in the inventory.

**Acceptance criteria:**

- Given `.spacemacs`, `.vimrc`, `.config/nvim/`, `.config/Code/`, and OMP exist, each is classified with a durable role and source of truth
- Given editor config references plugins, packages, checkouts, or external tools, missing and non-reproducible dependencies are named with an owning follow-up
- Given several current coding surfaces remain, terminal editor, workspace editor, secondary IDE, compatibility frontend, and agentic coding environment are distinguished instead of naming one false primary
- Given an archive/remove candidate is found, classification records it without performing an unapproved live-file or package mutation

**Evidence artifact:** [Editor configuration inventory](./editor-config-inventory.md)

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

Known archive candidates (add as found):

- `.config/polybar/config.bak2` (Aug 2019): pre-themes-dir polybar config, two
  generations superseded — it references bitmap-era fonts (Fixed/unifont/Siji)
  and its entry-point role died with the 5.5 `-c` launcher (#152). Archive or
  delete. (Spotted during the 2026-08-22 review of PR #167.)
- `.fonts/siji.pcf` + `.fonts/fonts.dir` (2019): tracked font blobs — siji is
  already declared as the `siji-git` package in desktop.toml, and `fonts.dir`
  is a stale X font index. The other two `.fonts` blobs were retired by the
  2.48 PR once their vendored packages landed; these two follow the same
  question. (Spotted 2026-08-22 during 2.48.)

**Evidence artifact:** Desktop config inventory

---

### Story 3.4: Inventory helper scripts ✅

As the repo owner,
I want personal helper scripts categorized,
So that useful tools are discoverable and risky scripts are labeled.

Issue: [#31](https://github.com/amasover/dotfiles/issues/31) (closed, PR [#38](https://github.com/amasover/dotfiles/pull/38))

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

### Story 3.6: Triage stale test-laptop drift for salvage ✅

**Issue:** [#10](https://github.com/amasover/dotfiles/issues/10) (closed, PR [#11](https://github.com/amasover/dotfiles/pull/11))

As the repo owner,
I want the archived test-laptop drift triaged file-by-file,
So that intentional changes are salvaged and genuinely stale config is dropped without guessing.

**Acceptance criteria:**

- Given local `main` was undiverged from the test-laptop lineage, when triage runs, then the stale lineage is preserved (`archive/stale-test-laptop-main` + tag) and each differing file is classified salvage/drop/decision
- Given a diff cannot distinguish stale from deliberate, when a removal is classified drop, then it is confirmed with Aaron before acting
- Given a salvage item contains a secret (e.g. an API key), when salvaged, then it is encrypted via `.config/yadm/encrypt`, never tracked as plaintext

**Evidence artifact:** [Stale drift triage (2026-06-23)](./stale-drift-triage-2026-06-23.md)

---

### Story 3.7: Fix xidlehook not starting on boot ✅

**Issue:** [#14](https://github.com/amasover/dotfiles/issues/14) (closed, PR [#221](https://github.com/amasover/dotfiles/pull/221))

As the repo owner,
I want xidlehook to start automatically at boot,
So that idle-lock / screen-off works without starting it by hand.

Decision (2026-08-29): i3 owns one `xidlehook` process through an
`exec_always` launcher guarded by a runtime `flock`, so initial startup and i3
restarts are covered without duplicates. X blanks at 3 minutes; xidlehook locks
at 5, explicitly powers the panel off at 15, hibernates a discharging laptop at
30, and hibernates any still-idle laptop at 90. Fullscreen postpones the chain;
background audio does not. Renewed activity resets it.

`systemd-lock-handler` continues to translate logind events into `lock.target`;
a tracked `locker.service` now routes that target through the same portable
pixelated-screen helper. The old xautolock declaration, inline shell pipeline,
hardcoded home paths, fixed screenshot filename, and commented bespoke DPMS
implementation are retired.

**Acceptance criteria:**

- Given initial i3 startup or an in-place restart, exactly one `xidlehook` process runs with the documented timer chain
- Given i3 reloads repeatedly, the runtime lock prevents duplicate processes
- Given 3/5/15-minute X and xidlehook policy, blanking, authentication lock, and explicit DPMS power-off each occur at their boundary
- Given logind starts `lock.target`, tracked `locker.service` locks through the same helper and transitions to `unlock.target` after authentication
- Given battery fixtures and command stubs, 30/90-minute hibernation selection is deterministic and no fixture can reach real `systemctl hibernate`

**Evidence artifact:** `tests/idle-lock.clitest.txt` (32/32); clean shellcheck,
shfmt, syntax, and systemd-unit checks; accelerated live blank/lock/DPMS tests;
one-process i3 restart/reload probes; live `lock.target`/`unlock.target` round trip.
The existing manual hibernate path remains, but a live hibernate attempt during
validation was not counted: current swap occupancy left insufficient image
headroom and the kernel returned `ENOSPC` before thawing the session.

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

### Story 3.9: Reconcile iwd vs wpa_supplicant NetworkManager backend ✅

As the repo owner,
I want exactly one Wi-Fi backend enabled and the choice documented,
So that NetworkManager isn't running a redundant `iwd.service` it doesn't use.

Issue: [#41](https://github.com/amasover/dotfiles/issues/41) (closed; live cutover commit `bddec52`)

Story 2.2 found `networkmanager-iwd` installed while NetworkManager explicitly selected
`wpa_supplicant` and a redundant `iwd.service` also ran. The live cutover chose the
official-repo `networkmanager`; its required `wpa_supplicant` dependency is the sole backend.

**Acceptance criteria:**

- Given the active backend is confirmed, when reconciled, then only one Wi-Fi backend is enabled — not both
- Given the choice is made, when documented, then `networkmanager` is explicit in the Story 2.2 `network-vpn` group and `wpa_supplicant` remains its package dependency

**Evidence artifact:** Commit `bddec52` removed `networkmanager-iwd`/`iwgtk`; live verification
on 2026-08-27 found NetworkManager enabled and connected through `wpa_supplicant`, with the
`iwd` package, unit, and process absent. The manifest declares `networkmanager`.


---

### Story 3.10: Consolidate screen recorders (evaluate kooha) ✅

As the repo owner,
I want one or two screen-capture tools instead of five,
So that screen recording is reliable and not a pile of overlapping legacy apps.

Issue: [#42](https://github.com/amasover/dotfiles/issues/42) (closed, PR #125)

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

### Story 3.12: Replace 2019 Go audio tools (dot, volume-go) with wpctl ✅

As the repo owner,
I want the volume keys and the polybar output switcher talking to PipeWire directly,
So that the audio stack stops depending on unmaintained 2019 Go binaries that no bootstrap can rebuild.

Issue: [#59](https://github.com/amasover/dotfiles/issues/59) (closed, PR [#168](https://github.com/amasover/dotfiles/pull/168))

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
- Given the i3 volume keys, when rebound to `wpctl` (or `pamixer`), then volume up/down still work. (The volnoti OSD half was found already dead everywhere during the 2026-08-22 review — volnoti is installed on no machine, declared in no metapac group, and no daemon was ever started; `volume-osd` keeps the `volnoti-show` hook as opt-in, and reviving it is out of this story's scope.)
- Given no consumers remain (grep repo + live `$HOME`), when the story lands, then `tools/dot-update` is deleted, the duplicate `dot-src` aliases go (with or ahead of the 3.1 dedupe), and the 2019 binaries are retired from `~/code/go/bin/`
- Given `pulseaudio-tail.sh` already speaks PipeWire, when the audio modules are touched, then it is renamed to match (folds in the cosmetic 3.4 follow-up)
- Given Story 2.13 excludes audio Go tools from the bootstrap, when this lands, then a fresh machine needs no Go audio artifacts at all — the last old-install audio gap closes

**Evidence artifact:** Working volume keys + output switcher on the live machine; updated follow-ups in the bootstrap inventory.

---

### Story 3.13: Adopt atuin shell history (self-hosted sync)

As the repo owner,
I want atuin managing zsh history, syncing to a self-hosted server,
So that shell history is searchable across machines and survives reinstalls without depending on a third-party service.

Issue: [#67](https://github.com/amasover/dotfiles/issues/67)

Aaron's ask (2026-07-04). `atuin` is in the official repos (`extra/atuin`), so install is a
one-line add to the `shell-cli` metapac group; zsh integration is an `atuin init zsh` hook in
`.zshrc`. **Partially blocked:** the sync half needs the atuin server running on the homelab
server first (outside this repo); the local half (install, hook, tracked config) can proceed
independently. Secret-safety: the client key (`~/.local/share/atuin/key`) and session are
credentials — never tracked as plaintext — and the sync-server address is a private hostname,
so decide how `~/.config/atuin/config.toml` is handled (encrypt manifest / local file /
template) before tracking it.

**Acceptance criteria:**

- Given `atuin` is declared in the `shell-cli` group and the zsh hook lands in `.zshrc`, when a new shell starts, then ctrl-r search works on the live machine and `metapac unmanaged` stays exactly empty
- Given atuin config is handled (tracked, templated, or local), when it lands, then no key/session material and no private sync address reach the repo as plaintext
- Given the homelab atuin server exists (blocker), when sync is configured, then `atuin sync` round-trips history between the workstation and the server
- Given a fresh machine runs bootstrap, when atuin lands via metapac, then the manual login/key-import step is documented in the [fresh-machine runbook](./runbook-fresh-machine-bootstrap.md)

**Evidence artifact:** Working ctrl-r + sync on the live machine; runbook note for the login step.

---

### Story 3.14: Evaluate Atuin Desktop (runbook app)

As the repo owner,
I want Atuin Desktop installed and exercised against a real runbook,
So that I can judge whether executable runbooks earn a place in the daily workflow.

Issue: [#68](https://github.com/amasover/dotfiles/issues/68)

Aaron's ask (2026-07-04). Atuin Desktop is the executable-runbook app from the atuin
developers — separate from the Story 3.13 history CLI; neither requires the other. Verify the
install method at pickup (AUR preferred so metapac owns it; upstream shipped it as a beta with
its own installer). This repo has real runbooks to test against, e.g.
[runbook-vm-validation.md](./runbook-vm-validation.md) and
[runbook-fresh-machine-bootstrap.md](./runbook-fresh-machine-bootstrap.md). The evaluation may
prove work-shaped — in that case the story transfers to the work/internal tracker and the
issue closes with a pointer note; no internal details land in this repo either way.

**Acceptance criteria:**

- Given an install method is chosen (AUR if one exists, else upstream installer), when installed, then the method is captured (metapac group if pacman/AUR owns it; machine-local or a docs note otherwise) and `metapac unmanaged` stays exactly empty
- Given one of this repo's runbooks, when ported into and exercised in Atuin Desktop, then a keep/drop verdict is recorded on the issue
- Given the verdict is "work tool", when transferred to the internal tracker, then the issue closes with a pointer note and nothing internal is committed here

**Evidence artifact:** Keep/drop verdict + install-method note on the issue.

---

### Story 3.15: Encrypt-manifest leftovers from 3.6

As the repo owner,
I want the parked encrypt-list decisions closed out,
So that the encryption manifest matches reality and the one keyed file is either protected or deliberately dropped.

Issue: [#77](https://github.com/amasover/dotfiles/issues/77) · Leftovers from Story 3.6 triage plus one 1.8 candidate, previously parked in STATUS.

**Acceptance criteria:**

- Given `.config/yadm/encrypt`, stale patterns are removed or re-justified
- Given `settings.json` (contains a key), it is adopted through the YADM encrypt path or deliberately dropped — recorded either way
- Given the gitignored `docs/private/` redaction note, its promotion to YADM-encrypted storage is decided and recorded (yes or no)

**Evidence artifact:** the encrypt-manifest diff + decision notes on the issue.

---

### Story 3.16: Restore hardware GL acceleration (Intel Iris Xe) ✅

As the repo owner,
I want the desktop to actually use the GPU,
So that GL apps, video, and screen recording work instead of silently falling back to software rendering.

Issue: [#126](https://github.com/amasover/dotfiles/issues/126) (closed, PR #127)

Found while evaluating recorders for Story 3.10 — the whole session was running on llvmpipe,
which is why every recorder looked broken. Two independent causes, applied and validated one at
a time: (1) `MESA_LOADER_DRIVER_OVERRIDE=i965` in `.profile` names a driver mesa deleted years
ago, so mesa can't load it and falls back to software; (2) legacy `xf86-video-intel` is installed
and Xorg auto-selects it over `modesetting`, then logs `Unknown chipset` and disables
acceleration. Diagnosis: [knowledge/errors/mesa-i965-override-forces-llvmpipe.md](../knowledge/errors/mesa-i965-override-forces-llvmpipe.md).

**Acceptance criteria:**

- Given the `.profile` export is removed, when a fresh login shell starts X, then `glxinfo -B` reports the Iris Xe with `Accelerated: yes` and `Xorg.0.log` has no `AIGLX ... i965` errors
- Given `xf86-video-intel` is removed, when X restarts, then `Xorg.0.log` shows `modesetting` in use with no "disabling acceleration" line
- Given both land, when `gsr-ui` runs, then it starts and records — closing out the live-capture half of Story 3.10

**Evidence artifact:** before/after `glxinfo -B` + `Xorg.0.log` excerpts on the issue.

---

### Story 3.17: Migrate monitor names after the modesetting driver switch

As the repo owner,
I want the desktop's monitor-layout configs to use the `modesetting` driver's
dashed output names,
So that autorandr auto-switching and the polybar multi-monitor layouts work
again after the 3.16 driver change.

Issue: [#129](https://github.com/amasover/dotfiles/issues/129) · Origin: fallout from
Story 3.16 (#126, PR #127), found during post-reboot verification. Not a regression to
reverse — the driver switch was correct; the rename has to be followed through.

Xorg outputs renamed `eDP1`/`HDMI1`/`DP1`/`DP1-1`/`DP1-2`/`VIRTUAL1` →
`eDP-1`/`HDMI-1`/`DP-1`/`DP-2`. Broken by the rename: all six autorandr profiles
(their EDID fingerprints are keyed by output name, so `autorandr --detected` matches
nothing and dock/undock auto-switching is dead) and `.config/polybar/launch.sh`'s
hardcoded layout table. Incidentally fixed by it: `~/.screenlayout/*.sh` already used
dashed names. Unaffected: i3's monitor block (commented out, already dashed).

**Acceptance criteria:**

- Given each autorandr profile, when the corresponding monitors are attached, then the profile is re-saved under `modesetting` naming and `autorandr --detected` matches it
- Given `.config/polybar/launch.sh`, when the layout table is updated to dashed output names, then each layout selects the intended bars
- Given a profile cannot be re-created (hardware no longer available), then it is deleted or marked stale rather than left silently non-matching
- Given the migration lands, when docs are updated, then the naming dependency is recorded so a future driver change does not silently break the same configs again

Re-saving autorandr profiles needs the physical monitors, so this is attended
work done per docking setup, not a single repo edit.

The historical 4K split-monitor setup (virtual-monitor geometry, the
per-profile autorandr hooks, i3 workspace placement, and rebuild guidance) is
preserved in
[knowledge/reference/4k-split-monitor-layout.md](../knowledge/reference/4k-split-monitor-layout.md)
— captured 2026-08-22 when the pre-5.5 global postswitch was archived off the
laptop (raw hook contents also on [#129](https://github.com/amasover/dotfiles/issues/129)).

**Evidence artifact:** `autorandr --detected` matching on each re-saved setup +
the updated `launch.sh` layout table.

---

### Story 3.18: Arc GTK theme is release-less upstream and unbuildable — repackage, replace, or drop

As the repo owner,
I want a deliberate decision about the desktop's GTK theme now that Arc cannot
be installed on fresh machines,
So that the daily-driver rebuild comes up with the intended look instead of
silently losing the configured theme.

Issue: [#137](https://github.com/amasover/dotfiles/issues/137) · Origin: the
Story 2.38 (#124) validation run, 2026-08-16 — `arc-gtk-theme` burned sync
attempts 2–10 (upstream git is alive — pushed 2025-10, gnome-shell dirs through
45 — but has tagged no release since Dec 2022; the 20221218 tarball's gnome-shell
meson rules reference directories the tarball lacks, and meson 1.12
hard-errors where the old meson warned; AUR recipe untouched since 2024;
chaotic doesn't carry it). `arc-solid-gtk-theme` is a split package of the
same pkgbase — it exists on the AUR but fails with the same build (an earlier
note wrongly called it deleted; corrected 2026-08-19). The pkgbase has been
flagged out-of-date since 2025-11 with no response. Both are
known-broken-deferred, so runs survive — but the live
desktop runs Arc-Dark (`.gtkrc-2.0` + `gtk-3.0/settings.ini`), and a fresh
machine now gets no theme. Same shape as Story 3.10's recorder consolidation.

**Acceptance criteria:**

- Given the candidates (maintained successor theme, vendored built theme files per 3.11's scripts-not-PKGBUILDs precedent, a different theme, or deliberate theme-less fresh installs), then one is chosen and recorded
- Given the choice, then the declarations match it — `arc-solid-gtk-theme` lives or dies with the same decision (it builds from the same pkgbase), the known-broken entries are retired to match, and the GTK configs are updated if the theme changes
- Given a fresh-machine path (harness guest is fine), then it converges with the intended theme state

**Evidence artifact:** the recorded decision + a run/guest showing the
intended theme state.

### Story 3.19: Firefox is the default browser ✅

As the repo owner,
I want Firefox declared as the default browser in tracked config,
So that `xdg-open` and link-clicking apps open the browser I chose instead of whichever one sorts first.

Issue: [#158](https://github.com/amasover/dotfiles/issues/158) (closed, PR #159)

**Current state (2026-08-22, VMware guest):** no `mimeapps.list` exists in any
xdg location and no tracked shell config sets `BROWSER`, so
`xdg-settings get default-web-browser` answers `chromium.desktop` — purely the
alphabetical `mimeinfo.cache` fallback, not a choice anyone made.

**Acceptance criteria:**

- A tracked `.config/mimeapps.list` maps the browser mime types and URL
  schemes (`text/html`, `xhtml+xml`, `http`, `https`, `about`, `unknown`) to
  `firefox.desktop`.
- `BROWSER=firefox` is exported from `.profile` for the CLI tools that check
  the variable before xdg (`gh auth login --web` among them).
- Verified live: `xdg-settings get default-web-browser` answers
  `firefox.desktop`.
- Firefox itself stays declared via `browsers.toml` (already true).

---

### Story 3.20: Decide the fate of the `dot` CLI (patrick-motard/dot)

As the repo owner,
I want the remaining `dot` subcommand consumers inventoried and replaced or retired,
So that daily workflows stop depending on a 2019 tool that exists only on the old laptop and that no bootstrap installs.

Origin: 2026-08-22, Story 5.5 review. The i3 theme-picker binding ran
`dot polybar --select`, but `dot` ([patrick-motard/dot](https://github.com/patrick-motard/dot),
last pushed December 2019) is installed only on the old laptop — on the guest
the binding was dead. The 5.5 fixes rebound `$mod+Shift+c` to the tracked
`polybar-theme-selector.sh` directly; the audio consumers (`dot sound port`)
are already [Story 3.12](#story-312-replace-2019-go-audio-tools-dot-volume-go-with-wpctl)'s
scope.

**Acceptance criteria:**

- Given the repo and the laptop's live `$HOME`, when `dot` usage is
  inventoried (configs, scripts, i3/polybar modules, shell history if handy),
  then every remaining consumer is listed with its subcommand and a
  replace/retire decision.
- Given consumers already replaced elsewhere (theme picker in 5.5, audio in
  3.12), when the last consumer is gone, then `dot` is retired from the laptop
  and any `dot`-related aliases or scripts leave the repo.
- Given a duty worth keeping that no existing story covers, then it gets a
  tracked, bootstrap-installable replacement — no new framework without a
  documented decision.

**Evidence artifact:** the consumer inventory + the recorded decision per consumer.

---

### Story 3.21: Per-theme bar manifests — revive nord under the 5.5 launcher ✅

As the repo owner,
I want the polybar launcher to learn each theme's own bar list, role gating, and gap needs,
So that the nord island theme is selectable again and future themes aren't chained to the `bar/main` contract.

Issue: [#173](https://github.com/amasover/dotfiles/issues/173) (closed, PR [#176](https://github.com/amasover/dotfiles/pull/176))

Origin: 2026-08-22 live preview during the #167/#168 convergence session. `launch.sh`
and `polybar-theme-selector.sh` hardcode `bar/main`/`bar/main-bottom` (plus role-gated
left/extra/split bars), so nord — which defines island bars
(`bar/main-top-left/middle/right`) — can't be launched or picked. The preview also
confirmed the islands are `override-redirect` windows that i3 neither reserves room for
nor restacks: without a top gap they sit behind/over windows, which is what the old
static `gaps top 10` (now commented out) was for. nord's `right-top-middle` bar also
references `${env:MONITOR_RIGHT}`, which is not a 5.5 role.

**Acceptance criteria:**

- Given a theme directory with a manifest (bar names, optional role gate per bar, optional `gap-top`), when `launch.sh` runs, then exactly the manifest's bars launch (role-gated ones only when their role resolved) and `i3-msg` applies the theme's top gap (default 0)
- Given a theme without a manifest, when `launch.sh` runs, then today's `bar/main` contract behaves unchanged (fallback, no regression for nord-arrow)
- Given the selector, when it lists themes, then manifest-bearing themes are offered alongside `bar/main` themes, and picking nord launches its islands with the gap applied
- Given nord's `right-top-middle`, when the manifest lands, then it is gated on the EXTRA role instead of the dead `MONITOR_RIGHT`
- Given the manifest parsing, then it lives in a pure `tools/` seam with clitest coverage (no polybar, no i3)

**Evidence artifact:** live toggle nord ↔ nord-arrow via the selector, both directions,
with the gap following the theme.

---

### Story 3.22: nord-arrow-slim — SCP-arrow variant of nord-arrow, DRY ✅

As the repo owner,
I want a third selectable theme that is nord-arrow with the slim Source Code Pro
for Powerline arrows (the post-#167 look),
So that I can toggle between the big-arrow and slim-arrow renderings instead of
choosing one forever.

Issue: [#174](https://github.com/amasover/dotfiles/issues/174) (closed, PR #177)

Origin: the 2026-08-22 font-restore decision (PR #171) — both looks turned out to be
wanted. Constraint from the same session: polybar's include-file merging makes any
duplicate key a fatal parse error, so variants must share via `inherit` (which has
per-key override semantics), not by re-including overlapping sections.

**Acceptance criteria:**

- Given the font variants, when the variant lands, then each is a complete `[bar/global]` in its own `themes/global/base-*` file and every theme entry includes exactly one. (AC amended during implementation: the planned shared `[bar/global-common]` parent cannot work — polybar resolves at most TWO `inherit` hops from a bar section, verified by `--dump` with a minimal fixture; the few duplicated common keys are guarded byte-identical by a clitest case instead.)
- Given nord-arrow's bars/colors/modules, when the variant lands, then they exist once (shared body include) — the variant entry config adds no duplicated bar definitions
- Given the selector, when it lists themes, then `nord-arrow-slim` appears and toggling between it and nord-arrow visibly switches only the fonts/arrows
- Given the inherit chain depth this introduces, then it is verified with `polybar --dump` through the full chain before landing
- Blocked on [3.21](#story-321-per-theme-bar-manifests--revive-nord-under-the-55-launcher) merging (the entry/body split changes what the launcher's theme checks see); branches off `main` only

**Evidence artifact:** selector screenshot with three themes + before/after bar
screenshots of the two nord-arrow variants.

---

### Story 3.23: hardware segments self-gate — temp/battery vanish where the hardware doesn't exist ✅

As the repo owner,
I want the cpu-temp and battery bar segments (chevrons included) to appear only on
machines that expose the hardware,
So that a VM's bar isn't a broken chain of orphan arrows and a laptop still gets its
battery — automatically, with no per-machine config.

Issue: [#179](https://github.com/amasover/dotfiles/issues/179) (closed, PR #180)

Follow-up fix: [#193](https://github.com/amasover/dotfiles/issues/193) — laptop temp→battery
junction broke because battery's format padding renders before the prefix chevron.

Mechanism (v2 — Aaron vetoed reordering; the original mid-chain order stays):
polybar itself already disables `internal/temperature` when no thermal zone exists and
`internal/battery` when no BAT* device does — VMware guests expose neither — so the
probe is free. Each segment's entry chevrons ride its own `format-*-prefix`, dying with
the module (the standalone chevron `custom/text` modules that survived as orphans are
deleted). With the order preserved (volume → temp → battery → time), exactly **two**
junction colors depend on which neighbors exist: battery's entry-chevron background and
the time-chevron's background. `tools/hw-junctions emit` probes the hardware and writes
them to `~/.cache/polybar/hw-junctions`; launch.sh regenerates it every launch and the
nord-arrow body splices it via a dedicated `[hw]` section's single `include-file`
(sidestepping the duplicate-key fatality), referenced as `${hw.bat-prev}`/
`${hw.time-prev}`. Temperature always follows volume, so its prefix is static. Two dead
ends recorded: `${env:}` refs don't substitute inside module lists
([knowledge/errors/polybar-env-in-module-lists.md](../knowledge/errors/polybar-env-in-module-lists.md)),
and tail placement traded the ordering for static colors (vetoed).

**Acceptance criteria:**

- Given a machine with no thermal zone and no battery (the VMware guest), when bars launch, then neither segment nor any chevron renders, the volume→time junction blends, and the module order is unchanged (screenshot evidence)
- Given a machine with both (the laptop), then volume → temp → battery → time renders with the original chevron transitions — verify on the laptop's next convergence
- Given any of the four presence states, then `hw-junctions emit` yields the correct two junction colors (clitest, fixture sysroots)
- Given the design, then clitest asserts the preserved order, the four format prefixes, the `${hw.*}` references, the `[hw]` include, and the absence of the orphan chevron modules

**Evidence artifact:** guest screenshot (unchanged order, clean blend) + laptop
screenshot (full chain), the 4-state hw-junctions tests, and the knowledge note.

### Story 3.24: meridian harness — Claude subscription proxy as a user service, omp wired through it

As the repo owner,
I want meridian running as a tracked systemd user service and oh-my-pi routed through it,
So that third-party harness experiments use the sanctioned Agent-SDK channel on my
subscription — never raw OAuth reuse — and the whole setup rebuilds from dotfiles.

Issue: [#181](https://github.com/amasover/dotfiles/issues/181)

Context: policy research 2026-08-23 — direct subscription-OAuth reuse in third-party
clients (oh-my-pi's `Anthropic oauth` provider) has been ToS-prohibited and enforced
since early 2026; the Agent-SDK path drawing on the signed-in subscription's limits is
the supported channel (per the May/June 2026 updates; re-verify before extending, the
policy flipped four times in six months).

**Acceptance criteria:**

- Given the tracked unit (`.config/systemd/user/meridian.service`), then it pins no interpreter/version paths (`/usr/bin/env meridian`; AUR owns the binary), binds loopback only, and uses the documented placeholder key (a non-loopback bind needs 3.25's real auth)
- Given omp, then `.omp/agent/models.yml` override-routes the built-in anthropic provider to `http://127.0.0.1:3456` with the Pi adapter header — omp's config-apiKey precedence guarantees no stored OAuth token is forwarded upstream
- Given a fresh machine, then bootstrap step 8d enables tracked user units (tolerating starts that wait on `claude login`), and both packages install from the `development` group (triaged out of the inbox)
- Given `~/.omp/agent/`, then only `models.yml`, `config.yml`, and reviewed
  `extensions/*.ts` sources are tracked — `agent.db` (credentials) and the
  state DBs stay machine-local, never synced

**Evidence artifact:** `systemctl --user is-active meridian` + a 200 from
`/v1/models` on the guest; clitest config assertions.

---

### Story 3.25: meridian + Claude on the home server (handoff)

As the repo owner,
I want meridian and its Claude auth hosted on the home server,
So that any machine on my network can point a coding harness at one shared endpoint.

Issue: [#182](https://github.com/amasover/dotfiles/issues/182)

Handoff scope (decide in-story): system unit vs lingering user unit; headless server
auth (`claude login` / omp auth-broker); a real `MERIDIAN_API_KEY` + TLS or a
tailnet/wireguard-only bind — 3.24's placeholder-key/loopback stance explicitly does
not transfer off-box; per-client config pattern (models.yml baseUrl per machine);
usage-limit sharing (every machine drains one subscription); and a fresh ToS posture
check at build time. Blocked on home-server availability.

**Evidence artifact:** a client machine completing an omp session against the
server endpoint, and the security decisions recorded.

---

### Story 3.26: Track dark-mode and Alacritty Nord defaults ✅

As the repo owner,
I want the laptop's dark-mode preference and Alacritty theme represented in tracked config,
So that a fresh i3 session gives Firefox and the terminal the same appearance as the laptop.

Issue: [#185](https://github.com/amasover/dotfiles/issues/185) (closed, PR [#187](https://github.com/amasover/dotfiles/pull/187))

Origin: a 2026-08-23 guest/laptop comparison found two untracked inputs. The
laptop's explicit dconf value
`org.gnome.desktop.interface color-scheme = 'prefer-dark'` makes the XDG
appearance portal report `color-scheme = 1`, which Firefox consumes for CSS
`prefers-color-scheme`; the tracked GTK 3 preference alone did not reproduce
that result on the guest. The live Nord/Hack
`~/.config/alacritty/alacritty.toml` was absent from the repo entirely.

**Acceptance criteria:**

- Given a new bare-i3 session, then tracked startup sets the desktop color
  preference to `prefer-dark`, the appearance portal reports `uint32 1`, and
  Firefox reports `prefers-color-scheme: dark`
- Given Alacritty on a fresh machine, then its tracked config loads the
  laptop's Nord palette, Hack font variants, and Shift+Return binding
- Given the laptop files, then `.xinitrc` is compared with live home before
  editing and the tracked Alacritty TOML is byte-identical to the live source

**Evidence artifact:** shell syntax/config-load checks plus portal and Firefox
dark-mode output from the guest after checkout.

---

### Story 3.27: OMP paired provider modes and Meridian session affinity

As the repo owner,
I want OMP's provider fallback and Meridian tool-round continuity represented in
tracked configuration,
So that moving from Claude credits to OpenAI stays deliberate and a Claude tool
round retains its SDK session instead of re-reading work.

Issue: [#195](https://github.com/amasover/dotfiles/issues/195)

Context: `omp-mode` selects provider-paired YAML overlays before OMP starts:
Claude uses Fable `xhigh` with Haiku `low` workers; OpenAI uses Terra `xhigh`
with Luna `low` workers. OMP's extension API can set an active primary model but
has no supported session-scoped mutation for `modelRoles` or
`task.agentModelOverrides`; retain the launcher rather than write global config
from a plugin. Separately, the Pi adapter needs `x-session-affinity` on
Meridian requests after a tool result; without it Meridian intentionally starts
an independent SDK session every round ([Meridian #820](https://github.com/rynfar/meridian/issues/820)).

**Acceptance criteria:**

- Given the tracked `meridian-session-affinity` extension, then a request
  already marked `x-meridian-agent: pi` carries the current OMP session ID as
  `x-session-affinity`; unmarked Anthropic requests are unchanged
- Given a Meridian tool round, then the first request is `lineage=new` and its
  tool-result continuation is `lineage=continuation` in proxy telemetry
- Given `omp-mode claude`, then Fable at `xhigh` is primary and subsequent
  `sonic`/`scout` workers use Haiku at `low`; given `omp-mode openai`, then
  Terra at `xhigh` is primary and those workers use Luna at `low`
- Given a later `/provider-mode` extension proposal, then it waits for an OMP
  session-scoped worker-routing API; it does not use private internals or write
  `~/.omp/agent/config.yml` at runtime

**Evidence artifact:** extension/header contract test, a real Meridian
`lineage=new` → `lineage=continuation` tool-round trace, and both mode
configuration outputs.

---

### Story 3.28: OMP LSP coverage across active workstation languages

As the repo owner,
I want OMP's existing LSP operations backed by reproducibly installed language servers,
So that the agentic coding environment gets semantic navigation and safe refactors across
the languages used on this workstation.

Issue: [#206](https://github.com/amasover/dotfiles/issues/206) · Origin: Story 3.2 found
that OMP has a deep LSP client but this repo detects only YAML and OmniSharp; gopls and
YAML LS are unowned global installs, while Bash LS, TypeScript LS, Pyright, and Marksman
are absent.

Decisions: rely on OMP's built-in server definitions plus package declarations; add an
override only for a reproduced default failure. Guarantee Bash/Zsh, TypeScript/JavaScript,
Python (official Pyright + Ruff), Markdown, Go, YAML, C#, and Terraform. New OMP protocol
actions are out of scope.

**Acceptance criteria:**

- Given the editor/tooling manifest, official packages declare `bash-language-server`, `typescript-language-server`, `pyright`, `marksman`, `gopls`, `yaml-language-server`, and `ruff`; existing OmniSharp and Terraform LS declarations remain in their appropriate groups
- Given an approved live reconcile, each server resolves from its declared package and the unowned GOPATH/Yarn copies are retired without removing unrelated global tools
- Given representative active repositories, OMP auto-detects the expected built-in server without a copied user-wide server map; any override is minimal and records the reproduced reason
- Given behavioral validation, diagnostics plus definition/references work across representative languages, and rename preview plus one code action run against disposable files; status-only evidence is insufficient
- Given Python, Pyright owns type intelligence and Ruff owns lint diagnostics without duplicate output being counted as separate defects

**Evidence artifact:** manifest diff, OMP status/capability output, per-language behavioral
transcripts, and live cutover record.

---

### Story 3.29: Evaluate OMP marketplace plugins across three plugin shapes

As the repo owner,
I want OMP marketplace plugins reviewed and trialed under a bounded trust model,
So that useful extensions can join the agentic coding environment without silently adding
hooks, credentials, network access, or duplicate prompt/tool weight.

Issue: [#207](https://github.com/amasover/dotfiles/issues/207) · Origin: Story 3.2 found
the official marketplace configured but no plugins installed. The tracked Meridian affinity
module is a direct extension, not a plugin.

Decisions: review three shapes—skills/agents, hooks/extensions, and LSP metadata. Seed
candidates are `code-simplifier`, `security-guidance`, and `typescript-lsp`; source review
may replace a rejected candidate only with the same shape. Trial one at a time under an
isolated OMP profile with project scope. A keeper promotes to user scope and becomes
reproducible; zero keepers is valid.

**Acceptance criteria:**

- Given the baseline, configured marketplaces, zero installed plugins, built-in capabilities, skills, and direct extensions are recorded so overlap is not mistaken for value
- Before installation, every executable surface is reviewed: hooks, extension modules, tools, commands, agents, MCP servers, LSP config, subprocess/network behavior, data paths, and credential access
- No networked MCP, remote-write integration, credential handoff, or executable hook runs without separate explicit approval; extension/hook code is treated as in-process trusted code
- Each accepted candidate installs project-scoped under an isolated profile, runs one bounded real task, and is compared with baseline value, noise, reliability, latency, and overlap
- Rejected candidates are uninstalled with no enabled plugin, project lock entry, hook, MCP server, LSP override, or cached credential left behind
- A keeper is promoted to user scope, verified in two unrelated projects, and gets a repeatable install/upgrade path; if none earns that burden, the zero-plugin baseline is restored

**Evidence artifact:** source-review matrix, isolated trial transcripts, keep/drop decisions,
residue checks, and reproducibility change for any keeper.

---

### Story 3.30: Thoroughly modernize the Spacemacs configuration

As the repo owner,
I want `.spacemacs` audited and simplified against current Emacs/Spacemacs behavior,
So that the current workspace editor keeps its workflows without hiding diagnostics,
disabling runtime safeguards, or carrying years of untested sediment.

Issue: [#210](https://github.com/amasover/dotfiles/issues/210) · Origin: Story 3.2
classified Spacemacs as current, while Story 2.13 owns only checkout reproducibility.
The opportunity pass found global warning suppression, effectively disabled garbage
collection, overwritten YAML schema state, stray startup prints, duplicate declarations,
and old Nord/Helm/Go/C#/path workarounds needing evidence.

Decision: thorough behavior-preserving modernization. Keep Spacemacs, Vim-style editing,
and confirmed workflows; baseline first rather than regenerate blindly or begin an editor
migration.

**Acceptance criteria:**

- Before editing, deterministic batch startup/timing and attended representative workflows establish a baseline for startup/theme, Vim editing, navigation, Git, completion, and confirmed active language integrations
- User-owned choices are separated from unchanged template defaults and generated sediment; pruning preserves an understandable, loadable config
- Useful warnings and normal garbage-collection semantics are restored, with before/after startup and memory measurements
- YAML schemas accumulate instead of replacing each other; debug prints and duplicate declarations disappear
- Each workaround is tied to its original defect and current versions, then removed only after a focused reproduction proves it obsolete or retained with a concise reason
- Active layers/packages match declared external dependencies; dead integrations and active hardcoded machine paths are removed or made portable without exposing private values
- Current Emacs + upstream Spacemacs `develop` start cleanly in batch and attended GUI modes, and every retained baseline workflow passes
- Live reverse-testing, editor restarts, plugin changes, and package mutations remain separately approved, with a rollback copy before the first live trial

Out of scope: switching editor/distribution/keymap, repairing `~/.emacs.d` (Story 2.13),
OMP LSP coverage (#206), and broad shell cleanup.

**Evidence artifact:** audit matrix, baseline/after measurements, focused config diff,
batch transcript, and attended workflow checklist.

---

### Story 3.31: Integrate OMP into Emacs through ACP

As the repo owner,
I want OMP available through a native Emacs agent buffer over ACP,
So that the workspace editor and agentic coding environment can share project context,
diff review, and permission UX without bespoke process glue.

Issue: [#214](https://github.com/amasover/dotfiles/issues/214) · Origin: Story 3.30
found abandoned GPTel experiments plus overlapping Aider/Aidermacs/Copilot surfaces.
Current [agent-shell](https://github.com/xenodium/agent-shell) is an Emacs ACP client and
ships `agent-shell-omp-start`, whose adapter launches `omp acp`; the protocol contract is
documented by [ACP](https://agentclientprotocol.com/) and implemented by
[acp.el](https://github.com/xenodium/acp.el).

**Acceptance criteria:**

- Current Copilot, Aider/Aidermacs, and commented GPTel workflows are baselined and assigned coexist/replace/retire decisions before another agent UI is retained
- `agent-shell`, `acp.el`, and the OMP adapter receive source/security review covering subprocess environment, file requests, permissions, cwd, session state, auth inheritance, and provider boundaries
- `agent-shell-omp-start` is prototyped against `omp acp` under isolated Emacs/OMP state with approval prompts enabled; user-scope yolo is never the default
- One bounded project workflow sends region/file context, requests a code change, renders its diff/tool activity, approves selectively, and verifies resulting files with normal project tests
- Project selection, prompt queue/steering, interruption, clean shutdown, process failure, and ACP-exposed model/session controls are exercised
- Session resume/history limitations are recorded from protocol behavior; no private session-file coupling is invented around a missing ACP capability
- A keep verdict declares packages/config/keybinding reproducibly, retains terminal OMP, and adds isolated ERT plus attended ACP smoke evidence; a drop verdict removes prototype state completely
- Existing AI integrations are removed only after their unique retained workflows are covered or explicitly retired

Out of scope: changing OMP core without a reproduced ACP gap, globally auto-approving
tools, forwarding OMP credentials into Emacs config, or replacing inline Copilot completion.

**Evidence artifact:** integration comparison matrix, source/security review, isolated ACP
transcript, ERT results, live workflow evidence, and keep/drop decision.

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
