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
shfmt -i 4 -bn -ci -kp -d .local/bin/setup/bootstrap .local/bin/setup/vm-harness .local/bin/tools/*
```

**Canonical shfmt style: `-i 4 -bn -ci -kp`** — chosen empirically as the flag
set with the least drift against the existing scripts (322 changed lines total
vs 481 for bare `-i 4`), matching how the code is already written rather than
imposing a new style: 4-space indent (no tabs anywhere in the tree), binary ops
(`|`, `&&`) at line starts, indented `case` labels, comment-alignment padding
kept.

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

`shfmt -i 4 -bn -ci -kp -l` over the same 17 scripts: 14 differ, 322 changed
lines total, almost all concentrated in two files:

| Script | Changed lines / total | What the drift is |
| --- | --- | --- |
| `tools/aur-quarantine` | 149 / 199 | deliberate dense style — compact multi-statement one-liner functions that shfmt always expands; reformatting is a rewrite decision for its own story |
| `setup/vm-harness` | 75 / 642 | mixed 2-/4-space indent pockets |
| `tools/polybar_alsa_module` | 21 / 157 | misc |
| remaining 11 files | ≤ 19 each | trivial (blank-line/spacing nits); `lock`, `dot-update`, `quick-git-check-in` already clean |

Same rule as lint findings: formatting is applied when a script's own story
touches it, never as a wholesale reformat pass. New scripts should be
`shfmt -i 4 -bn -ci -kp` clean.

## Re-running / updating the baseline

1. Run the shellcheck and shfmt invocations above; compare against the tables.
2. A story that cleans up a script updates its row (or removes it) in the same
   PR and links the story issue.
