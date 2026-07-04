# Runbook: fresh-machine bootstrap

Evidence artifact for Story 2.3 ([#25](https://github.com/amasover/dotfiles/issues/25)).
Design: [decision-bootstrap-architecture.md](./decision-bootstrap-architecture.md).
Script: [`.local/bin/setup/bootstrap`](../.local/bin/setup/bootstrap) (replaces the
retired 2019 `setup/install` — see [bootstrap-inventory.md](./bootstrap-inventory.md)
for its autopsy; history via `git log -- .local/bin/setup/install`).

> **METAL GATE:** until Story 2.10 ([#50](https://github.com/amasover/dotfiles/issues/50))
> lands, run this only in disposable VMs (Story 2.7 harness). The script warns and
> requires typing `metal` on real hardware. Reason: fresh installs pull the whole AUR
> set with no install-time gating yet.

## Preconditions (manual, once)

1. Arch installed — `archinstall` minimal profile is fine. Network up, user created,
   sudo working. No desktop profile needed: the class decides that later.
2. ```bash
   sudo pacman -S --needed git base-devel yadm
   yadm clone https://github.com/amasover/dotfiles.git
   ```
   `yadm clone` may report checkout conflicts on a non-pristine home; resolve, then
   continue. Templates render on checkout, but the profile guard re-renders anyway.

## Run

```bash
~/.local/bin/setup/bootstrap --check   # read-only: guards + plan
~/.local/bin/setup/bootstrap           # the real run
```

The script is linear and re-runnable; every mutating step is delegated to a tool that
shows its own plan and prompts (makepkg, metapac sync, chsh). What it does, in order:

1. **Secrets** — `yadm decrypt` (interactive passphrase; symmetric GPG, no key
   transfer needed; secret contents are never printed). Skipped when `~/.zshenv`
   already exists.
2. **Profile guard** — hard-fails unless `yadm config local.class <class>` is set and
   the rendered `~/.config/metapac/config.toml` has this hostname's entry. Choosing
   the class **is** the desktop-optional step: a class whose group list omits
   `desktop`/`media`/`gaming` bootstraps a headless-ish machine; nothing installs
   i3/polybar/rofi unless the class says so.
3. **Machine-local groups** — creates (empty) any absolute-path group file the config
   references; metapac hard-errors on missing group files. On the workstation class
   this is `~/.local/share/metapac/machine-local.toml` (Story 2.11 owns its contents).
4. **yay** — one manual `makepkg -si` from `yay-bin`; the only unmanaged install.
5. **metapac** — `yay -S metapac` (it's an AUR package).
6. **`metapac sync`** — the fresh install is just the first reconcile: installs the
   class's declared set (AUR through yay), per-package service hooks fire as declared.
7. **AUR trust baseline** — `aur-quarantine seed` (trust-first-seen, announced;
   interim until 2.10's portable baseline).
8. **oh-my-zsh** — official installer, `KEEP_ZSHRC=yes` so yadm's `.zshrc` survives
   (replaces the deleted vendored `install_oh_my_zsh`).
9. **Login shell** — `chsh -s /usr/bin/zsh` if needed. Reboot when done.

## Class table

| Class | Meaning | Group list |
| --- | --- | --- |
| `workstation` | the daily driver (this machine) | all 16 purpose groups + `inbox-workstation` + machine-local |

New machine ≈ new class: add a branch to `config.toml##template` with its group list
and an `inbox-<class>.toml`, set `yadm config local.class`, `yadm alt`. Classes are
public-safe labels; one per machine (see CONTEXT.md).

## After first boot

- `yay -Syu` is quarantine-gated from the start (holds are normal for a young
  baseline; `aur-quarantine accept <pkg>` after verifying).
- `setup/update` is the update loop; it ends with the read-only drift report
  (unmanaged / declared-but-missing / inbox triage).
- Machine-specific extras go in untracked `~/.gitconfig-local` / `~/.zshrc.local`
  (work machines: git identity, work aliases — see Story 1.8).

## Troubleshooting

- **"yadm.class is unset"** — `yadm config local.class <class>`, `yadm alt`, re-run.
- **"no [hostname_groups] entry"** — the template has no branch for this class, or
  `yadm alt` hasn't re-rendered since the class was set.
- **metapac errors on a missing group file** — re-run the script (step 3 creates
  empty ones), or check the absolute paths in the rendered config.
- **`metapac sync` proposes nothing** — the profile guard should have caught it;
  verify the hostname key really is in the rendered config (guard checks the literal
  `hostname` output).
