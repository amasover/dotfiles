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

- **2.56 pacstrap metal installer** ([#253](https://github.com/amasover/dotfiles/issues/253)):
  active on `story/2.56-pacstrap-metal-installer`. `install-on-metal` now installs
  directly with `pacstrap` and owns the metal preflight and finalize steps;
  `provision-seed` is an Archinstall recipe printer for the three VM targets only.
  The volume group is named for the host, the target mounts under `/run`, and no
  credential ever reaches disk. Two traps the engine change exposed: Arch's default
  HOOKS is systemd-based, where `encrypt` is inert and `cryptdevice=` is ignored,
  and `refind-config` only derives `resume=UUID=` when the live command line
  carries no `resume=`. One full `metal-rehearsal run` passes, hibernate included.
  Next: PR review; then 2.57 builds the portable shape on top.

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
