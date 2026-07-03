# Error pattern: `git push -u origin <branch>` lands on `main` (push.default=upstream)

**Observed:** 2026-07-02, while pushing `story/2.5-grill-amendments` — the push output
read `745683a..6e7990b story/2.5-grill-amendments -> main` and commit `6e7990b` landed
directly on `origin/main`, bypassing PR review (accepted after the fact; content was
docs-only and reviewed live).

## Mechanism

Three ingredients, all present in this checkout:

1. Global `push.default = upstream`.
2. The branch was created with `git checkout -b <branch> origin/main`, which sets its
   upstream to `origin/main`.
3. `git push -u origin <branch>` then resolves the destination from the branch's
   *upstream* — `refs/heads/main` — not from the branch's own name.

No warning is shown; the only tell is the `-> main` in the push output.

## Prevention

- **Always push a new story branch with an explicit destination refspec:**

  ```bash
  git push origin <branch>:refs/heads/<branch>
  git branch --set-upstream-to=origin/<branch> <branch>
  ```

- Or avoid creating the branch with upstream tracking `origin/main`
  (`git checkout -b <branch> origin/main --no-track`).
- Read the push output before considering the push done — `-> main` means trouble.
- **Durable fix landed (2026-07-02, approved via reverse-test):** `.gitconfig` now sets
  `push.default = simple`, which refuses this push instead of mis-routing it
  (yadm commit `b7a7f67`). The explicit-refspec habit above remains good practice.

## If it happens again

`git push --force-with-lease=main:<bad-tip> origin <good-tip>:main` restores main
exactly and only if nothing else moved it — but that is a destructive remote action:
**stop and ask Aaron first** (Hard rule 3).
