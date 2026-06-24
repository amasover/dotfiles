# Bootstrap & script inventory

**Story:** 2.1 (Classify setup scripts) — Issue [#16](https://github.com/amasover/dotfiles/issues/16)
**Epic:** [Epic 2 — Bootstrap & package modernization](./epic-2-bootstrap-and-package-modernization.md)
**Created:** 2026-06-23
**Scope:** every script under `.local/bin/setup/` and `.local/bin/tools/`.

This is the evidence artifact for Story 2.1: each script classified by safety and
currentness, with system mutations listed and do-not-run warnings made explicit.
Package-manifest triage (`arch-packages/`) is **Story 2.2**, not here. The future
bootstrap rewrite is **Story 2.3** — see [bootstrap architecture notes](./bootstrap-architecture-notes.md).

## Classification key

| Class | Meaning |
| --- | --- |
| **current** | Used on the live machine and works with the current stack. |
| **legacy** | Tied to the old Antergos / i3 / polybar / pulseaudio / Spacemacs era. May still run, but built on obsolete patterns or stacks now in question. |
| **unsafe** | Performs destructive or system-level mutations without gates. Do not run without review. |
| **unknown** | Purpose or current usage unclear — needs Aaron's input (see Open questions). |
| **broken** | Has a hard bug or missing dependency that prevents it working as written. |

> **Desktop-stack caveat:** many `tools/` entries are i3/polybar modules. Whether
> that desktop stack survives is an **Epic 3** decision. They're classified on their
> own merits here; "legacy (polybar)" means "works, but dies if the polybar stack is retired."

---

## `.local/bin/setup/`

| Script | Class | Purpose | System mutations |
| --- | --- | --- | --- |
| `install` | **unsafe + legacy** | Original 2019 full-machine bootstrap. | `pacman -Syu`, `pacman-optimize` (removed from pacman-contrib ~2019), `trizen`/`yay` AUR installs, `rustup`, `pip install --user`, `go get`, `git clone` (Vundle/Spacemacs), `yadm reset --hard origin/master`, `yadm remote set-url`, `xdg-settings`, `systemctl enable/start docker`, `usermod -aG`, **`reboot`**. |
| `lib.sh` | **legacy** | Shared helper sourced by `install`/`update`. Single function `install_pacman_packages`. | `yay -S` per line of the `arch-packages/pacman` manifest. |
| `update` | **current** | Daily "update everything" driver (modified 2026-06-23). | `yay -Syu` (system + AUR), `git pull` oh-my-zsh & Spacemacs, `antibody update`, `nvm`/`npm`/`yarn`/`pipx`/`uv` updates, `az extension update`, `tenv` (terraform/atmos), `vim VundleUpdate`. Interactive (Spacemacs prompt); holds sudo open via keepalive loop. |

### `install` — do NOT run

`install` is effectively unrunnable and must not be executed. Beyond the destructive
ops above, it is internally broken:

- `uninstall_deprecated_packages()` and `slow_aur_packages` are each **defined twice**
  (copy-paste); the second `uninstall_deprecated_packages` runs `sudo pacman -R --noconfirm`
  **with no package name** ([install:121](../.local/bin/setup/install#L121)).
- The slow-AUR loop iterates `$pkg` but installs leftover `$aur_package`
  ([install:158](../.local/bin/setup/install#L158)).
- Dead/missing commands: `pacman-optimize` (removed from pacman-contrib),
  `facter is_virtual` (puppet, not installed), `trizen` (unmaintained AUR helper).
- Deprecated package targets: `i3-gaps-next-git` (i3-gaps is merged into `i3-wm`).
- **Top-level commands run on _every_ execution**, regardless of flags — git-clones
  Vundle & Spacemacs, `yadm remote set-url`, and
  `xdg-settings set default-web-browser google-chrome.desktop`
  ([install:303](../.local/bin/setup/install#L303)).
- `--new` ends in an unconditional **`reboot`** ([install:367](../.local/bin/setup/install#L367)).
- `install_oh_my_zsh_and_plugins` runs `yadm reset --hard origin/master` — destructive
  and points at the retired `master` branch.

**Disposition (per session decision):** keep in place, classified unsafe; the real
fix is the Story 2.3 rewrite, not piecemeal patching. Do not promote as current.

---

## `.local/bin/tools/`

### Libraries / helpers (sourced, not run)

| Script | Class | Purpose | Notes |
| --- | --- | --- | --- |
| `dot-color` | **current** | ANSI color vars + `color` fn. Sourced by `bb-clone`, `dot-update`, `wifi`. | Fine. |
| `git_extras` | **unknown** | Defines `clone()` + `require_clean_work_tree()`. Marked "work in progress"; not executable; no caller found. | Uses `$BITBUCKET_ACCOUNT`/`$GITHUB_ACCOUNT`. Is anything sourcing this? |
| `dot-log` | **MISSING** | Referenced by `wifi` via `$TOOLS/dot-log` but does not exist in repo or `$HOME`. | Makes `wifi` fail at source time. |

### Current / working utilities

| Script | Class | Purpose | System mutations |
| --- | --- | --- | --- |
| `new_script` | **current** | Scaffold a new tool script, open in nvim. | writes file, `chmod +x`. |
| `quick-git-check-in` | **current** | Amend onto a `push` commit and force-push. | `git commit --amend`, `git push -f`. |
| `switch-aws-creds.sh` | **current** | Swap `~/.aws/credentials` for `credentials-<name>`. | `cp` over `~/.aws/credentials`. Touches creds (no secret in script). |
| `vault-ssh-files` | **current** | Pull an SSH key from Vault into `~/.ssh`. | writes `~/.ssh/<name>` (chmod 600). Needs `vault` + `secret/.ssh/*`. |
| `zsh_history_fix` | **current** | Repair a corrupt `~/.zsh_history`. | rewrites history file. |
| `mute_toggle` | **current** | Toggle mute via `volume` (volume-go). | depends on the `volume` Go binary (installed by old `install` go-get). |
| `sp` | **current** | Third-party Spotify CLI over dbus (Wander Nauta, MIT). | none destructive; needs Spotify running. |
| `vendor_repos` | **current** | Clone vendored repos (polybar-scripts, Vundle). Idempotent (skips if `.git`). | `git clone`. |

### Current but tied to the i3/polybar/X desktop stack (Epic 3 fate)

| Script | Class | Purpose | Notes |
| --- | --- | --- | --- |
| `lock` | **current (X/i3lock)** | Pixelated-screenshot screen lock. | `scrot`, `convert`, `i3lock`. Modified 2026-06-23. |
| `screenshot` | **current (X)** | `scrot` screenshot to `~/screenshots/YYYY/`. | `mkdir`, `scrot`, `notify-send`. |
| `pulseaudio-tail.sh` | **current (misnamed)** | Polybar volume module. **Already migrated to PipeWire** (`wpctl`/`pamixer`). | Filename says pulseaudio but uses PipeWire. Rename candidate. |
| `check_for_arch_updates` | **current (polybar)** | Polybar module: pending pacman + AUR update counts. | `checkupdates`, `yay -Qua`. Read-only. |
| `isrunning_dropbox.sh` | **current (polybar)** | Polybar Dropbox status + toggle. | `pkill`/start `dropbox`. |
| `yadm-checker.sh` | **legacy (polybar)** | Polybar module: yadm ahead/behind. | Hardcodes `master` ([yadm-checker.sh:63](../.local/bin/tools/yadm-checker.sh#L63)) — yadm now tracks `main`. Needs master→main fix. |

### Legacy / stale / superseded

| Script | Class | Purpose | Why flagged |
| --- | --- | --- | --- |
| `hashicorp-download` | **legacy (superseded)** | Download terraform/vault binaries to `~/.local/bin`. | `update` now manages terraform/atmos via `tenv`. Redundant. |
| `install_oh_my_zsh` | **legacy** | Install oh-my-zsh, change login shell, overwrite `~/.zshrc`. | `git clone`, **overwrites `~/.zshrc`**, `sudo usermod --shell`. Conflicts with `update`'s `antibody` model. Do not run casually. |
| `installed_packages.sh` | **legacy** | Dump explicit + foreign packages to `~/.config/{pacman,yaourt}-packages`. | References dead `yaourt`. Useful idea for Story 2.2; modernize. |
| `dot-update` | **legacy** | Rebuild the `dot` Go CLI from `patrick-motard/dot`. | `git reset --hard origin/master`, `go get`, `go install`, `cd $GOPATH`. Depends on the 2019 `dot` binary. |
| `polybar_alsa_module` | **legacy (likely broken)** | Polybar headphone/speaker switch. | Uses `pacmd` (PulseAudio, gone under PipeWire) + `dot sound port`. Contains upstream author's email. |
| `bb-clone` | **archive-candidate** | Clone repos from a work Bitbucket team. | Confirmed dead. Org scrubbed to `$BITBUCKET_ACCOUNT`; history scrub = privacy follow-up. |
| `squash` | **current (keep)** | Squash a branch against `upstreammaster`. | Confirmed in use. `git stash/merge/reset/commit`. Hardcoded `upstreammaster` ref may want review. |
| `termite_terminfo` | **legacy (dead dep)** | Push `termite` terminfo to a remote host. | The `termite` terminal was discontinued in 2020. |
| `docker-stack-redeploy` | **archive-candidate** | Redeploy a Docker Swarm stack (meant to be copied to a swarm manager). | Confirmed not in use. `sudo docker stack rm/deploy`. |
| `publish-python-package` | **archive-candidate** | Build + `twine upload` a Python package. | Confirmed not in use. `rm -rf dist`, `setup.py sdist`, `twine upload`. |
| `start-vbox-client` | **legacy (broken)** | Start VirtualBox guest client if virtual. | Gated on `facter is_virtual` — `facter` not installed, so it no-ops. |
| `update_background` | **legacy (broken)** | Random wallpaper via `feh`. | Hardcodes `/home/han/Dropbox/...` (original author's home) — path doesn't exist here. |
| `wifi` | **broken/legacy** | Reconnect wifi via `netctl`. | Sources missing `$TOOLS/dot-log` (fails immediately); uses `netctl` (Antergos-era); `if [[ ! connected ]]` never calls the function. |

---

## Do-not-run summary

Run only after review / rewrite:

- `setup/install` — destructive + broken (see above). **Never run as-is.**
- `tools/install_oh_my_zsh` — overwrites `~/.zshrc`, changes login shell.
- `tools/dot-update` — `git reset --hard` on the `dot` source tree.
- `tools/docker-stack-redeploy` — tears down + redeploys a live swarm stack.
- `tools/squash`, `tools/quick-git-check-in` — history-rewriting / force-push by design.

---

## Resolutions (2026-06-23, from Aaron)

- **`dot` Go CLI: confirmed in use.** Its live consumer is `polybar_alsa_module`
  (`dot sound port`), and the `alsa-switch` module is in `modules-right` of the **active**
  theme (`themes/nord-arrow/config.ini`, [line 31](../.config/polybar/themes/nord-arrow/config.ini#L31)).
  Aaron ran `dot sound port` directly and it works — so the running polybar genuinely
  depends on `dot` (every 0.5s via the listen loop). The *switch* path uses `pacmd`
  (PulseAudio) and may be degraded under PipeWire, but the read path is live. **So `dot`
  is a real dependency, not vestigial.** `dot-update` rebuilds it from
  `patrick-motard/dot`. Whether to keep depending on it is part of the architecture
  question — see [bootstrap-architecture-notes.md](./bootstrap-architecture-notes.md).
- **`bb-clone`:** confirmed no longer used → **archive-candidate**. Org name scrubbed
  from the working file (parameterized to `$BITBUCKET_ACCOUNT`); history scrub stays on
  the privacy follow-up.
- **`docker-stack-redeploy`, `publish-python-package`:** confirmed not in use →
  **archive-candidates**.
- **`squash`:** confirmed still used → **keep** (the `upstreammaster` ref may still want a look).
- **Polybar/i3 stack:** polybar *is* currently running; final fate is an Epic 3 call.

## Cross-cutting finding: a stray `update` alias (fixed)

The `update` shell alias had been pointing at Ansible, not the bash `setup/update`:

```sh
# was active:
alias update="ansible-playbook ~/code/dot-ansible/main.yml --ask-become-pass"
# was commented out — but is the one Aaron actually uses:
#alias update="zsh ~/.local/bin/setup/update"
```

Per Aaron, the Ansible line crept in accidentally during git/yadm branch shuffling;
the bash `setup/update` (edited 2026-06-23) is the real daily driver. **Fixed in this
story** ([.zshrc:200](../.zshrc#L200)): the bash alias is active again and the Ansible
line is kept commented as a dormant pointer. `~/code/dot-ansible` is
`patrick-motard/dot-ansible` (the upstream author's repo, 2019-era, never forked) — it
remains real prior art for the Story 2.3/2.5 architecture decision.

**Update (Story 3.4):** `.profile` had one live hook into dot-ansible — it sourced
`~/code/dot-ansible/shell-imports.sh`, which only set `LPASS_AGENT_TIMEOUT=0` for
lastpass-cli. Aaron no longer uses lastpass, so the import was **removed** in this story,
fully decoupling dot-ansible: it now has *no* live hook and survives only as a commented
`update`-alias pointer + reference prior-art for the 2.5 decision. (Knock-on: the i3
`$mod+p` rofi-lpass binding is now dead too — logged for Epic 3 desktop cleanup.)

## Story 3.4 — tool triage executed (2026-06-24)

Walked every tool with Aaron and acted. Removed files are recoverable from git history
(chosen over an `archive/` dir). Issue [#31](https://github.com/amasover/dotfiles/issues/31).

**Kept (12 + setup/update):** `update`, `dot-color`, `dot-update`, `polybar_alsa_module`,
`yadm-checker.sh` (master→main fixed in 2.1), `squash`, `new_script`, `quick-git-check-in`,
`pulseaudio-tail.sh`, `lock`, `screenshot`, `check_for_arch_updates`, `vendor_repos`.

**Deleted (17 scripts + `.fehbg`):** `git_extras`, `zsh_history_fix`, `switch-aws-creds.sh`,
`mute_toggle`, `installed_packages.sh`, `bb-clone`, `docker-stack-redeploy`,
`publish-python-package`, `sp`, `vault-ssh-files`, `hashicorp-download`, `termite_terminfo`,
`start-vbox-client`, `update_background`, `isrunning_dropbox.sh`, `wifi`, `install_oh_my_zsh`,
plus the broken `.fehbg`.

**Cascading config edits made:**
- `.zshrc`: removed `work-mode`/`other-mode` (both dup pairs), `bgf`, `bgn` aliases.
- `.config/i3/config`: removed the commented `mute_toggle` mute binding (active mute already
  uses `wpctl`) and the dead commented `sp` media bindings (active uses `playerctl`).
- `.config/polybar/themes/nord-arrow/config.ini`: removed the `dropbox-watcher` + arrow
  modules and their commented `modules-right` reference.
- `.profile`: removed the orphaned `# used by tools/wifi` comment.

**`setup/` deferred to Story 2.3:** `install` (rewrite), `lib.sh` (fold/replace).

## Remaining follow-ups

- **Fix `polybar_alsa_module` switch**: `pacmd` (PulseAudio) → `wpctl`/`pamixer` (PipeWire);
  the `dot sound port` read works, the click-to-switch likely doesn't.
- **Retire `volume-go`** (`~/code/go/bin/volume`, 2019) in favor of `wpctl`/`pamixer`
  (Epic 3); it still backs i3 volume up/down keys.
- **Rename `pulseaudio-tail.sh`** to reflect PipeWire (cosmetic; Epic 3).
- **Dead desktop config** (Epic 3 / Story 3.3): termite dropdown binding in i3
  ([config:166](../.config/i3/config#L166)); dead `$mod+p` rofi-lpass binding (off lastpass);
  stale polybar themes (`*.bak`, non-active themes).
- **`.zshrc` dedupe** (Story 3.1): duplicate `dot-src` and other repeated alias blocks.
- **Privacy** (existing follow-up): `cgbb` alias still names a work `[work-org]` Bitbucket path.
- **Story 2.2:** rebuild package inventory properly; evaluate **aconfmgr**. Issue [#24](https://github.com/amasover/dotfiles/issues/24).
- **Story 2.3:** install oh-my-zsh via the official installer (replaces the deleted vendored one).
- **Fish shell:** Aaron wants to be able to switch zsh→fish later — tracked as a new Epic 3 story.
