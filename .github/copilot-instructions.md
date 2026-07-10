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
| Local package inventory | live package manager output from `$HOME`'s machine | Evidence for deciding which packages are still needed, optional, stale, or missing from bootstrap |
| YADM metadata | `.yadm/encrypt`, `.yadm/files.gpg` | Encryption manifest and encrypted secret payload |
| Product docs | `README.md`, `docs/` | Product framing, PRD, epics, runbooks, and cleanup decisions |
| Agent knowledge | `knowledge/`, `.github/skills/` | Durable repo-specific guidance, reusable workflows, and task skills for future AI-assisted maintenance |

---

## Hard rules

### 1. Check repo state against the live home directory

Before changing any tracked dotfile, script, package list, or desktop/editor config, compare the repo version with the live file under `$HOME` when the live file exists.

Examples:

- Repo `.zshrc` maps to `$HOME/.zshrc`
- Repo `.config/i3/config` maps to `$HOME/.config/i3/config`
- Repo `.local/bin/tools/foo` maps to `$HOME/.local/bin/tools/foo`

Use the live home directory as current-state evidence, not as automatic truth. If repo and live home differ, state the difference and decide deliberately whether to adopt, ignore, archive, or document the live change.

Do not overwrite live-home behavior casually. This repo is intended to converge with the real workstation over time.

**Sanctioned reverse-test workflow (ask first).** Aaron permits validating a change on the
live system *before* it goes through a repo PR, by working in the reverse direction:

1. **Ask Aaron first** for the specific change — this edits his live machine.
2. Edit the live file directly under `$HOME` (e.g. `~/.zshrc`) and confirm it actually works.
3. Once verified, promote it: `yadm add <path>`, `yadm commit`, `yadm push`.
4. Bring it back into the working repo with `git pull`.

