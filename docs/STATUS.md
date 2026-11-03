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

- **Mac work VM** (issue TBD; [decision-work-vm.md](./decision-work-vm.md),
  Epic 5 Story 5.8): first daily-driver rebuild target is now aarch64 Arch Ports
  under VMware Fusion, class `work-vm`, with `arch-*` adapter groups. Next: the
  Fusion harness run on macOS, then the LUKS `work-vm` install.

- **2.29 provisioning recipe** ([#95](https://github.com/amasover/dotfiles/issues/95)):
  one generator owns disposable QEMU/VMware recipes, the LUKS `daily-vm` recipe,
  and the attended metal recipe; `vmware-aarch64` and `work-vm` targets join it.
  The Windows daily-VM record is now a later, optional variant. Next: the
  `work-vm` creation record.

- **3.17** closed: the laptop is gone; its autorandr profiles and
  `.screenlayout` scripts are retired. Close [#129](https://github.com/amasover/dotfiles/issues/129).

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
