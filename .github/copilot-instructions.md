# Dotfiles — Copilot Instructions

## What this repo is

This repository is a personal workstation platform, not just a bag of dotfiles.

It should support four outcomes at the same time:

1. Make the current daily workstation correct and pleasant to use.
2. Preserve enough automation to rebuild a similar environment on a fresh Linux machine.
3. Keep older Arch, i3, rofi, polybar, Spacemacs, Vim, and YADM-era assets understandable without extending obsolete patterns blindly.
4. Provide a safe, AI-assisted maintenance model for future cleanup.

The repo is managed with YADM, so many tracked paths map directly into the live home directory.

---

## Core surfaces

| Surface | Typical paths | Purpose |
| --- | --- | --- |
| Shell config | `.zshrc`, `.bashrc`, `.profile`, `.zprofile` | Interactive shell behavior, aliases, environment setup |
| Editor config | `.vimrc`, `.spacemacs`, `.config/nvim/`, `.config/Code/` | Editor defaults and plugin configuration |
| Desktop config | `.xinitrc`, `.Xresources`, `.config/i3/`, `.config/polybar/`, `.config/rofi/`, `.config/dunst/`, `.screenlayout/` | Linux desktop/session behavior |
| Bootstrap scripts | `.local/bin/setup/`, `.local/bin/tools/`, `install.md` | Install, update, helper, and migration scripts |
| Package lists | `.config/dotfiles/arch-packages/` | Historical Arch package manifests and future curated install inputs |
| Local package inventory | live package manager output from `/home/aaron`'s machine | Evidence for deciding which packages are still needed, optional, stale, or missing from bootstrap |
| YADM metadata | `.yadm/encrypt`, `.yadm/files.gpg` | Encryption manifest and encrypted secret payload |
| Product docs | `README.md`, `docs/` | Product framing, PRD, epics, runbooks, and cleanup decisions |
| Agent knowledge | `knowledge/`, `.github/skills/` | Durable repo-specific guidance, reusable workflows, and task skills for future AI-assisted maintenance |

---

## Hard rules

### 1. Check repo state against the live home directory

Before changing any tracked dotfile, script, package list, or desktop/editor config, compare the repo version with the live file under `/home/aaron` when the live file exists.

Examples:

- Repo `.zshrc` maps to `/home/aaron/.zshrc`
- Repo `.config/i3/config` maps to `/home/aaron/.config/i3/config`
- Repo `.local/bin/tools/foo` maps to `/home/aaron/.local/bin/tools/foo`

Use the live home directory as current-state evidence, not as automatic truth. If repo and live home differ, state the difference and decide deliberately whether to adopt, ignore, archive, or document the live change.

Do not overwrite live-home behavior casually. This repo is intended to converge with the real workstation over time.

### 2. Never expose or commit decrypted secrets

YADM can encrypt files. This repo already uses that model.

- Treat `.yadm/encrypt` as the source of truth for encrypted paths.
- Treat `.yadm/files.gpg` as an encrypted artifact, not as inspectable content.
- Never print decrypted secret file contents into chat, docs, logs, or generated files.
- Never copy secrets from `/home/aaron` into plaintext tracked files.
- Never add raw contents from paths covered by `.yadm/encrypt` into normal repo files.
- If a new sensitive file is needed, add the path pattern to `.yadm/encrypt` and regenerate the encrypted payload with YADM instead of committing plaintext.

Known encrypted/sensitive path patterns include:

- `.aws/**`
- `.ssh/**`
- `.zshenv`
- `.mysql/workbench/connections.xml`
- `.cobra.yaml`
- `.pypirc`

If a task touches credentials, tokens, SSH config, cloud auth, package publishing, API keys, or private hostnames, pause and do a secret-safety review first.

### 3. Do not run destructive workstation commands without explicit approval

Default to read-only inspection, docs, and small edits.

Do not run any command that installs packages, removes packages, changes system services, mutates YADM state, changes Git remotes, decrypts secrets, rewrites the home directory, restarts the desktop session, or modifies cloud/local credentials unless explicitly approved.

Examples requiring explicit approval:

