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

> ⚠️ **Diff alone cannot distinguish "stale" from "deliberately removed."** Every **Drop** item that is a *removal* needs Aaron's confirmation. Two confirmed-intentional examples are called out below.

### Confirmed intentional on the archive (per Aaron)

| Item | Note |
| --- | --- |
| `.config/yadm/encrypt` dropped `.aws/**`, `.mysql/workbench/connections.xml`, `.cobra.yaml`, `.pypirc` | Deliberate — no longer needed. **Decision:** should `main`'s manifest also drop these? It's a secret-handling change — confirm the underlying files don't need encrypted backup before editing `main`. |
| `.config/Code/User/settings.json` encrypted | Deliberate — it **contained an API key**. Must **never** be tracked as plaintext. To salvage onto this machine: add to `.config/yadm/encrypt` + `yadm encrypt`, and rotate/scrub the key. |

### Outcomes (line-by-line review with Aaron, 2026-06-23)

| File | Decision |
| --- | --- |
| `.local/bin/setup/update` sudo-keepalive | **Salvaged** into `main`. |
| `.local/bin/setup/update` pip-review + `.config/pip/pip.conf user=true` | **Dropped** — Aaron uninstalled `pip-review`; recoverable from the archive later. |
| `.local/bin/tools/lock` (Spotify-stop + DPMS idle-off) | **Dropped** — Aaron switched to `xidlehook`. Spun off [Story 3.7](https://github.com/amasover/dotfiles/issues/14) for the xidlehook-on-boot issue. |
| `.gitignore` | **No action** — `main` is already the superset (`*.~undo-tree~*`, `**.cecli`, `TODO.org`). The archive's is the *smaller* one. (Earlier triage note had this backwards.) |
| `.config/dotfiles/arch-packages/` (`antibody`, `linux-headers`, `sbsigntools`, `reflector-timer`; drop `vim`) | **Deferred to Epic 2** package triage (hard rule 5: live-install check + targeted Qs). |
| `.config/Code/User/settings.json` | **Pending** — encrypt-only (contains an API key); rotate key, then `yadm encrypt`. |
| `.config/yadm/encrypt` removals (`.aws/.mysql/.cobra/.pypirc`) | **Pending Aaron's confirm** before changing `main`'s manifest. |
| i3 vim-style focus keys, `.profile` `BROWSER` | Optional preference — not pursued. |

### Drop (`main` newer / this-machine-correct / superseded)

`.spacemacs` (archive 567 lines smaller — ancient), `.vimrc`, `.zshrc` (archive has work `wts-encryption` PATH, old `DOTNET_ROOT=/opt/dotnet`), `.profile` (archive = test-laptop wifi `wlp4s0`/`wts-wifi`; main intentionally removed), `.config/i3/config` bulk (main current), polybar `config`/`launch.sh`/themes (nord-arrow already → `config.ini` on main), `.gitconfig` (archive = old Navitaire email; main = Amadeus + better `includeIf`s), `.nvmrc` (`lts/dubnium`=Node 10 vs `lts/jod`=Node 22), `.config/gtk-3.0`, `.gtkrc-2.0`, `.config/rofi/config.rasi` (main newer), `.config/yadm/*` (archive = pre-1.6-upgrade payload location), `.local/bin/tools/check_for_arch_updates` (uses deprecated `trizen`), `.local/bin/tools/squash` (uses `master`), `.local/bin/tools/{screenshot,pulseaudio-tail.sh,polybar_alsa_module}` (main newer), `TODO.org` (old scratch list), `.bashrc`/`.bash_profile` (trivial).

## Privacy flag (separate concern, already on public `main`)

Not introduced by this triage, but noticed: `main`'s `.gitconfig` has a work email (`amadeus.com`) and production gitconfig includes; `.profile`/`.zshrc` reference `wts-*` (work). These are company-internal details in a public repo — worth a pass through the pre-PR privacy workflow, tracked separately.

## Recommended next actions

1. Decide on the secret-manifest removals (confirm, then update `main`'s `.config/yadm/encrypt`).
2. Salvage the low-risk wins into their proper epics: `update` keepalive, `.gitignore` patterns, package-manifest additions (Epic 2/3).
3. Handle `settings.json` via encryption only, after key rotation.
4. Keep `archive/stale-test-laptop-main` until salvage is done; then it can be deleted (history stays in the tag).
