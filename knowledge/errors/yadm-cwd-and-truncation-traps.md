# yadm from the repo checkout: cwd scoping + truncation traps

Four bites in one session (2026-08-23), same two roots. yadm's worktree is
`$HOME`, but agent shells usually sit in `~/code/dotfiles` — inside the
worktree, so commands *work* but pathspecs silently scope to the subtree.

## Trap 1: pathspec/cwd scoping (three variants)

- `yadm ls-files | grep ...` from the repo cwd lists only files under
  `~/code/dotfiles` → "0 matches" read as "not tracked" (led to a wrong
  `powerline-fonts` declaration on 2026-08-22, and a wrong "no .omp files
  tracked" reading on 08-23).
- `yadm log -- .config/...` and `yadm diff -- .config/...` with relative
  pathspecs from the repo cwd match nothing → empty history/diff read as
  "untouched"/"stale status cache" (masked REAL dirty files before a merge).
- **Rule: run yadm queries from `$HOME` (`cd ~ && yadm ...`) or use absolute
  pathspecs, and treat an empty yadm answer as suspect until re-run from
  `$HOME`.**

## Trap 2: `| tail -1` on merge/checkout output

`yadm merge --ff-only origin/main 2>&1 | tail -1` showed `Updating
af4d7b4..eefc1d0` while the merge had ABORTED — stdout/stderr interleaving
put git's "error: untracked working tree files would be overwritten" +
"Aborting" lines where the truncation hid them. The session then reported a
convergence that hadn't happened, and a pre-merge `rm` of a live file (made
on the assumption the merge would restore it) left omp with no models.yml.

**Rule: never truncate the output of a mutating git/yadm command; verify
with `yadm log --oneline -1` (did HEAD move?) + `yadm status --short` from
`$HOME`, not with the command's own tail.**
