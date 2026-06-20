# Live-Home Reconciliation — 2026-06-20

## Purpose

This document is the Story 1.2 evidence artifact for [Epic 1: Safety Inventory and Live-Home Reconciliation](./epic-1-safety-inventory-live-home.md).

Goal: map YADM-tracked paths to their live-home equivalents under `$HOME`, classify the current state, and define the order for detailed reconciliation.

No files were staged, committed, checked out, encrypted, decrypted, installed, removed, or pushed while producing this inventory.

---

## YADM-aware method

Normal YADM commands currently fail because YADM 3.5.0 detects legacy paths but expects XDG data paths.

For read-only inspection, use explicit legacy paths:

```bash
yadm --yadm-data $HOME/.config/yadm --yadm-archive $HOME/.config/yadm/files.gpg status --short --branch
yadm --yadm-data $HOME/.config/yadm --yadm-archive $HOME/.config/yadm/files.gpg diff --stat
yadm --yadm-data $HOME/.config/yadm --yadm-archive $HOME/.config/yadm/files.gpg list -a
```

Notes:

- `--yadm-data $HOME/.config/yadm` points YADM at the legacy repo data directory.
- `--yadm-archive $HOME/.config/yadm/files.gpg` points YADM at the legacy encrypted archive.
- `list -a` returns tracked files including alternates; plain `list` returned no output in this environment.
- Do not run `yadm upgrade`, `yadm checkout`, `yadm reset`, `yadm encrypt`, or `yadm decrypt` without explicit approval.

---

## Summary

| Item | Finding |
| --- | --- |
| Tracked files from `yadm list -a` | 421 |
| Branch | `<working-branch>` |
| Remote tracking | `origin/<working-branch>` |
| Ahead/behind | Ahead by 1 commit |
| Staged changes | None observed |
| Modified tracked files in live home | 31 |
| Deleted tracked files in live home | 2 |
| High-impact reconciliation candidates | 32 rows below |

---

## High-impact reconciliation candidates

| Status | Tracked path | Live path | Checkout path | Live exists | Checkout exists | Initial classification |
| --- | --- | --- | --- | --- | --- | --- |
| `M` | `.bash_profile` | `$HOME/.bash_profile` | `$DOTFILES_CHECKOUT/.bash_profile` | yes | yes | shell startup; review first |
| `M` | `.bashrc` | `$HOME/.bashrc` | `$DOTFILES_CHECKOUT/.bashrc` | yes | yes | shell startup; review first |
| `M` | `.config/Code/User/settings.json` | `$HOME/.config/Code/User/settings.json` | `$DOTFILES_CHECKOUT/.config/Code/User/settings.json` | yes | yes | editor config; review after shell/polybar |
| `M` | `.config/gtk-3.0/settings.ini` | `$HOME/.config/gtk-3.0/settings.ini` | `$DOTFILES_CHECKOUT/.config/gtk-3.0/settings.ini` | yes | yes | desktop/theme config |
| `M` | `.config/i3/config` | `$HOME/.config/i3/config` | `$DOTFILES_CHECKOUT/.config/i3/config` | yes | yes | desktop/session config |
| `D` | `.config/polybar/config` | `$HOME/.config/polybar/config` | `$DOTFILES_CHECKOUT/.config/polybar/config` | no | yes | deleted live; polybar priority |
| `M` | `.config/polybar/launch.sh` | `$HOME/.config/polybar/launch.sh` | `$DOTFILES_CHECKOUT/.config/polybar/launch.sh` | yes | yes | polybar priority |
| `M` | `.config/polybar/themes/global/modules` | `$HOME/.config/polybar/themes/global/modules` | `$DOTFILES_CHECKOUT/.config/polybar/themes/global/modules` | yes | yes | polybar priority |
| `D` | `.config/polybar/themes/nord-arrow/config` | `$HOME/.config/polybar/themes/nord-arrow/config` | `$DOTFILES_CHECKOUT/.config/polybar/themes/nord-arrow/config` | no | yes | deleted live; polybar priority; conflicts with checkout status |
| `M` | `.config/polybar/themes/nord/config` | `$HOME/.config/polybar/themes/nord/config` | `$DOTFILES_CHECKOUT/.config/polybar/themes/nord/config` | yes | yes | polybar priority |
| `M` | `.config/rofi/config.rasi` | `$HOME/.config/rofi/config.rasi` | `$DOTFILES_CHECKOUT/.config/rofi/config.rasi` | yes | yes | desktop launcher config |
| `M` | `.gitconfig` | `$HOME/.gitconfig` | `$DOTFILES_CHECKOUT/.gitconfig` | yes | yes | git identity/workflow; possible sensitive review |
| `M` | `.gitignore` | `$HOME/.gitignore` | `$DOTFILES_CHECKOUT/.gitignore` | yes | yes | global ignore behavior |
| `M` | `.gtkrc-2.0` | `$HOME/.gtkrc-2.0` | `$DOTFILES_CHECKOUT/.gtkrc-2.0` | yes | yes | desktop/theme config |
| `M` | `.local/bin/setup/update` | `$HOME/.local/bin/setup/update` | `$DOTFILES_CHECKOUT/.local/bin/setup/update` | yes | yes | bootstrap script; inspect only |
| `M` | `.local/bin/tools/check_for_arch_updates` | `$HOME/.local/bin/tools/check_for_arch_updates` | `$DOTFILES_CHECKOUT/.local/bin/tools/check_for_arch_updates` | yes | yes | helper script; package-related |
| `M` | `.local/bin/tools/lock` | `$HOME/.local/bin/tools/lock` | `$DOTFILES_CHECKOUT/.local/bin/tools/lock` | yes | yes | desktop/session helper |
| `M` | `.local/bin/tools/polybar_alsa_module` | `$HOME/.local/bin/tools/polybar_alsa_module` | `$DOTFILES_CHECKOUT/.local/bin/tools/polybar_alsa_module` | yes | yes | polybar helper |
| `M` | `.local/bin/tools/pulseaudio-tail.sh` | `$HOME/.local/bin/tools/pulseaudio-tail.sh` | `$DOTFILES_CHECKOUT/.local/bin/tools/pulseaudio-tail.sh` | yes | yes | audio/polybar helper |
| `M` | `.local/bin/tools/screenshot` | `$HOME/.local/bin/tools/screenshot` | `$DOTFILES_CHECKOUT/.local/bin/tools/screenshot` | yes | yes | desktop helper |
| `M` | `.local/bin/tools/squash` | `$HOME/.local/bin/tools/squash` | `$DOTFILES_CHECKOUT/.local/bin/tools/squash` | yes | yes | git helper script |
| `M` | `.nvmrc` | `$HOME/.nvmrc` | `$DOTFILES_CHECKOUT/.nvmrc` | yes | yes | runtime version |
| `M` | `.profile` | `$HOME/.profile` | `$DOTFILES_CHECKOUT/.profile` | yes | yes | login shell/env; review first |
| `M` | `.spacemacs` | `$HOME/.spacemacs` | `$DOTFILES_CHECKOUT/.spacemacs` | yes | yes | editor config; large diff |
| `M` | `.vimrc` | `$HOME/.vimrc` | `$DOTFILES_CHECKOUT/.vimrc` | yes | yes | editor config; small diff |
| `M` | `.xinitrc` | `$HOME/.xinitrc` | `$DOTFILES_CHECKOUT/.xinitrc` | yes | yes | desktop/session startup |
| `M` | `.zsh_plugins.sh` | `$HOME/.zsh_plugins.sh` | `$DOTFILES_CHECKOUT/.zsh_plugins.sh` | yes | no | shell plugin state; tracked in YADM but absent from checkout |
| `M` | `.zsh_plugins.txt` | `$HOME/.zsh_plugins.txt` | `$DOTFILES_CHECKOUT/.zsh_plugins.txt` | yes | no | shell plugin input; tracked in YADM but absent from checkout |
| `M` | `.zshrc` | `$HOME/.zshrc` | `$DOTFILES_CHECKOUT/.zshrc` | yes | yes | shell startup; review first |
| `M` | `LICENSE` | `$HOME/LICENSE` | `$DOTFILES_CHECKOUT/LICENSE` | yes | yes | repo metadata; odd live-home location |
| `M` | `README.md` | `$HOME/README.md` | `$DOTFILES_CHECKOUT/README.md` | yes | yes | docs; likely historical drift |
| `M` | `TODO.org` | `$HOME/TODO.org` | `$DOTFILES_CHECKOUT/TODO.org` | yes | yes | personal task/history doc |

