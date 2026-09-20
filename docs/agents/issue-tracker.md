# Issue tracker: GitHub

Issues and specs for this repo live as GitHub issues on `amasover/dotfiles`. Use the `gh`
CLI for all operations; it infers the repo from `git remote -v` when run inside the clone.

## Tracking model

This repo already has a tracking model, set by "Hard rule 8" in `CLAUDE.md`. The skills
work inside it, they do not replace it:

- **Status** (todo / in-progress / done), dates, and discussion live on the
  [GitHub Projects board](https://github.com/users/amasover/projects/1/views/1) and its
  issues. Never in `.md` files.
- **Spec** (objective, acceptance criteria, scope) lives in the epic `.md` under `docs/`.
- The issue and the epic `.md` link to each other with a one-line `Issue: #N` pointer;
  they do not duplicate each other.

So "publish to the issue tracker" means: create the GitHub issue, add it to the board,
and add the `Issue: #N` pointer to the matching epic story. One issue, one branch, one PR.

## Conventions

- **Create an issue**: `gh issue create --title "..." --body "..."`. Use a heredoc for
  multi-line bodies.
- **Read an issue**: `gh issue view <number> --comments`.
- **List issues**: `gh issue list --state open --json number,title,body,labels,comments --jq '[.[] | {number, title, body, labels: [.labels[].name], comments: [.comments[].body]}]'`,
  with `--label` / `--state` filters as needed.
- **Comment**: `gh issue comment <number> --body "..."`
- **Apply / remove labels**: `gh issue edit <number> --add-label "..."` / `--remove-label "..."`
- **Close**: `gh issue close <number> --comment "..."`

Story issues are titled `Story <epic>.<n>: <summary>` to match the epic `.md` files.

## When a skill says "fetch the relevant ticket"

Run `gh issue view <number> --comments`.

## Blocking dependencies

Used by `to-tickets`, which publishes tickets in dependency order and needs each one's
blocking edges as real identifiers.

GitHub's **native issue dependencies** are the canonical, UI-visible representation. Add
an edge with:

```shell
gh api --method POST repos/amasover/dotfiles/issues/<blocked>/dependencies/blocked_by \
  -F issue_id=<blocker-db-id>
```

`<blocker-db-id>` is the blocker's numeric **database id**
(`gh api repos/amasover/dotfiles/issues/<n> --jq .id`), not its `#number` or `node_id`.
GitHub reports open blockers as `issue_dependencies_summary.blocked_by`, which is the live
gate. Where dependencies aren't available, fall back to a `Blocked by: #<n>, #<n>` line at
the top of the blocked issue's body. A ticket is unblocked when every blocker is closed.

## Pull requests as a triage surface

**PRs as a request surface: no.** _(Set to `yes` if this repo starts treating external PRs
as feature requests; `triage` reads this flag.)_

GitHub shares one number space across issues and PRs, so a bare `#42` may be either:
resolve with `gh pr view 42` and fall back to `gh issue view 42`.

## Merging is not yours to do

Opening or pushing a PR never authorizes merging it. See `CLAUDE.md` Hard rule 8: after CI
is green, stop, report the ready PR, and wait. Only the docs-only direct-to-`main`
exception in that rule bypasses a PR.
