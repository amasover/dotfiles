# Recipe: clean YADM pull without scanning all untracked home files

Use when `$HOME` has tracked drift and many unrelated untracked files.

## Goal

Fast-forward YADM's `main` without overwriting live work or asking `yadm stash`
to walk every untracked home-directory tree.

## Procedure

1. Confirm branch, tracked drift, and remote distance. Hide untracked files: they
   may include large or permission-restricted application state.

   ```bash
   yadm branch --show-current
   yadm status --short --untracked-files=no
   yadm fetch origin main
   yadm rev-list --left-right --count HEAD...origin/main
   ```

   Continue only from `main` with zero local commits ahead of `origin/main`.

2. Preserve tracked edits only. Do **not** use `--include-untracked` / `-u`.

   ```bash
   yadm stash push -m 'pre-main-pull-YYYY-MM-DD'
   ```

3. Fast-forward without a merge commit.

   ```bash
   yadm pull --ff-only
   ```

   If Git names untracked paths that would be overwritten, move exactly those
   paths into one temporary holding directory, preserving their relative paths.
   Do not stash every untracked file.

   ```bash
   hold=$(mktemp -d /tmp/yadm-prepull-XXXXXX)
   mkdir -p "$hold/<parent>"
   mv <blocking-path> "$hold/<parent>/"
   yadm pull --ff-only
   ```

4. Verify tracked home is clean and current.

   ```bash
   yadm status --short --untracked-files=no
   yadm rev-list --left-right --count HEAD...origin/main
   ```

   Expected: no status output, then `0 0`.

5. Compare every moved blocker to its new tracked replacement before deleting
   the holding directory. Keep the directory until the comparison passes.

   ```bash
   cmp "$hold/<path>" "$HOME/<path>"
   ```

6. Inspect the stashed tracked edits against the newly pulled `main`. A path
   printed below was not captured upstream; leave the stash intact until its
   change is deliberately promoted, restored, or dropped.

   ```bash
   yadm diff --name-only HEAD 'stash@{0}' -- <stashed-paths>
   yadm diff 'stash@{0}^1' 'stash@{0}' -- <stashed-paths>
   ```

## Invariants

- Never run bare `sudo` while investigating package state.
- Never use `yadm reset`, `checkout`, or `stash pop` to force a clean pull.
- Never delete the temporary holding directory or a stash until every moved and
  stashed change has an explicit disposition.
