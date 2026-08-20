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
- **Secret scanning:** `betterleaks` (gitleaks fallback on the Linux machine) before every
  commit/PR ([recipe](../knowledge/recipes/secret-scan.md)), always paired with a manual
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
  slices 1–3 merged (PRs #120/#121/#128). GitHub auto-closed #119 at the #128 merge — the PR
  body's slice-4 sentence contains the literal closing keyword "closes #119" — reopened
  2026-08-15. Still owed: **slice 4** (progress display + ANSI scrub + the driver-tests
  decision) and the **evidence artifact** (bootstrap can't reach rc=0 until 2.38's holds land).
  Slice 4 is PR [#134](https://github.com/amasover/dotfiles/pull/134); adversarial-review fixes
  pushed 2026-08-16 (dead display sink now fails the phase, log-leg errors exit 3 — details in
  the PR comment); needs a Windows smoke run before merge.
  Spun out so they don't close with #119: **2.41** libvirt glue switchover
  ([#132](https://github.com/amasover/dotfiles/issues/132)) and **4.10** driver tests
  ([#133](https://github.com/amasover/dotfiles/issues/133)). 2.37 still waits on 2.29/2.30.
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
  installs via `auto`, two deferrals expected (the arcs). Adversarial-review fixes pushed
  2026-08-16 (known-broken retry now gated on an aged fix newer than `broken_at` via
  `broken-fix`, filter fails closed on non-house TOML styles, CLI intake hardening; clitest
  115→129 — details in the PR comment).
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
- **3.17 monitor-name migration** ([#129](https://github.com/amasover/dotfiles/issues/129)):
  live breakage until done — the 3.16 driver switch renamed Xorg outputs (`eDP1`→`eDP-1` etc.),
  so autorandr dock/undock auto-switching currently matches nothing and polybar's multi-monitor
  layouts can't select. Attended work per docking setup; spec in epic 3.
- **2.30 hardware split** ([#96](https://github.com/amasover/dotfiles/issues/96)): 3.16 turned up
  concrete evidence — the `desktop` group declares an AMD GPU set (`xf86-video-amdgpu`,
  `vulkan-radeon`, `lib32-vulkan-radeon`) on what is now an Intel laptop, `vulkan-intel` is
  missing, and `package-inventory.md` still calls the machine AMD. Detailed on the issue.

## Standing warnings

- **Chat transcripts are sensitive.** Org package names and the work email have each leaked into a
  session transcript (the repo stayed clean). Filter package listings before echoing them, and never
  inline `~/.local/share/metapac/machine-local.toml` contents into tracked files or issues.

## Last session (2026-08-16, Linux workstation)

- **Adversarial review of both open PRs** (#138 and #134), fixes committed and pushed to both
  branches the same session; full finding→fix mapping lives in a comment on each PR. The two
  #138 majors were design-level: the known-broken auto-retry could only rebuild the already-
  broken recipe (any third-party AUR push → ~14 days of fatal unattended runs — now gated on
  `aur-quarantine broken-fix`: an aged commit newer than `broken_at`), and shim-signed's
  "no auto-retry" note is not mechanism-enforced (**left as-is at Aaron's call** — an aged-in
  fix may auto-install ahead of 2.43's audit; revisit via #136). The #134 major: a dead/missing
  display child silently lost all phase output while the phase stamped rc=0 — now the phase
  fails loudly and log-leg errors exit 3.
- **Environment**: `python-pycdlib` installed on the workstation (seed-ISO tests now runnable
  here); pytest still runs via `uvx pytest`. Windows gaps unchanged (4.7 #94 / 4.10 #133).
- Prior-session context (spec-branch loss and rebuild, chaotic-aur enablement, valkey swap,
  2.42 spin-out) is recorded on the relevant issues and epic entries; the `libnm` +
  `networkmanager` undeclared drift is still Aaron's to triage (likely 3.9 #41 fallout).
- **Spun out of the 2.38 validation run (2026-08-16)**: **2.43** shim-signed boot-chain audit
  ([#136](https://github.com/amasover/dotfiles/issues/136) — is Secure Boot even in the chain?
  the AUR recipe healed 2026-07-31 but it stays deferred until the audit) and **3.18** Arc
  theme triage ([#137](https://github.com/amasover/dotfiles/issues/137) — release-less upstream,
  unbuildable split-package pair, yet the live desktop runs Arc-Dark). Aaron's live
  step done this session: `aur-quarantine auto playwright` — **the exempt list changed, so
  `yadm encrypt` is owed before the next yadm push** (the 4.9 guard will block until then).
- **2.43 executed after the PR merges**: boot-chain audit (findings on #136 — no Secure Boot,
  Setup Mode, unsigned rEFInd booting directly; the ESP's shim is Ubuntu's **live dual-boot**,
  corrected from "leftovers"), `shim-signed` dropped + deferral retired on the 2.43 branch, and
  **2.44** (#139) opened with its stub — reframed at Aaron's direction to *fresh installs boot
  Secure* (provisioning-time, rides the 2.29 recipe), not a fix for this machine.

## Epics

| Epic | Scope | Phase |
| --- | --- | --- |
| [1](./epic-1-safety-inventory-live-home.md) | Safety inventory & live-home reconciliation | 1 |
| [2](./epic-2-bootstrap-and-package-modernization.md) | Bootstrap & package modernization | 2 |
| [3](./epic-3-shell-editor-desktop-cleanup.md) | Shell / editor / desktop cleanup | 3 |
| [4](./epic-4-workflow-and-governance.md) | Workflow & governance (operating model) | 1 |
