# Recipe: Secret Scan Before Commit and PR

**PRD/FR:** FR-2 (Secret Safety and YADM Encryption) — [docs/prd.md](../../docs/prd.md)
**Epic/Story:** Story 1.4 — [docs/epic-1-safety-inventory-live-home.md](../../docs/epic-1-safety-inventory-live-home.md)
**Resolves:** OQ-5 (Which secret scan tool should be standard for this repo?)

A repeatable secret scan to run before staging commits and before pushing or
opening a pull request, so cleanup of this repo does not publish credentials,
tokens, SSH material, or private machine data. This repo maps into `$HOME`
through YADM and stores local secrets in an encrypted payload, so secret hygiene
is a release gate.

## Standard scanner: `gitleaks`

`gitleaks` is the standard secret scanner for this repo. Rationale:

- Already installed on the current workstation; no new dependency for Release 1.
- Scans both working tree and full Git history — the real risk here is
  historical exposure across ~1000 commits, not just the current diff.
- Redacted output (`--redact`) lets findings be reviewed and reported without
  printing the secret itself.
- In-repo allowlist (`.gitleaksignore`) keeps documented false positives
  dismissed across runs and machines.

If `gitleaks` is not installed, use the manual fallback below and ask Aaron to
install it (`pacman -S gitleaks` or equivalent). Do not install it
automatically without approval.

## Enforced automatically: pre-commit hook (Story 4.4, #35)

The staged-changes scan runs automatically on every commit via the tracked hook
[.githooks/pre-commit](../../.githooks/pre-commit). It runs
`gitleaks protect --staged --redact --no-banner` and blocks the commit on any
finding; if `gitleaks` is missing it fails loudly with the install step instead
of passing silently.

Enable it per repo with a repo-local `core.hooksPath` (never `--global` — that
would hijack hooks in every other repo under `$HOME`):

```bash
# working clone (~/code/dotfiles)
git config core.hooksPath .githooks

# YADM repo — run after a yadm checkout has placed ~/.githooks
yadm gitconfig core.hooksPath .githooks
```

Both settings live in each repo's own config, so unrelated home-directory Git
work is untouched. The relative path resolves against the worktree top: the
clone finds `.githooks/` at the repo root, YADM finds `~/.githooks/` (the same
tracked file, checked out by YADM).

Bypass for a single commit with `git commit --no-verify` — only after running
the scan manually. False positives are dismissed via `.gitleaksignore` (below),
which the hook respects.

## Steps

All commands are read-only. Run from the repo checkout (`$DOTFILES_CHECKOUT`).

1. **Before staging a commit — staged changes only** (the pre-commit hook runs
   this for you where enabled):

   ```bash
   gitleaks protect --staged --redact --no-banner
   ```

2. **Before pushing or opening a PR — working tree:**

   ```bash
   gitleaks dir . --redact --no-banner
   ```

3. **Periodically or before publishing history — full Git history:**

   ```bash
   gitleaks git . --redact --no-banner
   ```

Exit code `0` means no findings. Non-zero means findings exist — review before
continuing. Add `--report-format json --report-path <file>` for machine-readable
evidence.

**Scan the repo, not `$HOME`.** Never point the scanner at decrypted secrets or
live `$HOME` secret files. The encrypted payload (`.local/share/yadm/archive`,
formerly `.config/yadm/files.gpg`) is opaque binary to the scanner, which is
correct — the goal is to catch *plaintext* leaks in tracked files, not to inspect
intentionally encrypted material.

## Manual fallback (no scanner installed)

Weaker stopgap using `ripgrep` against the working tree:

```bash
rg -i --hidden -g '!.git' -g '!*.gpg' -g '!archive' \
  -e 'aws_secret_access_key' \
  -e 'BEGIN [A-Z ]*PRIVATE KEY' \
  -e 'api[_-]?key' \
  -e 'password\s*=' \
  -e 'token\s*=' \
  -e 'xox[baprs]-'      # Slack tokens
```

Then manually confirm the known sensitive surfaces are encrypted or excluded,
never tracked as plaintext. Patterns currently covered by the encrypt manifest
at [.config/yadm/encrypt](../../.config/yadm/encrypt):

- `.aws/**`
- `.ssh/**`
- `.zshenv`
- `.mysql/workbench/connections.xml`
- `.cobra.yaml`
- `.pypirc`

If a new credential-bearing file is about to be tracked as plaintext, stop: add
the pattern to the encrypt manifest and regenerate the encrypted payload with
YADM instead.

## Handling false positives

When a finding is a confirmed false positive, dismiss it durably and record why:

1. Get the fingerprint from a JSON report
   (`gitleaks dir . --redact --report-format json --report-path /tmp/gl.json`).
2. Add the fingerprint to `.gitleaksignore` at the repo root, with a comment
   stating the reason and date:

   ```
   # 2026-06-23 — sample key in docs, not a real credential (Aaron)
   <fingerprint>
   ```

Never dismiss a finding without a written reason. If it is unclear whether a
finding is real, treat it as real until proven otherwise and ask Aaron.

**Testing the hook with a planted secret:** gitleaks' default config allowlists
values containing `EXAMPLE`, so the canonical AWS docs key
(`AKIAIOSFODNN7EXAMPLE`) passes clean — a planted test secret must look real
(e.g. a random-suffix `ghp_…` GitHub PAT pattern). Verified 2026-07-09: the
hook blocked a realistic planted token and let clean commits through.

## Scan evidence

| Date | Scope | Command | Commits | Result |
| --- | --- | --- | --- | --- |
| 2026-06-23 | Working tree | `gitleaks dir . --redact --no-banner` | n/a | No leaks found |
| 2026-06-23 | Full history | `gitleaks git . --redact --no-banner` | 1002 | No leaks found |

No findings, so no false-positive dismissals were needed and no `.gitleaksignore`
file exists yet. Re-run the working-tree and staged scans before each commit
batch and record notable results in the PR description.
