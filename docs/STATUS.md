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
  (PROVIDER_PINS step 3d). Host jack2→pipewire-jack swap stays a live step.
- **2.23 redis→valkey** ([#76](https://github.com/amasover/dotfiles/issues/76)): [PR #115](https://github.com/amasover/dotfiles/pull/115)
  **merged** — valkey declared (Aaron's call). Open until the host live swap + clean drift report.
  The *parked* guest has AUR redis installed and would conflict on its next sync — moot if destroyed.
- **2.25 dotnet repo stack** ([#82](https://github.com/amasover/dotfiles/issues/82)): open for the
  gated host live swap + the `dotnet-runtime-2.1`/`2.2` relic decision; four repo names drift
  declared-but-missing until then.
- **Aaron's pending live steps**: chaotic adoption + jack2/redis swaps via attended bootstrap/sync
  (2.28/2.26/2.23). The yadm-side steps are done — `core.hooksPath .githooks` set (4.4) and the
  archive refreshed 2026-08-11 (4.9).
- **Direction (2026-07-10 grill)**: cleanup era ends at the daily-driver rebuild (a VMware VM
  on the Windows machine, not metal first) + the 1.8 work-machine steps. Record:
  [decision-daily-driver-vm.md](./decision-daily-driver-vm.md), PRD §4 eras, runbook checklist.
  Sequence: fresh evidence run → live steps above → **2.30** ([#96](https://github.com/amasover/dotfiles/issues/96))
  class+hardware split (now incl. the guest NetworkManager decision) → **2.29** ([#95](https://github.com/amasover/dotfiles/issues/95),
  amended: daily-VM first) → milestone run; **4.7** ([#94](https://github.com/amasover/dotfiles/issues/94)) CI parallel; epic 3 after.
- **metapac reinstall churn** (from the 07-19 log review): `yay --sync --asexplicit` without
  `--needed` reinstalls every installed declared package each sync (37–50 per run) — investigation
  in progress, story TBD.
- **2.36 Windows vm-harness** ([#119](https://github.com/amasover/dotfiles/issues/119)): slices 1–2
  merged (PRs #120/#121). Slice 3 next: bootstrap/check via shared guest bash, resumable `up`,
  `exec` — plus the trust-baseline injection, which doesn't port (the Windows host has no plaintext
  `aur-quarantine` source); design note on the issue, and it needs 4.9's encrypt first.
  2.37 (daily target) still waits on 2.29/2.30.
- **3.10 screen recorders** ([#42](https://github.com/amasover/dotfiles/issues/42),
  [PR #125](https://github.com/amasover/dotfiles/pull/125)): all three incumbents are dead here —
  kooha (no ScreenCast portal backend under i3/X11), simplescreenrecorder (dropped from the Arch
  repos, orphan linked against ffmpeg 7), kazam (dead upstream). `gpu-screen-recorder` +
  `-ui` are the keepers. Aaron's live step: uninstall the three, or they show as `metapac unmanaged`.
- **Desktop has been running on software rendering.** `MESA_LOADER_DRIVER_OVERRIDE=i965` in
  `.profile:40` names a driver mesa deleted years ago, so everything GL fell back to llvmpipe —
  the actual reason recording looked broken, not the long-assumed pending reboot. Removing the
  export restores Iris Xe acceleration (verified with `env -u`). Separately, legacy
  `xf86-video-intel` is installed and Xorg picks it over `modesetting`, logging "Unknown chipset"
  + "disabling acceleration". Both need issues + gated live steps; diagnosis in
  [knowledge/errors/mesa-i965-override-forces-llvmpipe.md](../knowledge/errors/mesa-i965-override-forces-llvmpipe.md).

## Standing warnings

- **Chat transcripts are sensitive.** Org package names and the work email have each leaked into a
  session transcript (the repo stayed clean). Filter package listings before echoing them, and never
  inline `~/.local/share/metapac/machine-local.toml` contents into tracked files or issues.

## Last session (2026-08-11, Linux workstation)

- **The encrypt manifest and the archive had silently diverged.** The AUR trust baseline
  joined `.config/yadm/encrypt` on 2026-07-09 (`9f5e7d3`) but the archive was last written
  2026-06-20 (`03e4f1b`) — declared, never encrypted, so a fresh machine's decrypt restored
  no trust state. Fixed by **4.9** ([#122](https://github.com/amasover/dotfiles/issues/122) ✅,
  PR #123): a yadm `pre_push` guard that blocks the push when a manifest match is newer than
  the archive (timestamps only; globs report a count, never expanded `.ssh/**` filenames).
  Attended wrap-up on the live machine: `core.hooksPath .githooks` set, `yadm encrypt` run,
  archive 48667 → 51085 bytes, pushed (`d84f2d5`), guard now silent.
- Auto-encrypt-on-push was considered and rejected — symmetric gpg needs a TTY, and its
  non-deterministic output would commit a fresh ~49k blob every push. A keypair
  (`yadm.gpg-recipient`) would fix the TTY problem but make fresh-machine recovery depend on
  transporting a private key; recorded on #122 rather than adopted.
- **2.36 slice 3 design note** on [#119](https://github.com/amasover/dotfiles/issues/119):
  `inject_trust_baseline` doesn't port — it scp's the *Linux host's* plaintext
  `aur-quarantine` files, and Windows has no such source. Rejected clone-then-decrypt in the
  unattended guest (routes the passphrase into a throwaway VM); proposed an overridable trust
  dir populated once on the Windows host by selective `gpg -d | tar xf -` of just the two
  files, with `VM_HARNESS_FRESH_TRUST=1` as the cheap default and its fidelity cost named.
- Environment note: pytest isn't installed on the Linux workstation, so the 2.36 Python
  suites can't run here — the mirror of 2026-08-10's Windows clitest gap, both 4.7's concern.

## Epics

| Epic | Scope | Phase |
| --- | --- | --- |
| [1](./epic-1-safety-inventory-live-home.md) | Safety inventory & live-home reconciliation | 1 |
| [2](./epic-2-bootstrap-and-package-modernization.md) | Bootstrap & package modernization | 2 |
| [3](./epic-3-shell-editor-desktop-cleanup.md) | Shell / editor / desktop cleanup | 3 |
| [4](./epic-4-workflow-and-governance.md) | Workflow & governance (operating model) | 1 |
