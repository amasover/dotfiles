# Validation and Release Workflow

## Purpose

This runbook defines the safe path for changing and syncing the `dotfiles` repo.

The workflow is intentionally conservative because this repo maps directly into `$HOME` through YADM and may include encrypted local secrets.

---

## Safety principles

1. Inspect before editing.
2. Compare repo files against `$HOME` before changing active config.
3. Review YADM status before staging.
4. Use `yadm diff --stat` before detailed diffs.
5. Never print decrypted secrets.
6. Never commit plaintext secrets.
7. Do not run install/update/bootstrap scripts as validation unless explicitly approved.
8. Isolate encrypted payload changes from normal config cleanup.
9. Inventory local packages before changing package manifests or install scripts.
10. Ask targeted package questions instead of guessing what should stay or go.
11. Prefer small commits by risk area.
12. Use one branch and one pull request per story.

---

## Release 1 validation checklist

### 1. Confirm repo and live-home context

Run or request these read-only checks:

```bash
yadm status
yadm diff --stat
yadm ls-files | sort > /tmp/dotfiles-yadm-files.txt
```

Expected outcome:

- Modified, deleted, untracked, and staged files are known.
- High-impact changed files are identified before detailed review.
- No secret-bearing diff is printed casually.

---

### 2. Compare high-impact files against `$HOME`

For any file being changed, compare the repo path and live path.

Examples:

```bash
diff -u $DOTFILES_CHECKOUT/.zshrc $HOME/.zshrc
diff -u $DOTFILES_CHECKOUT/.bashrc $HOME/.bashrc
diff -u $DOTFILES_CHECKOUT/.profile $HOME/.profile
diff -u $DOTFILES_CHECKOUT/.vimrc $HOME/.vimrc
```

For directories, start with file lists before content diffs:

```bash
find $DOTFILES_CHECKOUT/.config/i3 -type f | sort
find $HOME/.config/i3 -type f | sort
```

Expected outcome:

- Differences are classified as adopt repo, adopt live, merge, archive, delete, or unknown.
- Machine-specific files are documented before being changed.

---

### 3. Secret-safety review

Review the encryption manifest:

```bash
cat $DOTFILES_CHECKOUT/.yadm/encrypt
```

Known encrypted path patterns:

- `.aws/**`
- `.ssh/**`
- `.zshenv`
- `.mysql/workbench/connections.xml`
- `.cobra.yaml`
- `.pypirc`

Before staging commits:

- Check whether changed files may contain tokens, private keys, credentials, private hostnames, or account identifiers.
- Use a secret scanning tool if available.
- If no scanner is available, manually review likely hotspots.
- Do not print decrypted files.
- Do not run `yadm decrypt` unless explicitly approved.
- Do not run `yadm encrypt` unless an intentional encrypted-file change is ready.

Suggested scanner options to evaluate later:

- `gitleaks`
- `trufflehog`
- `detect-secrets`

Do not install a scanner automatically as part of validation.

---

### 4. Docs validation

For docs-only changes:

- Confirm Markdown renders clearly.
- Confirm relative links point to existing files or intentionally planned files.
- Confirm assumptions and open questions are explicit.
- Confirm no private values are embedded.

Useful check:

```bash
find $DOTFILES_CHECKOUT/docs -type f -name '*.md' -print | sort
```

---

### 5. Shell and script validation

For shell config and scripts, prefer syntax checks over execution.

Examples:

```bash
bash -n $DOTFILES_CHECKOUT/.local/bin/setup/install
bash -n $DOTFILES_CHECKOUT/.local/bin/setup/update
find $DOTFILES_CHECKOUT/.local/bin/tools -type f -maxdepth 1 -print
```

If `shellcheck` is available:

```bash
shellcheck $DOTFILES_CHECKOUT/.local/bin/setup/install
```

Do not execute setup scripts as tests unless explicitly approved.

---

### 6. Local package inventory and triage

Package cleanup should start with read-only inventory.

For Arch/pacman systems:

```bash
pacman -Qqe > /tmp/dotfiles-pacman-explicit.txt
pacman -Qqm > /tmp/dotfiles-pacman-foreign.txt
comm -23 <(sort /tmp/dotfiles-pacman-explicit.txt) <(sort /tmp/dotfiles-pacman-foreign.txt) > /tmp/dotfiles-pacman-native-explicit.txt
```

Then compare the inventory to repo manifests:

```bash
comm -23 <(sort /tmp/dotfiles-pacman-native-explicit.txt) <(sort $DOTFILES_CHECKOUT/.config/dotfiles/arch-packages/pacman) > /tmp/dotfiles-installed-not-in-repo.txt
comm -13 <(sort /tmp/dotfiles-pacman-native-explicit.txt) <(sort $DOTFILES_CHECKOUT/.config/dotfiles/arch-packages/pacman) > /tmp/dotfiles-repo-not-installed.txt
comm -23 <(sort /tmp/dotfiles-pacman-foreign.txt) <(sort $DOTFILES_CHECKOUT/.config/dotfiles/arch-packages/aur) > /tmp/dotfiles-foreign-not-in-repo.txt
comm -13 <(sort /tmp/dotfiles-pacman-foreign.txt) <(sort $DOTFILES_CHECKOUT/.config/dotfiles/arch-packages/aur) > /tmp/dotfiles-aur-repo-not-installed.txt
```