---

## Classification definitions

| Classification | Meaning | Action |
| --- | --- | --- |
| shell startup | Affects new terminal/login behavior | Reconcile early and carefully |
| polybar priority | Desktop status bar config or helper | Reconcile early because deleted/modified state conflicts |
| editor config | Affects editors and plugins | Reconcile after shell and polybar |
| desktop/session config | Affects X/i3/GTK/rofi/session behavior | Reconcile after shell and polybar |
| bootstrap script | May install/update/mutate system | Inspect only; do not execute |
| helper script | Personal executable workflow | Syntax-check and classify before changing |
| repo metadata/docs | Documentation or Git behavior | Safe to review, but still compare live vs checkout |
| possible sensitive review | Could contain identity, account, URL, or workflow info | Avoid printing detailed diff until reviewed |

---

## Recommended reconciliation order

1. Shell startup set: `.zshrc`, `.profile`, `.bashrc`, `.bash_profile`, `.zsh_plugins.sh`, `.zsh_plugins.txt`
2. Polybar set: `.config/polybar/config`, `.config/polybar/launch.sh`, `.config/polybar/themes/global/modules`, `.config/polybar/themes/nord/config`, `.config/polybar/themes/nord-arrow/config`
3. Git and runtime basics: `.gitconfig`, `.gitignore`, `.nvmrc`
4. Desktop/session set: `.xinitrc`, `.config/i3/config`, `.config/rofi/config.rasi`, GTK config files
5. Editor set: `.vimrc`, `.spacemacs`, `.config/Code/User/settings.json`
6. Helper scripts: setup/update and selected scripts under `.local/bin/tools/`
7. Repo docs and metadata: `README.md`, `TODO.org`, `LICENSE`

---

## Story 1.2 conclusion

Story 1.2 has produced the initial live-home reconciliation list for the changed high-impact files. The list shows where each changed tracked path maps in `$HOME`, whether it exists live, whether it exists in the normal checkout, and how it should be prioritized.

The next implementation step is file-by-file reconciliation. Start with shell startup files, because they affect daily terminal behavior and include files tracked by legacy YADM but missing from the normal checkout.
