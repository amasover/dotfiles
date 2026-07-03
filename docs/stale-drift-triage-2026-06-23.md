# Stale Drift Triage — test-laptop lineage (2026-06-23)

**Story:** Epic 3, Story 3.6 · **Issue:** [#10](https://github.com/amasover/dotfiles/issues/10)

## What this is

Local `main` had diverged from `origin/main`: the `test-laptop` branch (older local-machine state) was merged into local main, plus a few local commits, while `origin/main` carried the real reconciliation work (Stories 1.8/1.9). Local main was undiverged back to `origin/main`. The stale lineage is preserved for review:

- branch **`archive/stale-test-laptop-main`** (pushed to origin)
- tag **`pre-undiverge-local-main`** (commit `b5c123d`)

Inspect any file with:

```bash
git diff main archive/stale-test-laptop-main -- <path>      # main vs archive
git show archive/stale-test-laptop-main:<path>              # archive version
```

The split point (merge-base) is `19a7a7e` (2026-06-20), so this is days of drift, not years.

## Verdict

`main` wins for almost everything — it is the actively-maintained, *this-machine* state (it even intentionally commented out test-laptop's `WIFI_DEVICE`). The archive is older **but contains a few deliberate decisions and a short list of genuinely useful bits worth salvaging.**

> ⚠️ **Diff alone cannot distinguish "stale" from "deliberately removed."** Every **Drop** item that is a *removal* needs Aaron's confirmation.

### Already correct on `main` (intentional decisions, no action)

`main`'s `.config/yadm/encrypt` is already Aaron's intended state — verified with `git show main:.config/yadm/encrypt`:

```
.ssh/**
.zshenv
.config/Code/User/settings.json
```

| Item | Status |
| --- | --- |
| `.aws/**`, `.mysql/workbench/connections.xml`, `.cobra.yaml`, `.pypirc` removed from the manifest | **Already done on `main`** — deliberate (no longer needed); the underlying files are also absent in live `$HOME`. The *archive* is the old version that still listed them. |
| `.config/Code/User/settings.json` encrypted (it held an API key) | **Already done on `main`** — listed in the manifest, not tracked as plaintext. The *archive* is the old insecure version that tracked it as plaintext. Nothing to salvage; if anything, ensure it's included in the encrypted archive via `yadm encrypt`. |

### Outcomes (line-by-line review with Aaron, 2026-06-23)

| File | Decision |
| --- | --- |
| `.local/bin/setup/update` sudo-keepalive | **Salvaged** into `main`. |
| `.local/bin/setup/update` pip-review + `.config/pip/pip.conf user=true` | **Dropped** — Aaron uninstalled `pip-review`; recoverable from the archive later. |
| `.local/bin/tools/lock` (Spotify-stop + DPMS idle-off) | **Dropped** — Aaron switched to `xidlehook`. Spun off [Story 3.7](https://github.com/amasover/dotfiles/issues/14) for the xidlehook-on-boot issue. |
| `.gitignore` | **No action** — `main` is already the superset (`*.~undo-tree~*`, `**.cecli`, `TODO.org`). The archive's is the *smaller* one. (Earlier triage note had this backwards.) |
| `.config/dotfiles/arch-packages/` (`antibody`, `linux-headers`, `sbsigntools`, `reflector-timer`; drop `vim`) | **Deferred to Epic 2** package triage (hard rule 5: live-install check + targeted Qs). |
| `.config/Code/User/settings.json` | **No action** — already correctly encrypted on `main` (in manifest, not plaintext). |
| `.config/yadm/encrypt` removals (`.aws/.mysql/.cobra/.pypirc`) | **No action** — already removed on `main` (intended state; files absent in live `$HOME`). |
| i3 vim-style focus keys, `.profile` `BROWSER` | Optional preference — not pursued. |

### Drop (`main` newer / this-machine-correct / superseded)

`.spacemacs` (archive 567 lines smaller — ancient), `.vimrc`, `.zshrc` (archive has work `wts-encryption` PATH, old `DOTNET_ROOT=/opt/dotnet`), `.profile` (archive = test-laptop wifi `wlp4s0`/`wts-wifi`; main intentionally removed), `.config/i3/config` bulk (main current), polybar `config`/`launch.sh`/themes (nord-arrow already → `config.ini` on main), `.gitconfig` (archive = old Navitaire email; main = Amadeus + better `includeIf`s), `.nvmrc` (`lts/dubnium`=Node 10 vs `lts/jod`=Node 22), `.config/gtk-3.0`, `.gtkrc-2.0`, `.config/rofi/config.rasi` (main newer), `.config/yadm/*` (archive = pre-1.6-upgrade payload location), `.local/bin/tools/check_for_arch_updates` (uses deprecated `trizen`), `.local/bin/tools/squash` (uses `master`), `.local/bin/tools/{screenshot,pulseaudio-tail.sh,polybar_alsa_module}` (main newer), `TODO.org` (old scratch list), `.bashrc`/`.bash_profile` (trivial).

## Privacy flag (separate concern, already on public `main`)

Not introduced by this triage, but noticed: `main`'s `.gitconfig` has a work email (work domain — redacted; literal value in git history pending the BFG scrub) and production gitconfig includes; `.profile`/`.zshrc` reference `wts-*` (work). These are company-internal details in a public repo — worth a pass through the pre-PR privacy workflow, tracked separately.

## Recommended next actions

1. Decide on the secret-manifest removals (confirm, then update `main`'s `.config/yadm/encrypt`).
2. Salvage the low-risk wins into their proper epics: `update` keepalive, `.gitignore` patterns, package-manifest additions (Epic 2/3).
3. Handle `settings.json` via encryption only, after key rotation.
4. Keep `archive/stale-test-laptop-main` until salvage is done; then it can be deleted (history stays in the tag).