Classify packages into:

- core
- shell
- editor
- desktop
- development
- cloud
- media
- gaming
- optional
- machine-local
- unknown
- legacy
- remove-candidate

Ask Aaron questions by group first. Only ask about individual packages when the package is ambiguous or high-impact.

Do not install or remove packages during inventory unless explicitly approved.

---

### 7. Bootstrap dry-run expectations

Current setup scripts should be treated as inspect-only until classified.

A future bootstrap command should support at least one of:

- `--dry-run`
- `--check`
- `--plan`
- explicit checkpoint prompts before package install, service changes, YADM mutation, or secret restore

Until that exists, bootstrap validation is documentation and syntax-only.

---

### 8. Story branch and PR workflow

Use a story branch before making story-scoped edits:

```bash
cd $DOTFILES_CHECKOUT
git status --short --branch
git switch -c story/<story-id>-<short-summary>
```

Branch naming examples:

- `story/1.6-yadm-legacy-upgrade-workflow`
- `story/2.1-classify-setup-scripts`
- `story/3.1-shell-config-cleanup`

Expected outcome:

- The branch contains one story or one explicitly approved slice of a story.
- Unrelated live-home drift remains unstaged unless that story is reconciling it.
- Commit messages and PR descriptions can explain the story scope without relying on GitHub issue IDs.

When the branch is ready for remote review, push and create a PR only after Aaron asks for it or confirms that the local branch is ready:

```bash
git push -u origin story/<story-id>-<short-summary>
gh pr create --base main --head story/<story-id>-<short-summary>
```

PR description checklist:

- Story ID and title
- Summary of changes
- Validation performed
- Secret-safety review result
- Live-home comparison notes for active dotfiles
- YADM/encrypted payload impact, if any
- Known follow-up work

This repo does not currently use GitHub boards or issues for story tracking. Do not invent issue numbers, close issues, or update project boards.

---

### 9. Commit sequencing

Use small commits in this order:

1. AI/repo safety instructions
2. Product docs and planning artifacts
3. Inventory/runbook docs
4. Secret hygiene changes
5. Live-home reconciliation changes
6. Shell config cleanup
7. Editor config cleanup
8. Desktop config cleanup
9. Package inventory and triage docs
10. Bootstrap/package modernization
11. Encrypted payload updates, isolated and explained

Avoid mixing `.yadm/files.gpg` changes with unrelated cleanup.

---

## Pre-commit checklist

Before any commit:

- [ ] Current branch matches the active story or approved cleanup slice
- [ ] `yadm status` reviewed
- [ ] `yadm diff --stat` reviewed
- [ ] High-impact files compared against `$HOME`
- [ ] Secret hotspots reviewed
- [ ] `.yadm/encrypt` impact checked
- [ ] No decrypted secret content included in docs, chat, logs, or commits
- [ ] Scripts syntax-checked if touched
- [ ] Package inventory reviewed before package manifest changes
- [ ] Ambiguous package removals reviewed with Aaron
- [ ] Bootstrap scripts not executed unless explicitly approved
- [ ] Commit scope is small and reversible

---

## Pre-PR privacy checklist

Before pushing a story branch or opening a PR:

- [ ] Confirm Git author and committer use Aaron's personal email for new commits
- [ ] Run a secret scan with redacted output, for example `gitleaks protect --staged --redact --no-banner` before commit and `gitleaks dir . --redact --no-banner` before PR
- [ ] Search for plaintext credentials, tokens, private keys, internal hostnames, local IPs, private URLs, and company-specific internal details
- [ ] Review docs and knowledge files for unnecessary personal, employer, client, or workstation-identifying details
- [ ] Move sensitive local-only material to ignored paths or YADM-encrypted paths instead of publishing it as plaintext
- [ ] Confirm `.gitignore` and `.yadm/encrypt` cover any newly identified local-only sensitive surfaces
- [ ] Include privacy and secret-safety results in the PR description

---

## When to stop and ask for explicit approval

Stop before:

- Running `yadm encrypt` or `yadm decrypt`
- Staging `.yadm/files.gpg`
- Running setup/install/update scripts
- Installing/removing packages
- Removing a package from bootstrap manifests when its purpose is unknown
- Changing system services
- Deleting legacy directories
- Rewriting `.zshrc`, editor config, or desktop config wholesale
- Touching files under encrypted path patterns
- Pushing a branch, opening a PR, or merging to `main` unless Aaron has asked for that step

---

## Release readiness definition

A cleanup batch is ready to commit when:

- The changed files have a clear purpose
- Live-home differences have been considered
- Secret exposure risk has been reviewed
- Validation appropriate to the file type has passed or blockers are documented
- The commit can be reverted without losing unrelated work