This lets changes be tested on the real workstation before a PR. It is the only sanctioned
path that runs `yadm add/commit/push` (still gated by Hard rule 3's approval requirement),
and it must be deliberate and careful — it mutates the live system. Never do it silently or
without Aaron's go-ahead for that specific change.

### 2. Never expose or commit decrypted secrets

YADM can encrypt files. This repo already uses that model.

- Treat `.config/yadm/encrypt` as the source of truth for encrypted paths.
- Treat `.yadm/files.gpg` as an encrypted artifact, not as inspectable content.
- Never print decrypted secret file contents into chat, docs, logs, or generated files.
- Never copy secrets from `$HOME` into plaintext tracked files.
- Never add raw contents from paths covered by `.yadm/encrypt` into normal repo files.
- If a new sensitive file is needed, add the path pattern to `.config/yadm/encrypt` and regenerate the encrypted payload with YADM instead of committing plaintext.
- Run a secret scan before staging commits and before pushing or opening a PR. The standard scanner is `gitleaks`; follow the [secret scan recipe](../knowledge/recipes/secret-scan.md), which also documents the manual fallback and false-positive handling. Keep scanner output redacted.
- The staged-changes scan is enforced by a tracked pre-commit hook (`.githooks/pre-commit`) in repos where `core.hooksPath .githooks` is set — but do not rely on it: fresh clones don't have it enabled (setup in the recipe), and it covers only the staged diff at commit time. The pre-PR working-tree scan and the privacy pass below stay manual.
- **`gitleaks` is necessary but never sufficient.** It matches credential-shaped patterns, not privacy leaks. Always pair it with a deliberate **manual privacy pass** — read the actual diff by eye for work/personal email, real names, employer or client names, internal hostnames, local IPs, and paths that reveal a workplace or project. A clean `gitleaks` run does not clear any of these; do not treat scanner output as a substitute for reading the diff.

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

Before starting work, consult existing entries under `knowledge/` and reuse the relevant recipe or reference instead of re-deriving it. Use `knowledge/` and `.github/skills/` when a cleanup lesson should survive the current chat.

- Use `knowledge/reference/` for repo-specific facts, workflows, conventions, and operating notes.
- Use `knowledge/errors/` for repeatable failure patterns and troubleshooting guidance.
- Use `knowledge/recipes/` for step-by-step cleanup, reconciliation, or validation workflows.
- Use `knowledge/examples/` for concrete examples worth reusing later.
- Use `.github/skills/` only when a repeatable task needs a structured, invokable agent skill.

Keep knowledge entries concise, evidence-based, and linked to the relevant docs or files when possible. Prefer updating an existing knowledge note over duplicating the same guidance in multiple places.

### 8. Use one issue, branch, and PR per story

Cleanup work is story-scoped and tracked on the GitHub Projects board, which is
the source of truth for status.

**Tracking model — one fact, one home:**

- Story **status** (todo / in-progress / done), dates, and discussion live on the [GitHub Projects board](https://github.com/users/amasover/projects/1/views/1) and its issues — not in the `.md` files.
- Story **spec** (objective, acceptance criteria, scope) lives in the epic `.md` under `docs/`.
- The issue and the epic `.md` **link** to each other; they do not duplicate each other. Do not add live status (todo / in-progress / blocked) or status checkboxes to the `.md` once an issue exists — the board owns anything still moving.
- **Terminal-state exception:** when a story is finished (issue closed), append ` ✅` to its epic `.md` heading and `(closed, PR #N)` to its `Issue:` line, in the same wrap-up commit that updates STATUS. Done is immutable, so this duplicates nothing that can drift; an unmarked story means "check the board".

**Workflow:**

- When starting a story, open a GitHub issue, add it to the board, and link it from the matching epic `.md` story with a one-line `Issue: #N` pointer.
- Create or switch to a dedicated branch before editing. Use names like `story/4.2-consolidate-trunk` or `story/2.1-classify-setup-scripts`.
- Keep each branch focused on one story or one explicitly approved slice of a story.
- Commit as work progresses, but keep commits scoped by risk area: docs, YADM metadata, shell config, desktop config, package inventory, bootstrap scripts, or encrypted payload updates.
- Do not add `Co-Authored-By` trailers or other AI-attribution lines to commit messages **or PR descriptions** (e.g. no "Generated with Claude Code" footer).
- Push the story branch and open one GitHub pull request per story, referencing its issue. The PR description should include the story, summary, validation performed, secret-safety notes, live-home comparison notes, and follow-up work.
- **Always open PRs against `main`. Never create stacked/dependent PRs** (a PR based on another story branch). A stacked PR previously merged into its dead base branch instead of `main`, so the work never reached `main`. If new work seems to depend on an unmerged branch, either wait for that branch to merge to `main` first, or keep the new work self-contained so it can branch off `main` cleanly.
- Before pushing or opening a PR, run a privacy/sensitivity pass for secrets, personal details, company/internal details, private hostnames, local IPs, and other machine-specific data. Keep sensitive files local, encrypted through YADM, or ignored; do not publish them as plaintext.
- **When you finish a meaningful chunk of work** (open or merge a PR, land a decision, complete a story slice), update [docs/STATUS.md](../docs/STATUS.md) so the next session can orient: refresh the **In flight** and **Last session** notes, and ✅-mark any story heading whose issue closed (see the terminal-state exception above). Keep STATUS itself to session narrative — live per-story status still lives on the board.
- `main` is the trunk. Do not merge to `main` or push to a remote unless Aaron explicitly asks for that step in the current task.

---

## Default investigation order

Start every session by reading [docs/STATUS.md](../docs/STATUS.md) — it names the trunk branch, the tracking board, and what work is in flight, so you can orient without re-reading `prd.md` and every epic. Read only the relevant epic's **Stories** section, not the whole epic.

Before proposing or making changes, inspect in this order:

1. The relevant repo file under `../dotfiles`.
2. The matching live-home file under `$HOME`, if it exists.
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
- Compare high-impact repo files against `$HOME`.
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
- Run a secret scan (`gitleaks`, per `knowledge/recipes/secret-scan.md`) before staging commits and before opening a PR. The pre-commit hook (`.githooks/pre-commit`) enforces the staged scan where enabled; the pre-PR working-tree scan stays manual.
- Always pair the scan with a manual privacy pass by eye (see Hard rule 2). `gitleaks` finding nothing does not clear personal, employer, or machine-specific details — read the diff yourself.
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
- Do not assume the repo matches `$HOME` without checking.
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
find $HOME -maxdepth 2 -name '.zshrc' -o -name '.bashrc' -o -name '.profile'
bash -n $HOME/.local/bin/setup/install
pacman -Qqe
pacman -Qqm
```

For secret scanning, prefer a tool already available on the machine. If no scanner is installed, recommend one instead of installing it automatically.

## Plain words, not jargon

Don't use jargon-as-shorthand. Say what you actually mean.

- Don't say "load-bearing assumptions". Say "the assumptions the xyz depends on".

- Don't say "cross-service". Name both services, e.g. "whether the X service can derive duration without calling the Y service". "Cross-X" is confusing because it hides which things are involved.

- Don't deliver verdicts as abstract noun-phrases like "Cross-RCA double-counting is unfounded". Say it plainly: "I checked whether the same root cause gets counted twice across RCA runs, and it doesn't."

## No earth-shattering declarations

Don't hype findings. Skip "a critical finding changes everything", "now I have the full picture", "this changes the game", etc. Just state what you found plainly. Most findings are ordinary; report them that way.

## Don't reflexively hedge a "yes"

When the answer is yes, say yes. Don't soften every positive answer with a caveat: it erodes confidence in the "yes". Only add a caveat when there's a genuine, specific uncertainty worth flagging.