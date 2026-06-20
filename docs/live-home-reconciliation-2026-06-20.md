# Live-Home Reconciliation — 2026-06-20

## Purpose

This document is the Story 1.2 evidence artifact for [Epic 1: Safety Inventory and Live-Home Reconciliation](./epic-1-safety-inventory-live-home.md).

Goal: map YADM-tracked paths to their live-home equivalents under `/home/aaron`, classify the current state, and define the order for detailed reconciliation.

No files were staged, committed, checked out, encrypted, decrypted, installed, removed, or pushed while producing this inventory.

---

## YADM-aware method

Normal YADM commands currently fail because YADM 3.5.0 detects legacy paths but expects XDG data paths.

For read-only inspection, use explicit legacy paths:

```bash
yadm --yadm-data /home/aaron/.config/yadm --yadm-archive /home/aaron/.config/yadm/files.gpg status --short --branch
yadm --yadm-data /home/aaron/.config/yadm --yadm-archive /home/aaron/.config/yadm/files.gpg diff --stat
yadm --yadm-data /home/aaron/.config/yadm --yadm-archive /home/aaron/.config/yadm/files.gpg list -a
```

Notes:

- `--yadm-data /home/aaron/.config/yadm` points YADM at the legacy repo data directory.
- `--yadm-archive /home/aaron/.config/yadm/files.gpg` points YADM at the legacy encrypted archive.
- `list -a` returns tracked files including alternates; plain `list` returned no output in this environment.
- Do not run `yadm upgrade`, `yadm checkout`, `yadm reset`, `yadm encrypt`, or `yadm decrypt` without explicit approval.

---

## Summary

| Item | Finding |
| --- | --- |
| Tracked files from `yadm list -a` | 421 |
| Branch | `test-laptop` |
| Remote tracking | `origin/test-laptop` |
| Ahead/behind | Ahead by 1 commit |
| Staged changes | None observed |
| Modified tracked files in live home | 31 |
| Deleted tracked files in live home | 2 |
| High-impact reconciliation candidates | 32 rows below |

---

## High-impact reconciliation candidates

