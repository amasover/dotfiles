# YADM Legacy Upgrade and Local Git Runbook

## Purpose

This runbook covers the next Phase 1 cleanup step after the initial live-home reconciliation inventory: upgrade YADM's legacy data paths, keep local work committed in small checkpoints, and resume file-by-file reconciliation from a clearer baseline.

It is intentionally local-first, but story branches should be PR-ready. GitHub boards and issues are not required for this repo right now.

## Current evidence

- YADM version is `3.5.0`.
- Normal `yadm status` and `yadm diff --stat` previously failed with legacy-path detection.
- Before upgrade, read-only inspection worked with explicit legacy flags:

```bash
yadm --yadm-data /home/aaron/.config/yadm --yadm-archive /home/aaron/.config/yadm/files.gpg status --short --branch
yadm --yadm-data /home/aaron/.config/yadm --yadm-archive /home/aaron/.config/yadm/files.gpg diff --stat
```

- The legacy YADM repo is on `test-laptop`, tracking `origin/test-laptop`, and is ahead by one commit.
- The normal checkout at `/home/aaron/code/dotfiles` is also on `test-laptop` and has untracked `.github/` and `docs/` plus an unrelated polybar modification.
- The normal checkout remote uses HTTPS; the legacy YADM remote uses SSH.

## Upgrade result

YADM legacy paths were upgraded on 2026-06-20.

Observed moves:

```text
/home/aaron/.config/yadm/repo.git -> /home/aaron/.local/share/yadm/repo.git
/home/aaron/.config/yadm/files.gpg -> /home/aaron/.local/share/yadm/archive
```

Post-upgrade verification:

- Normal `yadm status --short --branch` works without explicit legacy flags.
- Normal `yadm diff --stat` works without explicit legacy flags.
- `yadm list -a` returned 421 tracked files before and after the upgrade.
- The tracked-file list changed only by replacing `.config/yadm/files.gpg` with `.local/share/yadm/archive`.
- The YADM repo committed the archive rename as `7fc6fb6` with message `Upgrade YADM data paths`.
- Remaining YADM drift is the previously inventoried live-home reconciliation set.

## Safety rules

- Do not run `yadm decrypt`, `yadm encrypt`, `yadm checkout`, `yadm reset`, or `yadm push` as part of the upgrade.
- Do not stage `.yadm/files.gpg` unless there is an intentional encrypted-file update.
- Do not mix docs commits with live-home config reconciliation.
- Do not include the existing polybar drift in docs or runbook commits.
- Keep every commit small enough to revert independently.
- Use a dedicated branch for each story before editing.
- Do not push, open a PR, merge to `main`, or run YADM remote operations unless Aaron explicitly asks for that step.

## Pre-upgrade checklist

Run these before approving or executing the upgrade:

```bash
cd /home/aaron/code/dotfiles
git status --short --branch
git branch --show-current
git remote -v

yadm --yadm-data /home/aaron/.config/yadm --yadm-archive /home/aaron/.config/yadm/files.gpg status --short --branch
yadm --yadm-data /home/aaron/.config/yadm --yadm-archive /home/aaron/.config/yadm/files.gpg diff --stat
yadm --yadm-data /home/aaron/.config/yadm --yadm-archive /home/aaron/.config/yadm/files.gpg list -a > /tmp/dotfiles-yadm-list-before-upgrade.txt
```

Expected result:

- The current branch and remote are known for both the normal checkout and YADM.
- The pre-upgrade modified/deleted file list is recorded.
- No secret-bearing detailed diff is printed.

## Upgrade step

This was run only after explicit approval:

```bash
yadm upgrade
```

Do not combine this with any other YADM mutation.

## Post-upgrade verification

After the upgrade, verify normal YADM commands work:

```bash
yadm status --short --branch
yadm diff --stat
yadm list -a > /tmp/dotfiles-yadm-list-after-upgrade.txt
diff -u /tmp/dotfiles-yadm-list-before-upgrade.txt /tmp/dotfiles-yadm-list-after-upgrade.txt
```

Expected result:

- Normal YADM commands no longer require explicit legacy flags. Completed.
- The tracked-file list is unchanged except for the expected encrypted archive path move. Completed.
- The same live-home drift remains available for reconciliation. Completed.
- No encrypted content is decrypted or printed. Completed.

## Local commit sequence

Use local Git checkpoints on the active story branch:

1. Create or switch to a branch named for the story, for example `story/1.6-yadm-legacy-upgrade-workflow`.
2. Commit safety instructions and planning docs.
3. Commit the YADM upgrade metadata only if the upgrade changes tracked metadata and the change is understood.
4. Commit reconciliation decisions by risk area: shell startup, polybar, Git/runtime basics, desktop, editor, helper scripts, package docs.
5. Keep encrypted payload updates isolated.

For the first docs commit from the normal checkout:

```bash
cd /home/aaron/code/dotfiles
git add .github docs
git diff --cached --check
git status --short --branch
git commit -m "Add dotfiles safety planning docs"
```

This intentionally excludes `.config/polybar/themes/nord-arrow/config` until polybar reconciliation reaches it.

## Push and PR path

When Aaron asks to publish the story branch, push it and create a PR against `main`:

```bash
cd /home/aaron/code/dotfiles
git status --short --branch
git log --oneline --decorate --graph --max-count=12 --all
git push -u origin story/1.6-yadm-legacy-upgrade-workflow
gh pr create --base main --head story/1.6-yadm-legacy-upgrade-workflow
```

The PR should include the story title, summary, validation, secret-safety notes, YADM impact, live-home comparison notes, and known follow-up work.

## Local merge to main

After the story PR is reviewed or Aaron explicitly asks for a local merge, merging to `main` is reasonable if `main` exists and the branch relationship is understood:

```bash
cd /home/aaron/code/dotfiles
git branch --list
git log --oneline --decorate --graph --max-count=12 --all
git switch main
git merge --no-ff story/1.6-yadm-legacy-upgrade-workflow
git status --short --branch
```

Do not push `main` as part of this runbook unless explicitly requested after the local merge is reviewed.

## Reconciliation order after upgrade

Resume from the Story 1.2 priority list:

1. Shell startup files: `.zshrc`, `.profile`, `.bashrc`, `.bash_profile`, `.zsh_plugins.sh`, `.zsh_plugins.txt`
2. Polybar files: `.config/polybar/config`, `.config/polybar/launch.sh`, `.config/polybar/themes/global/modules`, `.config/polybar/themes/nord/config`, `.config/polybar/themes/nord-arrow/config`
3. Git and runtime basics: `.gitconfig`, `.gitignore`, `.nvmrc`
4. Desktop/session files: `.xinitrc`, `.config/i3/config`, `.config/rofi/config.rasi`, GTK config files
5. Editor files: `.vimrc`, `.spacemacs`, `.config/Code/User/settings.json`
6. Helper scripts under `.local/bin/setup/` and `.local/bin/tools/`
7. Repo docs and metadata

## Done when

- YADM normal commands work or the upgrade is explicitly deferred.
- The docs and safety artifacts are committed locally without unrelated config drift.
- The first post-upgrade reconciliation target is selected from the priority list.
- Any local merge into `main` has been reviewed before push or PR workflow setup.