# Runbook: Shell Script Validation (shellcheck + shfmt)

**Epic/Story:** Story 4.5 — [docs/epic-4-workflow-and-governance.md](./epic-4-workflow-and-governance.md)
**Issue:** [#36](https://github.com/amasover/dotfiles/issues/36)

Standard tooling for validating the repo's shell scripts, plus the recorded
baseline. Findings feed Epic 2 (script classification) and Story 3.4 (helper
script inventory) — they are **not** fixed blindly from here; a script gets its
findings addressed when its own cleanup story touches it.

## Standard tooling

| Tool | Role | Status |
| --- | --- | --- |
| `shellcheck` | Lint bash/sh scripts for correctness hazards | Installed (`/usr/bin/shellcheck`) |
| `shfmt` | Canonical formatting (diff-only in validation, never auto-applied wholesale) | Installed (v3.13.1, 2026-07-09) |

Validation-time invocations:

```bash
# lint — all bash/sh scripts under the two script dirs
shellcheck --format=gcc .local/bin/setup/bootstrap .local/bin/setup/vm-harness .local/bin/tools/*

# formatting drift (read-only diff) — flags are the repo's canonical style, see below
shfmt -i 4 -bn -ci -d .local/bin/setup/bootstrap .local/bin/setup/vm-harness .local/bin/tools/*
```

**Canonical shfmt style: `-i 4 -bn -ci`** — the flag set closest to how the
code is already written: 4-space indent (no tabs anywhere in the tree), binary
ops (`|`, `&&`) at line starts, indented `case` labels.

**Do not use `-kp` (keep-padding).** It initially looked attractive (kept
aligned trailing comments, smallest raw diff), but it is deprecated upstream
(removal planned — mvdan/sh#658) and it mangles one-liner blocks: shfmt always
expands `cmd && { a; b; }` onto multiple lines, and `-kp` then "aligns" the
statements to their old columns, producing absurd deep indentation. Caught in
PR #91's first formatting pass.

**Exclusion:** `.local/bin/setup/update` is a zsh script; shellcheck does not
support zsh. It stays validated by `zsh -n` only.

New or modified shell scripts in a PR should be shellcheck-clean; the baseline
below grandfathers existing findings until each script's own story.

## Baseline — 2026-07-09

17 bash/sh scripts scanned; **65 findings, 0 errors** (all warning/info/style).
Full output: comment on [#36](https://github.com/amasover/dotfiles/issues/36).

Clean (5): `bootstrap`, `vm-harness`, `check_for_arch_updates`,
`metapac-dedeclare`, `quick-git-check-in` — notably, every script written
during the current cleanup era.

| Script | Findings | Dominant issue |
| --- | --- | --- |
| `tools/yadm-checker.sh` | 20 | unused nord color vars (SC2034), unquoted expansions |
| `tools/dot-update` | 14 | unquoted expansions (SC2086), unchecked `cd` (SC2164) |
| `tools/polybar_alsa_module` | 11 | unquoted `[[ ]]` comparisons (SC2053), expansions |
| `tools/vendor_repos` | 6 | unquoted expansions |
| `tools/screenshot` | 3 | unquoted expansions |
| `squash`, `pulseaudio-tail.sh`, `metapac-drift-report`, `aur-quarantine` | 2 each | misc |
| `new_script`, `lock`, `dot-color` | 1 each | misc |

Aggregate by code: SC2086 unquoted expansion ×33, SC2034 unused variable ×15,
SC2053 unquoted `==` RHS ×4, rest ×1–2.

Reading of the baseline: findings concentrate in the legacy i3-era helpers
(`yadm-checker.sh`, `dot-update`, `polybar_alsa_module`), several of which are
already candidates for archive/replacement (e.g. Story 3.12 replaces the audio
tooling). That supports classify-then-decide over lint-fixing scripts that may
not survive cleanup.

## Formatting baseline (shfmt) — 2026-07-09

The 13 small-drift files (spacing/blank-line nits) were formatted in PR #91
itself with the canonical flags — validated by `bash -n` and an identical
shellcheck finding set before/after. Two deliberate exclusions remain, to be
formatted when their own stories touch them:

| Script | Changed lines / total | Why deferred |
| --- | --- | --- |
| `tools/aur-quarantine` | 160 / 199 | deliberate dense style — compact multi-statement one-liner functions that shfmt always expands; reformatting is a rewrite decision for its own story |
| `setup/vm-harness` | 102 / 642 | mixed 2-/4-space indent pockets; actively developed (2.21/2.22) — format inside the next story that touches it to avoid blame noise |

Everything else is `shfmt -i 4 -bn -ci` clean, and new or modified scripts in
a PR should stay that way.

## Regression tests (clitest) — adopted 2026-07-10

Lint checks that scripts are *written* safely; `tests/*.clitest.txt` checks
they *behave* correctly, via [clitest](https://github.com/aureliojargas/clitest)
(host-installed 2026-07-10):

```bash
# from the repo root
clitest tests/*.clitest.txt
```

- **Ship tests with new logic in the same commit/PR** (Aaron's standing
  preference): pytest-style tests for python-internal logic, clitest for
  shell seams — sed/awk filters, CLI flag handling, pass-through/pipeline
  guarantees, pty behavior (via `script(1)` inside a test).
- Design testable seams while writing — e.g. `vm-harness scrub` exposes the
  state-log filter as a subcommand precisely so tests can reach it.
- Tests must not depend on host state (no libvirt, no network); they are the
  natural payload for Story 4.7's minimal CI ([#94](https://github.com/amasover/dotfiles/issues/94)).
- Format gotchas (block termination with a lone `$`, one shared shell session
  per file): [knowledge/reference/clitest-shell-tests.md](../knowledge/reference/clitest-shell-tests.md).
- First suite: `tests/vm-harness.clitest.txt` (Story 2.21, PR #102) — scrub
  filters, display-tool pass-through, display-flag rejections.

## Re-running / updating the baseline

1. Run the shellcheck and shfmt invocations above; compare against the tables.
2. A story that cleans up a script updates its row (or removes it) in the same
   PR and links the story issue.