- `yadm reset`, `yadm checkout`, `yadm decrypt`, `yadm encrypt`, `yadm push`
- `pacman -S`, `pacman -R`, `yay`, `trizen`, `pip install`, `npm install -g`
- `systemctl enable`, `systemctl start`, `systemctl restart`
- scripts under `.local/bin/setup/` when they perform installs or system mutations

### 4. Preserve legacy context, but do not extend stale patterns by default

This repo has older Arch/i3-era assumptions. They are useful context, not automatically the future direction.

When touching legacy areas:

- Prefer documenting current status over pretending everything still works.
- Keep working legacy assets if they still support the current machine or future rebuilds.
- Archive or delete clearly dead assets only after checking live-home usage and Git/YADM history.
- Do not extend obsolete tools or workflows only because they exist.
- Prefer small, understandable modules and scripts over large brittle install flows.

### 5. Local package cleanup is collaborative

Package cleanup should inventory the current machine first, then ask targeted questions about package groups instead of assuming what should stay or go.

- Prefer read-only package inventory commands before editing package manifests.
- Compare live installed packages against `.config/dotfiles/arch-packages/`.
- Group packages by purpose: core, shell, editor, desktop, development, cloud, media, gaming, optional, unknown, and remove-candidate.
- Ask Aaron about specific ambiguous packages or groups before removing them from install scripts.
- It is acceptable to ask Aaron to install a package needed for this cleanup work, but never install it automatically without approval.
- Do not remove packages from the live machine as part of documentation or inventory work.

### 6. Product docs should guide cleanup

Use `docs/` for product-level planning artifacts:

- `docs/prd.md` for product vision, goals, MVP, requirements, risks, and open questions.
- `docs/epic-*.md` for backlog-ready cleanup work.
- `docs/runbook-*.md` or `docs/*-runbook.md` for repeatable workflows.
- `docs/decision-*.md` for durable decisions when a cleanup choice is non-obvious.

If code behavior and docs disagree, say so plainly. Treat code and live-home files as current-state evidence; treat docs as target direction.

### 7. Skills and knowledge should preserve reusable lessons

Use `knowledge/` and `.github/skills/` when a cleanup lesson should survive the current chat.

- Use `knowledge/reference/` for repo-specific facts, workflows, conventions, and operating notes.
- Use `knowledge/errors/` for repeatable failure patterns and troubleshooting guidance.
- Use `knowledge/recipes/` for step-by-step cleanup, reconciliation, or validation workflows.
- Use `knowledge/examples/` for concrete examples worth reusing later.
- Use `.github/skills/` only when a repeatable task needs a structured, invokable agent skill.

Keep knowledge entries concise, evidence-based, and linked to the relevant docs or files when possible. Prefer updating an existing knowledge note over duplicating the same guidance in multiple places.

### 8. Use one branch and PR per story

Cleanup work should be story-scoped, branch-based, and PR-ready.

- When starting a new story, create or switch to a dedicated branch before editing. Use names like `story/1.6-yadm-legacy-upgrade-workflow` or `story/2.1-classify-setup-scripts`.
- Keep each branch focused on one story or one explicitly approved slice of a story.
- Commit as work progresses, but keep commits scoped by risk area: docs, YADM metadata, shell config, desktop config, package inventory, bootstrap scripts, or encrypted payload updates.
- Push the story branch to Aaron's GitHub repo when the local scope is ready for review.
- Prepare one GitHub pull request per story. The PR description should include the story, summary, validation performed, secret-safety notes, live-home comparison notes, and follow-up work.
- This repo does not currently use GitHub boards or issues for story tracking. Do not invent issue numbers or board updates.
- Do not merge to `main` or push to a remote unless Aaron explicitly asks for that step in the current task.

---

## Default investigation order

Before proposing or making changes, inspect in this order:

1. The relevant repo file under `../dotfiles`.
2. The matching live-home file under `/home/aaron`, if it exists.
3. YADM state with read-only commands such as `yadm status` and `yadm diff --stat`, when approved or provided by the user.
4. Related docs such as `README.md`, `install.md`, `TODO.org`, and files under `docs/`.
5. Relevant repo knowledge under `knowledge/` and task skills under `.github/skills/`.
6. Nearby scripts, package lists, or config directories.
7. Secret/encryption coverage in `.yadm/encrypt` if the area may contain sensitive data.
8. Current branch and PR scope when the task maps to a story.

