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
- **Secret scanning:** `betterleaks` (gitleaks fallback only where it isn't installed yet;
  the guest has it via the 2.46 vendored PKGBUILD) before every commit/PR
  ([recipe](../knowledge/recipes/secret-scan.md)), always paired with a manual
  privacy pass by eye — the scanner misses employer/personal/host details.

## How to start a session

1. Read this file, then the relevant epic's **Stories** section (not the whole epic).
2. Pick up work via its GitHub issue; check `knowledge/` for related recipes.
3. Branch `story/<n>-<slug>` off `main`; one story per branch and PR; PRs against `main` only (never stacked).
4. When a chunk lands, update this file *per the format contract above*.

## In flight

- **The 2026-07-19 23:07 run went fully green** (`bootstrap rc=0` + `check rc=0`, unmanaged empty,
  drift clean) — first ever. It was a *resumed* run; one fresh `destroy` → `up` still supplies the
  fresh-run evidence for **2.19** ([#70](https://github.com/amasover/dotfiles/issues/70), full log set),
  **2.26** ([#83](https://github.com/amasover/dotfiles/issues/83), prompt-free from scratch),
  **2.27** ([#87](https://github.com/amasover/dotfiles/issues/87), `df /` ≈ disk size), and formal
  2.34 DB-age evidence. Aaron plans it soon. The green-run logs (22:19 + 23:07) already carry the
  evidence for **2.32/2.33/2.22** ([#100](https://github.com/amasover/dotfiles/issues/100)/[#103](https://github.com/amasover/dotfiles/issues/103)/[#75](https://github.com/amasover/dotfiles/issues/75)),
  **2.34** ([#107](https://github.com/amasover/dotfiles/issues/107), zero retrieval failures), and
  2.31's resume — closable at Aaron's call.
- **2.31 resumable `up`** ([#98](https://github.com/amasover/dotfiles/issues/98)): open for the
  interrupt+resume evidence + the resume gap (a resumed `up` never updates the guest's yadm
  checkout — `yadm clone || true` no-ops; candidate 2-line fix on the issue). The old
  evdi/displaylink hold resolved itself: chaotic ships 6.3-2.1 against evdi 1.15.0, installed clean 07-19.
- **2.21 progress mode** ([#73](https://github.com/amasover/dotfiles/issues/73)): #102 + #111
  (SIGWINCH resize fix, pty regression test) merged; open for attended transcripts from a green run.
- **2.26 provider pins** ([#83](https://github.com/amasover/dotfiles/issues/83)): #86/#99/#110 merged
  (PROVIDER_PINS step 3d). The host jack2→pipewire-jack swap is **done** (verified live
  2026-08-15: jack2 absent, pipewire-jack installed).
- **2.25 dotnet repo stack** ([#82](https://github.com/amasover/dotfiles/issues/82)): open for the
  gated host live swap + the `dotnet-runtime-2.1`/`2.2` relic decision; four repo names drift
  declared-but-missing until then.
- **Direction (2026-07-10 grill)**: cleanup era ends at the daily-driver rebuild (a VMware VM
  on the Windows machine, not metal first) + the 1.8 work-machine steps. Record:
  [decision-daily-driver-vm.md](./decision-daily-driver-vm.md), PRD §4 eras, runbook checklist.
  Sequence: fresh evidence run → live steps above → **2.30** ([#96](https://github.com/amasover/dotfiles/issues/96))
  class+hardware split (now incl. the guest NetworkManager decision) → **2.29** ([#95](https://github.com/amasover/dotfiles/issues/95),
  amended: daily-VM first) → milestone run; **4.7** ([#94](https://github.com/amasover/dotfiles/issues/94)) CI parallel; epic 3 after.
- **2.40 metapac reinstall churn** ([#131](https://github.com/amasover/dotfiles/issues/131)): `yay
  --sync --asexplicit` without `--needed` reinstalls every installed declared package each sync
  (37–50 per run). Open question on the issue: whether `--needed` skips the explicit re-marking
  that keeps `unmanaged` honest.
- **2.36 Windows vm-harness** ([#119](https://github.com/amasover/dotfiles/issues/119), reopened):
  slices 1–4 merged (PRs #120/#121/#128/#134), pty/color follow-up merged (#142). **The evidence
  artifact landed 2026-08-21**: a fully green `up` (`bootstrap rc=0` + `check rc=0`, unmanaged
  and missing both empty, four honest age-deferrals) — logs `20260820-194838-*` / `20260821-*`
  on the Windows machine. Run on `story/2.45-syu-upgrade-holds` (guest needed #145's 3c fix +
  the 2.42 retag done by hand), so the from-`main` rerun after #146 merges is the formal
  close-out. Still open: attended bar/compact display transcripts. Spun out: **2.41**
  ([#132](https://github.com/amasover/dotfiles/issues/132)), **4.10**
  ([#133](https://github.com/amasover/dotfiles/issues/133)). 2.37 waits on 2.29/2.30.
- **2.42 unmanaged-names parsing** ([#135](https://github.com/amasover/dotfiles/issues/135), PR
  open from `story/2.42-unmanaged-inline-toml`): metapac 0.10's inline-TOML `unmanaged` output
  made bootstrap 6b's dep-retag and the drift report's listing silent no-ops — caught live by
  the harness check's exactly-empty gate (lua51/qt5-charts/yaycache stayed explicit). One shared
  seam (`tools/metapac-unmanaged-names`, clitest-covered, both shapes) now feeds both consumers.
- **2.38 unattended holds** ([#124](https://github.com/amasover/dotfiles/issues/124),
  PR [#138](https://github.com/amasover/dotfiles/pull/138) merged 2026-08-16; issue stays open
  for the evidence run): implementation complete — known-broken CLI,
  age-deferral in pre-flight + sync loop, filtered `metapac --config-dir` staging, drift-report
  buckets; clitest 88→115 green. First validation run (2026-08-16) proved the skip path live
  (both `DEFERRED [broken]` lines fired) and flushed out three more finds fixed on the branch:
  the libgl provider prompt (chaotic's nvidia-340xx-utils; pinned via PROVIDER_PINS + the
  deterministic-fatal seam now catches resolver prompts), the arc-theme bit-rot (→ 3.18 #137),
  and a `broken`-CLI commit-id intake bug. **Owed: the green evidence run** — with #138 merged
  (and once 2.43's PR lands) it's a plain `vm-harness destroy` + `up` off `main`: playwright
  installs via `auto`; the arcs pre-build patched (3.18 workaround), so expect ZERO deferrals —
  the held-path live proof is run 1's two `DEFERRED` lines + the clitest coverage. Adversarial-review fixes pushed
  2026-08-16 (known-broken retry now gated on an aged fix newer than `broken_at` via
  `broken-fix`, filter fails closed on non-house TOML styles, CLI intake hardening; clitest
  115→129 — details in the PR comment).
- **2.45 syu upgrade holds** ([#144](https://github.com/amasover/dotfiles/issues/144), PR open
  from `story/2.45-syu-upgrade-holds`): a chaotic-gate age hold on an *upgrade* killed step 3c's
  `pacman -Syu` on the 2026-08-20 resumed run — the aged ngrok was already installed, but 3c had
  no hold handling and 2.38's deferrals only shape the *requested* set. Fixed: unattended 3c
  retries with accumulated `--ignore` for age holds on installed packages (deferred + reported
  like every 2.38 hold); everything else still dies. Owed: the evidence run log (spec in epic 2).
- **2.39 quarantine pin is defeatable** ([#130](https://github.com/amasover/dotfiles/issues/130)):
  a stepped AUR commit doesn't pin what gets built — `playwright`'s `pkgver()` replaced the aged
  pin with the newest upstream. Spec now in epic 2. **Blocked**: the grill's policy-options
  writeup went down with the lost 2.38 branch and none was chosen — re-derive the options
  (likeliest source: the 2026-08-13 Windows-machine session transcript) before picking one; the
  recreated [error note](../knowledge/errors/quarantine-pin-defeated-by-pkgver.md) records the loss.
- **2.43 shim-signed audit** ([#136](https://github.com/amasover/dotfiles/issues/136), PR open
  from `story/2.43-drop-shim-signed`): audit done, findings on the issue — Secure Boot is
  disabled with the firmware in Setup Mode, rEFInd boots directly and unsigned, no MOK, empty
  keys dir; the only shim on the ESP is **Ubuntu's live dual-boot** (do not touch). Decision:
  `shim-signed` dropped from `base.toml`, its deferral entry retired. Still Aaron's: whether to
  uninstall the host's shim-signed/sbsigntools/mokutil-git copies. Future work spun out as
  **2.44** ([#139](https://github.com/amasover/dotfiles/issues/139)): Secure Boot as a property
  of **fresh installs** (provisioning-time enrollment in the 2.29 recipe, self-re-signing
  chain) — this workstation explicitly out of scope, opt-in later.
- **3.18 arc theme** ([#137](https://github.com/amasover/dotfiles/issues/137), PR open from
  `story/3.18-arc-build-workaround`): root cause found (meson 1.12 validates `depend_files` as
  files; arc's `find` feeds it directories) — one-line fix validated on the 2022 tarball (full
  guest build) and upstream master; upstream PR drafted from `~/code/arc-theme` (Aaron submits).
  Interim: repo-local patch under `.config/dotfiles/aur-patches/` applied by `aur-quarantine
  build` + a bootstrap pre-build pass, both arcs **un-deferred**. Delete the patch when the
  upstream PR merges AND the AUR recipe ships it; the theme-future decision stays open.
  Follow-up in PR: the patch stage's `makepkg --nobuild` verified source PGP sigs, which a
  fresh guest's empty keyring can never satisfy (arc died "unknown public key", 2026-08-20 run)
  — now `--skippgpcheck` there; checksums + the age pin stay the integrity gate.
- **3.17 monitor-name migration** ([#129](https://github.com/amasover/dotfiles/issues/129)):
  live breakage until done — the 3.16 driver switch renamed Xorg outputs (`eDP1`→`eDP-1` etc.),
  so autorandr dock/undock auto-switching currently matches nothing and polybar's multi-monitor
  layouts can't select. Attended work per docking setup; spec in epic 3.
- **2.30 hardware split** ([#96](https://github.com/amasover/dotfiles/issues/96)): 3.16 turned up
  concrete evidence — the `desktop` group declares an AMD GPU set (`xf86-video-amdgpu`,
  `vulkan-radeon`, `lib32-vulkan-radeon`) on what is now an Intel laptop, `vulkan-intel` is
  missing, and `package-inventory.md` still calls the machine AMD. Detailed on the issue.

- **Epic 5 charter** (PR pending from `docs/epic-5-guest-daily-driver`): new epic for
  guest-as-daily-driver work — stories 5.1–5.6 ([#148](https://github.com/amasover/dotfiles/issues/148)–[#153](https://github.com/amasover/dotfiles/issues/153),
  all on the board): fresh-machine SSH keys, attended auth bootstrap, current-guest
  credential fix, dynamic resolution, polybar on guests, unattended host-driven auth.
- **3.19 default browser** ([#158](https://github.com/amasover/dotfiles/issues/158)): #159
  merged; the chromium inbox→browsers triage commit missed that merge window and is rescued
  as PR [#160](https://github.com/amasover/dotfiles/pull/160) (chromium was declared via the
  2.9 inbox all along — not drift).
- **2.46 vendored PKGBUILDs** ([#164](https://github.com/amasover/dotfiles/issues/164), PR
  [#165](https://github.com/amasover/dotfiles/pull/165) open from `story/2.46-vendored-pkgbuilds`):
  betterleaks built from the repo's own PKGBUILD (bin-style, checksum-pinned) and installed
  live on the guest; `tools/custom-pkgs` owns watch/bump/sync/pins; `update` is the
  steady-state applier. Design grilled 2026-08-22 — the epic-2 spec carries the ten
  decisions. Never declare vendored names in metapac groups (an AUR `betterleaks` exists;
  IgnorePkg guards the swap).
- **5.4 wrap-up note**: SPICE/libvirt half (pointer calibration is in `vm-autofit` but dormant;
  needs xinput + evdev InputClass declared) waits on a Linux-host run — threads on
  [#151](https://github.com/amasover/dotfiles/issues/151) (closed).

- **3.22 nord-arrow-slim** ([#174](https://github.com/amasover/dotfiles/issues/174), PR
  [#177](https://github.com/amasover/dotfiles/pull/177) open from `story/3.22-nord-arrow-slim`):
  third selectable theme — nord-arrow's bars with the slim SCP arrows. Font stacks are
  complete `themes/global/base-big`/`base-slim` files (**polybar resolves at most two
  `inherit` hops** — fixture-proven, so the planned shared-parent section was dropped;
  common keys sync-guarded by clitest), bars/colors/modules shared once via
  `themes/nord-arrow/body`, manifest symlinked. Three-way toggle live-validated. Laptop
  home runs the branch; after merge: `yadm checkout main && yadm pull`.
- **5.7 VMware Firefox acceleration** ([#189](https://github.com/amasover/dotfiles/issues/189),
  branch `story/5.7-vmware-firefox-acceleration`): live guest now has VMware 3D + Xorg
  SVGA3D and Firefox hardware WebRender/WebGL through GLX; tracked VMX + guest-only
  enterprise policy are implemented and focused tests are green. Owed: review/PR.


## Standing warnings

- **Chat transcripts are sensitive.** Org package names and the work email have each leaked into a
  session transcript (the repo stayed clean). Filter package listings before echoing them, and never
  inline `~/.local/share/metapac/machine-local.toml` contents into tracked files or issues.

## Last session (2026-08-23, VMware guest)

- **5.7 built and live-validated** (#189): enabling VMware 3D fixed system GL; Firefox
  still blocklisted Mesa SVGA under EGL, but the three-pref GLX policy produced hardware
  WebRender + WebGL 1/2 on SVGA3D. A full 2334×1112 scrolling run held 60 Hz (p99
  17.44 ms, zero frames over 25 ms). Policy symlink is live under `/etc/firefox/policies`;
  source/reconciler are reverse-tested in live home pending branch merge.

- **Evening block — theme system built out**: font restore merged (#171); **2.48 done**
  (#172, PR #175 — `otf-powerline-extra-symbols` vendored + installed, the two
  yadm-tracked `.fonts` blobs it supersedes retired; correction: those blobs were
  tracked, not untracked); **3.21 done** (#173, PR #176 — `tools/theme-manifest`:
  per-theme bar lists, role gates, theme-owned `gap-top` via launch.sh, nord revived
  and toggling live). 3.22 in flight above.
- **PRs #167 (nord themes) + #168 (3.12 wpctl audio) adversarially reviewed vs the live
  laptop, fixed, and merged.** Review finds fixed on the branches before merge: the themes
  now carry everything the capture lost (`enable-ipc`, `wm-restack`, cursors, the
  `global/modules` include), DRY'd into `themes/global/base` `[bar/global]` + `inherit`
  (include-file merging makes duplicate keys FATAL — proven live); volnoti recorded as
  dormant everywhere; `volume-tail` rejects unknown flags; listen loop survives transient
  pactl failures; #168 downgraded to "part of #59" until laptop evidence existed.
- **2.47 done** (#169, PR #170): `otf-source-code-pro-powerline` vendored (14 OTFs pinned
  to frozen powerline/fonts `a029626`, `no-watch`) + installed live; IgnorePkg now pins
  both vendored names. `ttf-hack` replaced #167's wrong `powerline-fonts` declaration
  (extra's package is only PowerlineSymbols.otf). User font copies removed after backup
  (`~/fonts-local-backup-20260822.tar.gz`). Brew's font cask was rejected: `:latest`,
  no checksum, and it fires bare `sudo` (struck faillock once from the agent shell).
- **Laptop converged to main**: untracked `~/.config/polybar/config.ini` and the global
  autorandr postswitch archived (`.pre-5.5` / `.pre-3.16` — the 4K split-monitor layout
  they encoded is preserved in
  [knowledge/reference/4k-split-monitor-layout.md](../knowledge/reference/4k-split-monitor-layout.md)
  and on #129); `yadm pull`; bars relaunched on the 5.5 `-c` path (IPC sockets live,
  `updates-arch` rendering, zero log errors). **3.12/#59 closed** with laptop evidence:
  real port switch round trip, volume keys stepping wpctl, `~/code/go/bin/{dot,volume}`
  deleted. The i3 reload's exec_always did not relaunch bars once (launch.sh by hand did;
  unexplained, watch for recurrence).
- **4.7 spec refreshed** (CI test surface = clitest + pytest + the old pair; betterleaks):
  pytest newly installed on the laptop — first local run 110/110.
- **3.24 meridian harness** (#181, PR open): meridian (AUR) live as a tracked systemd
  user unit (no pinned paths, loopback, placeholder key), omp's anthropic provider
  override-routed through it (no raw OAuth forwarding by construction), packages
  triaged inbox→development, bootstrap 8d enables user units. Verified: service
  active, /v1/models 200. **3.25** (#182) is the home-server handoff story.
- **3.23 done** (#179, PR #180 merged): temp/battery bar segments self-gate in their
  historical order — chevrons in each module's format-prefix, the two adjacency-
  dependent junction colors launcher-generated (`tools/hw-junctions` → `[hw]` include).
  Guest re-converged post-merge (zero drift, relaunch verified). Laptop owes the
  full-chain look check. Two dead ends recorded en route (env refs in module lists;
  tail placement vetoed — order preserved).
- **Guest converged to main** (2026-08-23): yadm pulled (superseded hand-test hybrids of
  the theme/launcher files discarded; my untracked audio-tool copies removed for main's),
  `custom-pkgs` pins + sync installed both vendored font packages, `ttf-hack` installed
  (the only declared-but-missing), bars relaunched on the manifest launcher — zero
  font/color log errors, screenshot-verified. `powerline-fonts`
  uninstalled at Aaron's call — the 2.15 removal hook auto-dropped its inbox line;
  guest yadm drift is now ZERO. Still open: `.local/share/fonts` (133 files) is
  yadm-TRACKED (old "added powerline fonts" commit) — retiring it is a 3.3-style
  archive-candidate decision now that the vendored packages cover the bar fonts. Two
  stashes still parked on `story/2.45-syu-upgrade-holds` (launch.sh — droppable;
  bashrc/bash_profile — keep). The root `2026-08-22_16_28_39_1920x1080.png` is
  intentional (Aaron): reference image of the system's intended look.
- Prior Windows-harness session's merge queue (#142, #145, #146) still pending — the formal
  2.36/2.38 close-out run (plus 2.19/2.26/2.27/2.34 fresh-run evidence) follows once they land.

## Epics

| Epic | Scope | Phase |
| --- | --- | --- |
| [1](./epic-1-safety-inventory-live-home.md) | Safety inventory & live-home reconciliation | 1 |
| [2](./epic-2-bootstrap-and-package-modernization.md) | Bootstrap & package modernization | 2 |
| [3](./epic-3-shell-editor-desktop-cleanup.md) | Shell / editor / desktop cleanup | 3 |
| [4](./epic-4-workflow-and-governance.md) | Workflow & governance (operating model) | 1 |
| [5](./epic-5-guest-daily-driver.md) | Guest as daily driver (auth, display, desktop-in-guest) | Rebuild era |
