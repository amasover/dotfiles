# Recipe: Secret Scan Before Commit and PR

**PRD/FR:** FR-2 (Secret Safety and YADM Encryption) — [docs/prd.md](../../docs/prd.md)
**Epic/Story:** Story 1.4 — [docs/epic-1-safety-inventory-live-home.md](../../docs/epic-1-safety-inventory-live-home.md)
**Resolves:** OQ-5 (Which secret scan tool should be standard for this repo?)

A repeatable secret scan to run before staging commits and before pushing or
opening a pull request, so cleanup of this repo does not publish credentials,
tokens, SSH material, or private machine data. This repo maps into `$HOME`
through YADM and stores local secrets in an encrypted payload, so secret hygiene
is a release gate.

## Standard scanner: `betterleaks` (fallback: `gitleaks`)

`betterleaks` is the standard secret scanner for this repo (Story 4.8, #117;
it replaced `gitleaks`, which resolved OQ-5 and remains the accepted fallback).
Rationale:

- Successor to gitleaks from the same maintainers, including the original
  author; gitleaks itself is no longer where detection improvements land.
- Drop-in compatible where it matters here: reads gitleaks config files and
  `.gitleaksignore`, same `dir`/`git` scan syntax, redacted output
  (`--redact`).
- Scans both working tree and full Git history — the real risk here is
  historical exposure across ~1000 commits, not just the current diff.

Known divergence: betterleaks has **no `protect` subcommand**, so the staged
scan is `git diff --staged | betterleaks stdin` (the hook's form, below). A
`stdin` scan reports different fingerprints than `protect` did — when
dismissing a false positive, take the fingerprint from a `dir`/`git` JSON
report, not from hook output.

Install: `winget install Betterleaks.Betterleaks` (Windows). On Arch it
installs from the repo's **vendored PKGBUILD** (Story 2.46 —
`.config/dotfiles/pkgbuilds/betterleaks/`, applied by bootstrap step 6d or
`tools/custom-pkgs sync`); it is still not in the official repos, and the
same-named AUR package is a third party's build guarded against via pacman's
IgnorePkg — never install betterleaks from the AUR or declare it in a metapac
group. `gitleaks` (`pacman -S gitleaks`, declared in `security.toml`) remains
the accepted fallback on machines that predate the vendored package. If
neither scanner is installed, use the manual fallback below and ask Aaron to
install one. Do not install automatically without approval.

## Enforced automatically: pre-commit hook (Story 4.4, #35; betterleaks-first since 4.8, #117)

The staged-changes scan runs automatically on every commit via the tracked hook
[.githooks/pre-commit](../../.githooks/pre-commit). It prefers
`git diff --staged | betterleaks stdin --redact --no-banner`, falls back to
`gitleaks protect --staged --redact --no-banner` where only gitleaks exists,
and blocks the commit on any finding; with no scanner installed it fails loudly
with the install steps instead of passing silently. Scanner selection is
covered by [tests/pre-commit-hook.clitest.txt](../../tests/pre-commit-hook.clitest.txt).

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

## Enforced automatically: encrypted-archive staleness guard (Story 4.9, #122)

The scanners guard what you publish; this guards what you forget to publish.
[.config/yadm/hooks/pre_push](../../.config/yadm/hooks/pre_push) aborts
`yadm push` when a file matching `.config/yadm/encrypt` is newer than
`.local/share/yadm/archive` — the drift that left the AUR trust baseline
declared in the manifest but absent from the archive for a month, so a fresh
machine's decrypt restored no trust state.

Unlike the pre-commit hook, this needs no `core.hooksPath`: yadm runs
`~/.config/yadm/hooks/pre_<command>` whenever it exists and is executable, so
the `yadm checkout` that places the file also enables it. Confirm with
`test -x ~/.config/yadm/hooks/pre_push && echo enabled`.

It compares timestamps only — it never runs `yadm encrypt`, never reads the
listed files, and reports a glob as a count instead of expanded filenames
(a `.ssh/**` name can carry a private hostname). When it fires:

```bash
yadm encrypt                              # interactive passphrase prompt
yadm add ~/.local/share/yadm/archive
yadm commit -m "yadm: refresh encrypted archive"
```

Because the check is mtime-based, a fresh clone can raise a false positive; the
cost is one `yadm encrypt`, which is the right direction to fail. Bypass a
single push with `YADM_SKIP_ENCRYPT_CHECK=1 yadm push`. Behavior is covered by
[tests/encrypt-staleness.clitest.txt](../../tests/encrypt-staleness.clitest.txt).

## Steps

All commands are read-only. Run from the repo checkout (`$DOTFILES_CHECKOUT`).

1. **Before staging a commit — staged changes only** (the pre-commit hook runs
   this for you where enabled):

   ```bash
   git diff --staged | betterleaks stdin --redact --no-banner
   # fallback: gitleaks protect --staged --redact --no-banner
   ```

2. **Before pushing or opening a PR — working tree:**

   ```bash
   betterleaks dir . --redact --no-banner
   # fallback: gitleaks dir . --redact --no-banner
   ```

3. **Periodically or before publishing history — full Git history:**

   ```bash
   betterleaks git . --redact --no-banner
   # fallback: gitleaks git . --redact --no-banner
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
   (`betterleaks dir . --redact --report-format json --report-path /tmp/bl.json`).
   Use a `dir`/`git` report, not hook output — `stdin` scans carry different
   fingerprints.
2. Add the fingerprint to `.gitleaksignore` at the repo root, with a comment
   stating the reason and date:

   ```
   # 2026-06-23 — sample key in docs, not a real credential (Aaron)
   <fingerprint>
   ```

Never dismiss a finding without a written reason. If it is unclear whether a
finding is real, treat it as real until proven otherwise and ask Aaron.

**Testing the hook with a planted secret:** the default config allowlists
values containing `EXAMPLE`, so the canonical AWS docs key
(`AKIAIOSFODNN7EXAMPLE`) passes clean — a planted test secret must look real
(e.g. a random-suffix `ghp_…` GitHub PAT pattern). Verified 2026-07-09 against
the gitleaks-era hook: it blocked a realistic planted token and let clean
commits through. The betterleaks stdin path has not yet had a planted-secret
run — re-verify on the next convenient occasion.

## Scan evidence

| Date | Scope | Command | Commits | Result |
| --- | --- | --- | --- | --- |
| 2026-06-23 | Working tree | `gitleaks dir . --redact --no-banner` | n/a | No leaks found |
| 2026-06-23 | Full history | `gitleaks git . --redact --no-banner` | 1002 | No leaks found |
| 2026-08-09 | Working tree | `betterleaks dir . --redact --no-banner` (1.7.1, Windows clone) | n/a | No leaks found |

No findings, so no false-positive dismissals were needed and no `.gitleaksignore`
file exists yet. Re-run the working-tree and staged scans before each commit
batch and record notable results in the PR description.
