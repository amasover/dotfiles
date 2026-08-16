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
- **Aaron's pending live steps**: chaotic adoption (chaotic-keyring/-mirrorlist not yet
  installed) and the redis→valkey host swap (redis still installed, valkey absent — 2.23's issue
  auto-closed with the declaration PR, so this line is the swap's only tracker), both via
  attended bootstrap/sync (2.28/2.23). The yadm-side steps are done — `core.hooksPath .githooks`
  set (4.4) and the archive refreshed 2026-08-11 (4.9).
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
  Spun out so they don't close with #119: **2.41** libvirt glue switchover
  ([#132](https://github.com/amasover/dotfiles/issues/132)) and **4.10** driver tests
  ([#133](https://github.com/amasover/dotfiles/issues/133)). 2.37 still waits on 2.29/2.30.
- **2.38 unattended holds** ([#124](https://github.com/amasover/dotfiles/issues/124), in progress
  on `story/2.38-unattended-age-holds`, re-cut off `main` 2026-08-15): the original spec branch
  was **lost unpushed** (absent from GitHub and the Windows machine); the epic 2 stub is rebuilt
  from #124's body, which preserved the full design — acceptance criteria re-derived, Aaron to
  eyeball. Linux-side work; `lua5.1` + clitest confirmed present here. 2.36 evidence-run blockers
  unchanged: `shim-signed` (koji 404) and `playwright` (see 2.39).
- **2.39 quarantine pin is defeatable** ([#130](https://github.com/amasover/dotfiles/issues/130)):
  a stepped AUR commit doesn't pin what gets built — `playwright`'s `pkgver()` replaced the aged
  pin with the newest upstream. Spec now in epic 2. **Blocked**: the grill's policy-options
  writeup went down with the lost 2.38 branch and none was chosen — re-derive the options
  (likeliest source: the 2026-08-13 Windows-machine session transcript) before picking one; the
  recreated [error note](../knowledge/errors/quarantine-pin-defeated-by-pkgver.md) records the loss.
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

## Last session (2026-08-15, Linux workstation)

- **The 2.38/2.39 spec branch turned out lost** — `story/2.38-unattended-age-holds` was never
  pushed and isn't on the Windows machine either. Rebuilt from the issue bodies, which preserved
  the full design: 2.38's epic stub (acceptance criteria re-derived, worth Aaron's eyeball) and
  the 2.39 error note. The one unrecoverable piece is 2.39's policy-options list (see its entry).
- **All owed epic stubs written** (2.39/2.40/2.41 in epic 2, 3.17 in epic 3, 4.10 in epic 4).
  The "add the stub when the story starts" deferral is retired — a story's stub is written when
  its issue opens.
- **STATUS reconciled against the board and live pacman state**: 2.23/3.10/3.16 closed →
  ✅-marked in their epics; #119 reopened (GitHub keyword auto-close, not a decision); the jack2
  swap and the 3.10 recorder uninstalls verified done on the live machine; chaotic adoption and
  the redis swap still pending. PR #128's review details live in its PR description.
- **Environment**: `lua5.1` + clitest are present on the Linux workstation, so 2.38 is buildable
  here. pytest is still missing here, and Windows still lacks `lua5.1`/`setsid`/`script(1)` — no
  machine runs the full suite (4.7's [#94](https://github.com/amasover/dotfiles/issues/94)
  concern, and 4.10's [#133](https://github.com/amasover/dotfiles/issues/133), whose driver
  tests would need `pwsh`).

## Epics

| Epic | Scope | Phase |
| --- | --- | --- |
| [1](./epic-1-safety-inventory-live-home.md) | Safety inventory & live-home reconciliation | 1 |
| [2](./epic-2-bootstrap-and-package-modernization.md) | Bootstrap & package modernization | 2 |
| [3](./epic-3-shell-editor-desktop-cleanup.md) | Shell / editor / desktop cleanup | 3 |
| [4](./epic-4-workflow-and-governance.md) | Workflow & governance (operating model) | 1 |
