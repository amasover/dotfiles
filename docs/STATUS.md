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
  merged (PRs #120/#121); **slice 3 in review** — `exec`/`bootstrap`/`check`/`up`, shared guest
  glue, trust import. Code-complete and unit-green; the **evidence artifact is still owed**
  (bootstrap can't reach rc=0 until the declared set converges — see 2.38). Slice 4 (progress
  display + ANSI scrub) closes the story. 2.37 still waits on 2.29/2.30.
- **2.38 unattended holds** ([#124](https://github.com/amasover/dotfiles/issues/124), spec on
  `story/2.38-unattended-age-holds`, unpushed): age-deferred and known-broken packages stop
  failing unattended runs; design settled at the 2026-08-13 grill. **Linux-side work** (needs
  `lua5.1` + clitest). Three declared packages are unbuildable today and block the 2.36 evidence
  run: `simplescreenrecorder` (ffmpeg 9 API break; kooha is Wayland-only, so 3.10 can't just drop
  it), `shim-signed` (koji source 404), `playwright` (see below).
- **Quarantine pin is defeatable** ([knowledge note](../knowledge/errors/quarantine-pin-defeated-by-pkgver.md)):
  a stepped AUR commit doesn't pin what gets built — `playwright`'s `pkgver()` replaced the aged
  pin with the newest upstream. Age guarantee is silently void for such PKGBUILDs; needs its own
  story, options recorded, none chosen.

## Standing warnings

- **Chat transcripts are sensitive.** Org package names and the work email have each leaked into a
  session transcript (the repo stayed clean). Filter package listings before echoing them, and never
  inline `~/.local/share/metapac/machine-local.toml` contents into tracked files or issues.

## Last session (2026-08-13, Windows machine)

- **2.36 slice 3 built and pushed** (`exec`, shared `vm-harness-guest` glue, `bootstrap`/`check`,
  resumable `up` via a pytest-covered `vm-harness-vmx resume` table, `trust-import`). Live runs
  found four real defects, all fixed with tests: the phase log had two writers (Tee vs
  Add-Content) and crashed the first real `up`; native output decoded as OEM, mangling guest
  em-dashes; `find_ip` trusted file order and returned a **two-day-expired lease** (vmnetdhcp
  rewrites the file — ssh timed out against a dead IP while the guest was healthy); and the
  guest glue inherited `yadm clone || true`, so a resumed run converged against stale dotfiles.
- **Trust baseline now works on Windows** without bash: `vm-harness-trust` streams `gpg --decrypt`
  into `tarfile` and extracts only the two identity files — the decrypted archive never hits disk
  ([recipe](../knowledge/recipes/windows-trust-baseline.md)). Local `auto`/`accept` edits there
  are temporary; the archive is authoritative.
- Guest reached `bootstrap` and stopped on package content, not harness defects — which is the
  harness doing its job: **the declared set cannot converge on a fresh machine today** (2.38).
  The same failures would hit the pending Linux fresh-run evidence.

- Environment note: pytest isn't installed on the Linux workstation and `lua5.1`/`setsid`/
  `script(1)` are missing on Windows, so neither machine can run the full test suite —
  4.7's ([#94](https://github.com/amasover/dotfiles/issues/94)) concern.

## Epics

| Epic | Scope | Phase |
| --- | --- | --- |
| [1](./epic-1-safety-inventory-live-home.md) | Safety inventory & live-home reconciliation | 1 |
| [2](./epic-2-bootstrap-and-package-modernization.md) | Bootstrap & package modernization | 2 |
| [3](./epic-3-shell-editor-desktop-cleanup.md) | Shell / editor / desktop cleanup | 3 |
| [4](./epic-4-workflow-and-governance.md) | Workflow & governance (operating model) | 1 |
