# Local Dotfiles Workflow

## Current operating model

- Treat `$DOTFILES_CHECKOUT` as the normal working checkout for docs and planning changes.
- Treat `$HOME` as the live YADM work tree for active dotfiles.
- Before changing an active dotfile, compare the checkout path with the matching live-home path.
- Keep docs/planning commits separate from live-home config reconciliation.

## YADM state

- YADM 3.5.0 was observed reporting legacy-path detection before upgrade.
- The legacy YADM paths were upgraded on 2026-06-20.
- Normal `yadm status`, `yadm diff --stat`, and `yadm list -a` now work without explicit legacy flags.
- The encrypted YADM archive moved from `.config/yadm/files.gpg` to `.local/share/yadm/archive` and was committed in the YADM repo as `9d93210`.
- If legacy-path inspection is needed for historical comparison, the old command shape was:

```bash
yadm --yadm-data $HOME/.config/yadm --yadm-archive $HOME/.config/yadm/files.gpg status --short --branch
yadm --yadm-data $HOME/.config/yadm --yadm-archive $HOME/.config/yadm/files.gpg diff --stat
```

- Do not run `yadm decrypt`, `yadm encrypt`, `yadm checkout`, `yadm reset`, or `yadm push` without explicit approval.

## Local commits

- Start each story on a dedicated branch, for example `story/1.6-yadm-legacy-upgrade-workflow`.
- Use one GitHub PR per story when Aaron is ready to push the branch; GitHub boards and issues are not part of the current workflow.
- Before pushing or opening a PR, run a privacy/sensitivity pass for secrets, personal details, company/internal details, private hostnames, local IPs, and other machine-specific plaintext.
- Commit as work progresses to keep recoverable checkpoints.
- Stage docs and repo knowledge explicitly; do not rely on broad `git add .` while live-home reconciliation is in progress.
- Leave unrelated drift, such as the current polybar change, unstaged until its reconciliation story reaches it.
- Do not push, create a PR, or merge to `main` unless Aaron asks for that step.

## Secret scanning

- Aaron is open to being asked to install local tooling or packages when validation would benefit from it.
- For secret scanning, prefer an installed scanner such as `gitleaks`; if no scanner is present, ask before installing one.
- Run a secret scan before committing docs or config changes.
- Keep scanner output redacted and avoid printing decrypted secret material.