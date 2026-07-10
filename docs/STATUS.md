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
- **Secret scanning:** `gitleaks` before every commit/PR ([recipe](../knowledge/recipes/secret-scan.md)),
  always paired with a manual privacy pass by eye — gitleaks misses employer/personal/host details.

## How to start a session

1. Read this file, then the relevant epic's **Stories** section (not the whole epic).
2. Pick up work via its GitHub issue; check `knowledge/` for related recipes.
3. Branch `story/<n>-<slug>` off `main`; one story per branch and PR; PRs against `main` only (never stacked).
4. When a chunk lands, update this file *per the format contract above*.

## In flight

- **2.19 vm-harness observability** ([#70](https://github.com/amasover/dotfiles/issues/70)):
  [PR #74](https://github.com/amasover/dotfiles/pull/74) **merged 2026-07-05**; issue stays open
  until the evidence lands — one green detached `up` with its full log set (the final fix stack
  hasn't completed a run yet). Detail: epic spec, [observability notes](./vm-harness-observability-notes.md)
  (grill D1–D11 + implementation deltas), [VM runbook](./runbook-vm-validation.md).
- **2.25 dotnet repo stack** ([#82](https://github.com/amasover/dotfiles/issues/82)):
  [PR #84](https://github.com/amasover/dotfiles/pull/84) **merged 2026-07-08**; issue open for the
  gated host live swap (-bin family → repo stack) + the `dotnet-runtime-2.1`/`2.2` relic drop decision.
  Until the swap, host drift shows the four repo names as declared-but-missing.
- **2.26 bootstrap determinism** ([#83](https://github.com/amasover/dotfiles/issues/83)):
  [PR #86](https://github.com/amasover/dotfiles/pull/86) **merged 2026-07-08**; issue open until a
  fresh VM run shows instant deterministic death or a prompt-free sync.
- **1.8 privacy scrub** ([#55](https://github.com/amasover/dotfiles/issues/55)): round-2 rewrite
  executed 2026-07-10 (nine work aliases dropped from `.zshrc`, one kept helper moved to
  `~/.zshrc.local`; second BFG pass, clones reset, sweeps clean; dead remote branches pruned —
  origin is main-only). Work machine's `~/.gitconfig-local` + `~/.zshrc.local` are in place;
  open only for hard-resetting that machine's clones to the rewritten history. Records:
  comments on #55 + the [BFG recipe](../knowledge/recipes/bfg-history-rewrite.md) round-2 lessons.
- **2.27 vm root fills disk** ([#87](https://github.com/amasover/dotfiles/issues/87)):
  [PR #88](https://github.com/amasover/dotfiles/pull/88) **merged 2026-07-08**; running VM already
  rescued in place (78G/48%); issue open until a fresh create shows `df /` ≈ disk size.
- One fresh detached VM run (`create` → `up`) supplies the closing evidence for 2.19, 2.26, and 2.27.
- **4.4 pre-commit secret scan**: [PR #90](https://github.com/amasover/dotfiles/pull/90)
  **merged 2026-07-09**, #35 closed. Remaining live step for Aaron:
  `yadm gitconfig core.hooksPath .githooks` (after a yadm checkout places `~/.githooks`).
- **2.10 AUR install gating**: [PR #92](https://github.com/amasover/dotfiles/pull/92)
  **merged 2026-07-10**, #50 closed. Remaining live steps for Aaron: yadm pull +
  `yadm encrypt` (baseline files joined the encrypt manifest).
- **2.28 Chaotic-AUR**: [PR #93](https://github.com/amasover/dotfiles/pull/93) **merged
  2026-07-10**, #89 closed. Live adoption = next attended bootstrap run (after yadm pull).
- **Direction (2026-07-10 grill)**: cleanup era ends at the daily-driver rebuild (a VMware VM
  on the Windows machine, not metal first) + the 1.8 work-machine steps. Record:
  [decision-daily-driver-vm.md](./decision-daily-driver-vm.md), PRD §4 eras, runbook checklist.
  Sequence: evidence VM run → Aaron's live steps (pull/encrypt/hooksPath) → **2.30** ([#96](https://github.com/amasover/dotfiles/issues/96))
  class+hardware split → **2.29** ([#95](https://github.com/amasover/dotfiles/issues/95), amended: daily-VM first) → milestone run;
  **4.7** ([#94](https://github.com/amasover/dotfiles/issues/94)) CI parallel; epic 3 after the VM bring-up.
- Newly ticketed: **2.31** ([#98](https://github.com/amasover/dotfiles/issues/98)) resumable `vm-harness up`
  (from the 2026-07-10 bootstrap failure on the displaylink quarantine hold).
  Everything else lives on the board.

## Standing warnings

- **Chat transcripts are sensitive.** Org package names and the work email have each leaked into a
  session transcript (the repo stayed clean). Filter package listings before echoing them, and never
  inline `~/.local/share/metapac/machine-local.toml` contents into tracked files or issues.

## Last session (2026-07-07 → 08)

- **2.15 merged + live-validated** ([PR #81](https://github.com/amasover/dotfiles/pull/81), closes #63):
  alpm removal hook (yay Lua has no removal event) de-declares uninstalled packages; /etc symlink
  installed; raw `pacman -R gnu-netcat` exercised it end-to-end. openbsd-netcat (its replacement)
  sits in the live inbox awaiting triage.
- **2.25 merged** (see In flight): unattended VM bootstrap died on repo-vs-AUR dotnet providers;
  development.toml now declares the official extra stack. `~/code/ness` (the sole .NET 6 pin) deleted
  by Aaron — no dotnet-sdk-6.0 needed. Decision record on #82.
- 2.20/2.24 wrapped (✅); STATUS re-trimmed twice after the #72 conflict resolution re-added rehomed
  narrative; conflict-marker residue dropped from the 2.24 epic section.
- Ticketed: **2.26** ([#83](https://github.com/amasover/dotfiles/issues/83)) bootstrap determinism,
  [#85](https://github.com/amasover/dotfiles/issues/85) stale quarantine report reprinted by `update`
  when yay dies before the hook (root-caused from the 07-07 AUR RPC connection reset).

## Epics

| Epic | Scope | Phase |
| --- | --- | --- |
| [1](./epic-1-safety-inventory-live-home.md) | Safety inventory & live-home reconciliation | 1 |
| [2](./epic-2-bootstrap-and-package-modernization.md) | Bootstrap & package modernization | 2 |
| [3](./epic-3-shell-editor-desktop-cleanup.md) | Shell / editor / desktop cleanup | 3 |
| [4](./epic-4-workflow-and-governance.md) | Workflow & governance (operating model) | 1 |