| Status | Tracked path | Live path | Checkout path | Live exists | Checkout exists | Initial classification |
| --- | --- | --- | --- | --- | --- | --- |
| `M` | `.bash_profile` | `/home/aaron/.bash_profile` | `/home/aaron/code/dotfiles/.bash_profile` | yes | yes | shell startup; review first |
| `M` | `.bashrc` | `/home/aaron/.bashrc` | `/home/aaron/code/dotfiles/.bashrc` | yes | yes | shell startup; review first |
| `M` | `.config/Code/User/settings.json` | `/home/aaron/.config/Code/User/settings.json` | `/home/aaron/code/dotfiles/.config/Code/User/settings.json` | yes | yes | editor config; review after shell/polybar |
| `M` | `.config/gtk-3.0/settings.ini` | `/home/aaron/.config/gtk-3.0/settings.ini` | `/home/aaron/code/dotfiles/.config/gtk-3.0/settings.ini` | yes | yes | desktop/theme config |
| `M` | `.config/i3/config` | `/home/aaron/.config/i3/config` | `/home/aaron/code/dotfiles/.config/i3/config` | yes | yes | desktop/session config |
| `D` | `.config/polybar/config` | `/home/aaron/.config/polybar/config` | `/home/aaron/code/dotfiles/.config/polybar/config` | no | yes | deleted live; polybar priority |
| `M` | `.config/polybar/launch.sh` | `/home/aaron/.config/polybar/launch.sh` | `/home/aaron/code/dotfiles/.config/polybar/launch.sh` | yes | yes | polybar priority |
| `M` | `.config/polybar/themes/global/modules` | `/home/aaron/.config/polybar/themes/global/modules` | `/home/aaron/code/dotfiles/.config/polybar/themes/global/modules` | yes | yes | polybar priority |
| `D` | `.config/polybar/themes/nord-arrow/config` | `/home/aaron/.config/polybar/themes/nord-arrow/config` | `/home/aaron/code/dotfiles/.config/polybar/themes/nord-arrow/config` | no | yes | deleted live; polybar priority; conflicts with checkout status |
| `M` | `.config/polybar/themes/nord/config` | `/home/aaron/.config/polybar/themes/nord/config` | `/home/aaron/code/dotfiles/.config/polybar/themes/nord/config` | yes | yes | polybar priority |
| `M` | `.config/rofi/config.rasi` | `/home/aaron/.config/rofi/config.rasi` | `/home/aaron/code/dotfiles/.config/rofi/config.rasi` | yes | yes | desktop launcher config |
| `M` | `.gitconfig` | `/home/aaron/.gitconfig` | `/home/aaron/code/dotfiles/.gitconfig` | yes | yes | git identity/workflow; possible sensitive review |
| `M` | `.gitignore` | `/home/aaron/.gitignore` | `/home/aaron/code/dotfiles/.gitignore` | yes | yes | global ignore behavior |
| `M` | `.gtkrc-2.0` | `/home/aaron/.gtkrc-2.0` | `/home/aaron/code/dotfiles/.gtkrc-2.0` | yes | yes | desktop/theme config |
| `M` | `.local/bin/setup/update` | `/home/aaron/.local/bin/setup/update` | `/home/aaron/code/dotfiles/.local/bin/setup/update` | yes | yes | bootstrap script; inspect only |
| `M` | `.local/bin/tools/check_for_arch_updates` | `/home/aaron/.local/bin/tools/check_for_arch_updates` | `/home/aaron/code/dotfiles/.local/bin/tools/check_for_arch_updates` | yes | yes | helper script; package-related |
| `M` | `.local/bin/tools/lock` | `/home/aaron/.local/bin/tools/lock` | `/home/aaron/code/dotfiles/.local/bin/tools/lock` | yes | yes | desktop/session helper |
| `M` | `.local/bin/tools/polybar_alsa_module` | `/home/aaron/.local/bin/tools/polybar_alsa_module` | `/home/aaron/code/dotfiles/.local/bin/tools/polybar_alsa_module` | yes | yes | polybar helper |
| `M` | `.local/bin/tools/pulseaudio-tail.sh` | `/home/aaron/.local/bin/tools/pulseaudio-tail.sh` | `/home/aaron/code/dotfiles/.local/bin/tools/pulseaudio-tail.sh` | yes | yes | audio/polybar helper |
| `M` | `.local/bin/tools/screenshot` | `/home/aaron/.local/bin/tools/screenshot` | `/home/aaron/code/dotfiles/.local/bin/tools/screenshot` | yes | yes | desktop helper |
| `M` | `.local/bin/tools/squash` | `/home/aaron/.local/bin/tools/squash` | `/home/aaron/code/dotfiles/.local/bin/tools/squash` | yes | yes | git helper script |
| `M` | `.nvmrc` | `/home/aaron/.nvmrc` | `/home/aaron/code/dotfiles/.nvmrc` | yes | yes | runtime version |
| `M` | `.profile` | `/home/aaron/.profile` | `/home/aaron/code/dotfiles/.profile` | yes | yes | login shell/env; review first |
| `M` | `.spacemacs` | `/home/aaron/.spacemacs` | `/home/aaron/code/dotfiles/.spacemacs` | yes | yes | editor config; large diff |
| `M` | `.vimrc` | `/home/aaron/.vimrc` | `/home/aaron/code/dotfiles/.vimrc` | yes | yes | editor config; small diff |
| `M` | `.xinitrc` | `/home/aaron/.xinitrc` | `/home/aaron/code/dotfiles/.xinitrc` | yes | yes | desktop/session startup |
| `M` | `.zsh_plugins.sh` | `/home/aaron/.zsh_plugins.sh` | `/home/aaron/code/dotfiles/.zsh_plugins.sh` | yes | no | shell plugin state; tracked in YADM but absent from checkout |
| `M` | `.zsh_plugins.txt` | `/home/aaron/.zsh_plugins.txt` | `/home/aaron/code/dotfiles/.zsh_plugins.txt` | yes | no | shell plugin input; tracked in YADM but absent from checkout |
| `M` | `.zshrc` | `/home/aaron/.zshrc` | `/home/aaron/code/dotfiles/.zshrc` | yes | yes | shell startup; review first |
| `M` | `LICENSE` | `/home/aaron/LICENSE` | `/home/aaron/code/dotfiles/LICENSE` | yes | yes | repo metadata; odd live-home location |
| `M` | `README.md` | `/home/aaron/README.md` | `/home/aaron/code/dotfiles/README.md` | yes | yes | docs; likely historical drift |
| `M` | `TODO.org` | `/home/aaron/TODO.org` | `/home/aaron/code/dotfiles/TODO.org` | yes | yes | personal task/history doc |

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

Story 1.2 has produced the initial live-home reconciliation list for the changed high-impact files. The list shows where each changed tracked path maps in `/home/aaron`, whether it exists live, whether it exists in the normal checkout, and how it should be prioritized.

The next implementation step is file-by-file reconciliation. Start with shell startup files, because they affect daily terminal behavior and include files tracked by legacy YADM but missing from the normal checkout.
