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

### Story 3.23: hardware segments self-gate — temp/battery vanish where the hardware doesn't exist

As the repo owner,
I want the cpu-temp and battery bar segments (chevrons included) to appear only on
machines that expose the hardware,
So that a VM's bar isn't a broken chain of orphan arrows and a laptop still gets its
battery — automatically, with no per-machine config.

Issue: [#179](https://github.com/amasover/dotfiles/issues/179)

Mechanism (chosen after a dead end — see
[knowledge/errors/polybar-env-in-module-lists.md](../knowledge/errors/polybar-env-in-module-lists.md)):
polybar itself already disables `internal/temperature` when no thermal zone exists and
`internal/battery` when no BAT* device does — VMware guests expose neither — so the
probe is free. What was missing: the segments' powerline chevrons were standalone
`custom/text` modules that survived as orphans, and removing middle segments broke the
adjacency-paired chevron colors. Fix shape: temperature/battery move to the **tail** of
bar/main's right chain (battery at the screen edge), each carries its entry chevrons in
its own `format-*-prefix` (inline color tags), the orphan chevron modules are deleted,
and the one interior chevron that changed neighbors (`-time`) is re-paired to
volume-tail's background. Being last, their absence alters no surviving junction — the
chain just ends at the date.

**Acceptance criteria:**

- Given a machine with no thermal zone and no battery (the VMware guest), when bars launch, then neither segment nor any of its chevrons renders and every remaining junction blends (screenshot evidence)
- Given a machine with both (the laptop), then temp + battery render at the tail with correct chevron transitions — verify on the laptop's next convergence
- Given the known caveat, then a battery-without-thermal-zone machine would show one off-color junction (battery's entry chevron pairs with temperature's background) — documented in the body, no such machine exists today
- Given the design is body-level, then clitest asserts the tail placement, the four format prefixes, and the absence of the orphan chevron modules

**Evidence artifact:** guest screenshot (clean shortened chain) + laptop screenshot
(full chain), and the knowledge note on the discarded `${env:}` approach.

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