Do not infer the active workstation setup from old README content alone.

---

## Cleanup strategy

Use a staged cleanup model.

### Phase 1: Safety and inventory

- Capture YADM status and unsynced changes.
- Identify untracked, modified, deleted, and stale files.
- Compare high-impact repo files against `/home/aaron`.
- Inventory locally installed packages with read-only commands when available.
- Run or request a secret scan before staging commits.
- Confirm encrypted paths in `.yadm/encrypt` still cover sensitive local files.

### Phase 2: Product docs and operating model

- Create or refresh `docs/prd.md`.
- Create initial epics and runbooks.
- Define what is current, legacy-supported, archived, and deleted.

### Phase 3: Shell and tool modernization

- Clean duplicated shell aliases and functions.
- Separate machine-specific, secret, and portable shell concerns.
- Keep `.zshenv` encrypted if it contains local secrets.
- Prefer documented plugin management over implicit dependencies.

### Phase 4: Bootstrap modernization

- Make install/update scripts safe, idempotent, and dry-run capable.
- Split package manifests into core, shell, editor, desktop, development, cloud, media, gaming, optional, unknown, and legacy/remove-candidate groups.
- Use guided package triage with Aaron to decide what still belongs in bootstrap.
- Avoid one giant install script that mutates everything without checkpoints.

### Phase 5: Desktop/editor cleanup

- Preserve active desktop/editor config.
- Archive inactive configs with notes, or delete after validation.
- Keep screenshots and old docs only if they explain supported workflows or historical context.

---

## Validation expectations

For docs-only changes:

- Check Markdown readability.
- Ensure links are relative and point to existing or intentionally planned files.
- Keep assumptions and open questions explicit.

For shell scripts:

- Prefer `shellcheck` when available.
- Run syntax-only validation where safe, for example `bash -n <script>`.
- Do not execute install/update scripts unless explicitly approved.

For shell config:

- Prefer syntax checks where possible.
- Validate against live-home behavior before changing aliases, PATH, plugin setup, or environment variables.
- Do not remove an alias or function until checking whether it exists in the live home config and whether it is still used.

For YADM and secrets:

- Review `yadm status` before staging.
- Review `yadm diff --stat` before detailed diffs.
- Do not show diffs for files likely to contain secrets.
- Run `yadm encrypt` only with explicit approval.
- Stage `.yadm/files.gpg` only when the encryption manifest and intended encrypted changes are understood.

For package/bootstrap changes:

- Prefer dry-run and diffable manifests.
- Use read-only local package inventory as evidence before changing package lists.
- Ask targeted questions about ambiguous packages instead of guessing.
- Do not install/remove packages as validation unless explicitly approved.
- Mark old package assumptions such as Antergos, yaourt, trizen, i3-gaps-era packages, or deprecated AUR packages as requiring verification.

---

## Writing style

- Be direct and concise.
- Prefer concrete file paths and commands over generic advice.
- Separate current-state facts from assumptions.
- Call out risk plainly.
- Do not over-modernize without evidence.
- Do not turn personal preferences into generic best practices unless the repo supports them.

---

## What to avoid

- Do not commit plaintext secrets.
- Do not expose decrypted YADM content.
- Do not assume old Arch/i3 install docs are still accurate.
- Do not assume the repo matches `/home/aaron` without checking.
- Do not run bootstrap scripts as tests.
- Do not rewrite large config files when a small targeted cleanup is safer.
- Do not delete legacy assets solely because they look old.
- Do not add new package managers, frameworks, or config managers without a documented decision.

---

## Useful read-only commands

Only run commands after considering whether the user has approved command execution for the task.

```bash
yadm status
yadm diff --stat
yadm ls-files
find /home/aaron -maxdepth 2 -name '.zshrc' -o -name '.bashrc' -o -name '.profile'
bash -n /home/aaron/.local/bin/setup/install
pacman -Qqe
pacman -Qqm
```

For secret scanning, prefer a tool already available on the machine. If no scanner is installed, recommend one instead of installing it automatically.
