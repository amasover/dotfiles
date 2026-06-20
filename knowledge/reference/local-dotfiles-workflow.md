# Local Dotfiles Workflow

## Current operating model

- Treat `/home/aaron/code/dotfiles` as the normal working checkout for docs and planning changes.
- Treat `/home/aaron` as the live YADM work tree for active dotfiles.
- Before changing an active dotfile, compare the checkout path with the matching live-home path.
- Keep docs/planning commits separate from live-home config reconciliation.

## YADM state

- YADM 3.5.0 was observed reporting legacy-path detection before upgrade.
- Until upgraded, read-only YADM inspection can use:

```bash
yadm --yadm-data /home/aaron/.config/yadm --yadm-archive /home/aaron/.config/yadm/files.gpg status --short --branch
yadm --yadm-data /home/aaron/.config/yadm --yadm-archive /home/aaron/.config/yadm/files.gpg diff --stat
```

- Do not run `yadm decrypt`, `yadm encrypt`, `yadm checkout`, `yadm reset`, or `yadm push` without explicit approval.

## Local commits

- Start each story on a dedicated branch, for example `story/1.6-yadm-legacy-upgrade-workflow`.
- Use one GitHub PR per story when Aaron is ready to push the branch; GitHub boards and issues are not part of the current workflow.
- Commit as work progresses to keep recoverable checkpoints.
- Stage docs and repo knowledge explicitly; do not rely on broad `git add .` while live-home reconciliation is in progress.
- Leave unrelated drift, such as the current polybar change, unstaged until its reconciliation story reaches it.
- Do not push, create a PR, or merge to `main` unless Aaron asks for that step.

## Secret scanning

- Aaron is open to being asked to install local tooling or packages when validation would benefit from it.
- For secret scanning, prefer an installed scanner such as `gitleaks`; if no scanner is present, ask before installing one.
- Run a secret scan before committing docs or config changes.
- Keep scanner output redacted and avoid printing decrypted secret material.