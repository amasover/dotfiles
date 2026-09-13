# Status — session entry point

Disposable handoff for active work. GitHub issues own durable detail; the
[Projects board](https://github.com/users/amasover/projects/1/views/1) owns status.

## Keep this file cheap

- Keep one brief entry per story actually moving: current state, detail link,
  and next step or blocker.
- Prune before adding. The completing PR removes its story; paused or backlog work
  returns to the board.
- Keep the file near one screen; trim instead of appending history.

## Session basics

- `main` is trunk; `master` is retired. Branch from `main`, one story and PR per
  branch, and target `main` only.
- Read the relevant epic's **Stories** section after this file. Laptop-only live
  work is filtered in [laptop-only-work.md](./laptop-only-work.md).
- Before commits and pushes, run `betterleaks` per the
  [secret-scan recipe](../knowledge/recipes/secret-scan.md) and manually check for
  employer, personal, and host details.

## In flight

- **2.29 provisioning recipe** ([#95](https://github.com/amasover/dotfiles/issues/95)):
  active on `story/2.29-metal-provisioning`. One generator now owns disposable
  QEMU/VMware recipes, the LUKS-encrypted `daily-vm` recipe, and the attended
  LVM-on-LUKS/rEFInd recipe for a different blank laptop—never this workstation.
  Host-independent tests cover target selection, credentials, destructive preflight,
  and cleanup. Next: the required Windows-host daily-VM creation record; the later
  laptop run revalidates the metal path.

- **2.53 metal rehearsal harness** ([#247](https://github.com/amasover/dotfiles/issues/247)):
  `metal-rehearsal run` now proves the attended metal path end to end in
  user-owned QEMU from the working tree — install, rEFInd/storage handoff,
  reboot, real hibernate/resume — with stage exit codes and retained
  artifacts. `install-on-metal` is the one-command USB front door, and the
  generator is renamed `provision-seed`. Next: land the PR; the laptop run
  then revalidates the metal path.

- **3.17 monitor-name migration** ([#129](https://github.com/amasover/dotfiles/issues/129)):
  laptop and home-4K profiles now match current modesetting names; home split
  bars and workspace placement are live-verified. Story 5.5 already removed the
  obsolete `launch.sh` layout table, so remaining work is hardware profile
  capture, not launcher name replacement. Next: reconnect offsite work-4K,
  office, and DisplayLink setups; all remain relevant.

- **3.30 Spacemacs modernization** ([#210](https://github.com/amasover/dotfiles/issues/210)):
  active in another agent session. Preserve Spacemacs, Vim-style interaction,
  and established workflows while modernizing tracked `.spacemacs`.
  Known defects: near-total warning suppression, disabled GC, overwritten YAML
  schemas, stray prints, stale/duplicate integrations, and hardcoded paths.
  PR #215 landed first-start package ownership and the Origami exclusion; sync any
  active 3.30 branch from `main` before further `.spacemacs` edits.
  Next: capture batch/GUI behavior, timing, warnings, and memory baseline; then
  make evidence-backed fixes and rerun the same checks. Live config or package
  changes require separate approval and a rollback copy.

## Standing warning

- Chat transcripts are sensitive. Never publish org package names, work email,
  or `~/.local/share/metapac/machine-local.toml` contents.
