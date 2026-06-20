# YADM Legacy Upgrade and Local Git Runbook

## Purpose

This runbook covers the next Phase 1 cleanup step after the initial live-home reconciliation inventory: upgrade YADM's legacy data paths, keep local work committed in small checkpoints, and resume file-by-file reconciliation from a clearer baseline.

It is intentionally local-first. A GitHub PR workflow can come later; this step is about making the current machine recoverable and reviewable.

## Current evidence

- YADM version is `3.5.0`.
- Normal `yadm status` and `yadm diff --stat` currently fail with legacy-path detection.
- Read-only inspection works with explicit legacy flags:

```bash
yadm --yadm-data /home/aaron/.config/yadm --yadm-archive /home/aaron/.config/yadm/files.gpg status --short --branch
yadm --yadm-data /home/aaron/.config/yadm --yadm-archive /home/aaron/.config/yadm/files.gpg diff --stat
```

- The legacy YADM repo is on `test-laptop`, tracking `origin/test-laptop`, and is ahead by one commit.
- The normal checkout at `/home/aaron/code/dotfiles` is also on `test-laptop` and has untracked `.github/` and `docs/` plus an unrelated polybar modification.
- The normal checkout remote uses HTTPS; the legacy YADM remote uses SSH.

## Safety rules

- Do not run `yadm decrypt`, `yadm encrypt`, `yadm checkout`, `yadm reset`, or `yadm push` as part of the upgrade.
- Do not stage `.yadm/files.gpg` unless there is an intentional encrypted-file update.
- Do not mix docs commits with live-home config reconciliation.
- Do not include the existing polybar drift in docs or runbook commits.
- Keep every commit small enough to revert independently.

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

Run only after explicit approval:

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

- Normal YADM commands no longer require explicit legacy flags.
- The tracked-file list is unchanged or any difference is understood.
- The same live-home drift remains available for reconciliation.
- No encrypted content is decrypted or printed.

## Local commit sequence

Use local Git checkpoints before remote workflow setup exists:

1. Commit safety instructions and planning docs.
2. Commit the YADM upgrade metadata only if the upgrade changes tracked metadata and the change is understood.
3. Commit reconciliation decisions by risk area: shell startup, polybar, Git/runtime basics, desktop, editor, helper scripts, package docs.
4. Keep encrypted payload updates isolated.

For the first docs commit from the normal checkout:

```bash
cd /home/aaron/code/dotfiles
git add .github docs
git diff --cached --check
git status --short --branch
git commit -m "Add dotfiles safety planning docs"
```

This intentionally excludes `.config/polybar/themes/nord-arrow/config` until polybar reconciliation reaches it.

## Local merge to main

After the docs commit exists on `test-laptop`, a local merge to `main` is reasonable if `main` exists and the branch relationship is understood:

```bash
cd /home/aaron/code/dotfiles
git branch --list
git log --oneline --decorate --graph --max-count=12 --all
git switch main
git merge --no-ff test-laptop
git status --short --branch
```

Do not push as part of this runbook unless explicitly requested after the local merge is reviewed.

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