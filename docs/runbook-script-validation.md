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
| `shfmt` | Canonical formatting (diff-only in validation, never auto-applied wholesale) | **Not installed yet** — install with `pacman -S shfmt` when approved |

Validation-time invocations:

```bash
# lint — all bash/sh scripts under the two script dirs
shellcheck --format=gcc .local/bin/setup/bootstrap .local/bin/setup/vm-harness .local/bin/tools/*

# formatting drift, once shfmt is installed (read-only diff)
shfmt -d .local/bin/setup/bootstrap .local/bin/setup/vm-harness .local/bin/tools/*
```

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

## Re-running / updating the baseline

1. Run the shellcheck invocation above; compare against this table.
2. A story that cleans up a script updates its row (or removes it) in the same
   PR and links the story issue.
3. Formatting baseline via `shfmt -d` is a follow-up once shfmt is installed
   (tracked on #36).
