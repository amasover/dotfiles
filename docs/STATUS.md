# Status — session entry point

Disposable handoff for active work. GitHub issues own durable detail; the
[Projects board](https://github.com/users/amasover/projects/1/views/1) owns status.

## Keep this file cheap

- Keep one brief entry per story actually moving: current state, detail link,
  and next step or blocker.
- Nothing lives only here. Remove paused, merged, or closed work.
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

- **3.30 Spacemacs modernization** ([#210](https://github.com/amasover/dotfiles/issues/210)):
  active in another agent session. Preserve Spacemacs, Vim-style interaction,
  and established workflows while modernizing tracked `.spacemacs`.
  Known defects: near-total warning suppression, disabled GC, overwritten YAML
  schemas, stray prints, stale/duplicate integrations, and hardcoded paths.
  Next: capture batch/GUI behavior, timing, warnings, and memory baseline; then
  make evidence-backed fixes and rerun the same checks. Live config or package
  changes require separate approval and a rollback copy.

## Standing warning

- Chat transcripts are sensitive. Never publish org package names, work email,
  or `~/.local/share/metapac/machine-local.toml` contents.
