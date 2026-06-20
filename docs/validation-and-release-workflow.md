# Validation and Release Workflow

## Purpose

This runbook defines the safe path for changing and syncing the `dotfiles` repo.

The workflow is intentionally conservative because this repo maps directly into `/home/aaron` through YADM and may include encrypted local secrets.

---

## Safety principles

1. Inspect before editing.
2. Compare repo files against `/home/aaron` before changing active config.
3. Review YADM status before staging.
4. Use `yadm diff --stat` before detailed diffs.
5. Never print decrypted secrets.
6. Never commit plaintext secrets.
7. Do not run install/update/bootstrap scripts as validation unless explicitly approved.
8. Isolate encrypted payload changes from normal config cleanup.
9. Inventory local packages before changing package manifests or install scripts.
10. Ask targeted package questions instead of guessing what should stay or go.
11. Prefer small commits by risk area.

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

### 2. Compare high-impact files against `/home/aaron`

For any file being changed, compare the repo path and live path.

Examples:

```bash
diff -u /home/aaron/code/dotfiles/.zshrc /home/aaron/.zshrc
diff -u /home/aaron/code/dotfiles/.bashrc /home/aaron/.bashrc
diff -u /home/aaron/code/dotfiles/.profile /home/aaron/.profile
diff -u /home/aaron/code/dotfiles/.vimrc /home/aaron/.vimrc
```

For directories, start with file lists before content diffs:

```bash
find /home/aaron/code/dotfiles/.config/i3 -type f | sort
find /home/aaron/.config/i3 -type f | sort
```

Expected outcome:

- Differences are classified as adopt repo, adopt live, merge, archive, delete, or unknown.
- Machine-specific files are documented before being changed.

---

### 3. Secret-safety review

Review the encryption manifest:

```bash
cat /home/aaron/code/dotfiles/.yadm/encrypt
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
find /home/aaron/code/dotfiles/docs -type f -name '*.md' -print | sort
```

---

### 5. Shell and script validation

For shell config and scripts, prefer syntax checks over execution.

Examples:

```bash
bash -n /home/aaron/code/dotfiles/.local/bin/setup/install
bash -n /home/aaron/code/dotfiles/.local/bin/setup/update
find /home/aaron/code/dotfiles/.local/bin/tools -type f -maxdepth 1 -print
```

If `shellcheck` is available:

```bash
shellcheck /home/aaron/code/dotfiles/.local/bin/setup/install
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
comm -23 <(sort /tmp/dotfiles-pacman-native-explicit.txt) <(sort /home/aaron/code/dotfiles/.config/dotfiles/arch-packages/pacman) > /tmp/dotfiles-installed-not-in-repo.txt
comm -13 <(sort /tmp/dotfiles-pacman-native-explicit.txt) <(sort /home/aaron/code/dotfiles/.config/dotfiles/arch-packages/pacman) > /tmp/dotfiles-repo-not-installed.txt
comm -23 <(sort /tmp/dotfiles-pacman-foreign.txt) <(sort /home/aaron/code/dotfiles/.config/dotfiles/arch-packages/aur) > /tmp/dotfiles-foreign-not-in-repo.txt
comm -13 <(sort /tmp/dotfiles-pacman-foreign.txt) <(sort /home/aaron/code/dotfiles/.config/dotfiles/arch-packages/aur) > /tmp/dotfiles-aur-repo-not-installed.txt
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

### 8. Commit sequencing

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

- [ ] `yadm status` reviewed
- [ ] `yadm diff --stat` reviewed
- [ ] High-impact files compared against `/home/aaron`
- [ ] Secret hotspots reviewed
- [ ] `.yadm/encrypt` impact checked
- [ ] No decrypted secret content included in docs, chat, logs, or commits
- [ ] Scripts syntax-checked if touched
- [ ] Package inventory reviewed before package manifest changes
- [ ] Ambiguous package removals reviewed with Aaron
- [ ] Bootstrap scripts not executed unless explicitly approved
- [ ] Commit scope is small and reversible

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

---

## Release readiness definition

A cleanup batch is ready to commit when:

- The changed files have a clear purpose
- Live-home differences have been considered
- Secret exposure risk has been reviewed
- Validation appropriate to the file type has passed or blockers are documented
- The commit can be reverted without losing unrelated work
