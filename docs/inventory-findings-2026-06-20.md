# Inventory Findings — 2026-06-20

## Purpose

This document captures the first read-only inventory findings from the dotfiles cleanup effort. It is an evidence artifact for:

- [PRD](./prd.md)
- [Epic 1: Safety Inventory and Live-Home Reconciliation](./epic-1-safety-inventory-live-home.md)
- [Epic 2: Bootstrap and Package Modernization](./epic-2-bootstrap-and-package-modernization.md)
- [Validation and Release Workflow](./validation-and-release-workflow.md)

No files were staged or committed as part of this inventory.

---

## Git repo status

Read-only `git status --short --branch` from `$DOTFILES_CHECKOUT` showed:

```text
## <working-branch>...origin/<working-branch>
 M .config/polybar/themes/nord-arrow/config
?? .github/
?? docs/
```

Interpretation:

- The normal Git checkout is on branch `<working-branch>` tracking `origin/<working-branch>`.
- The new planning artifacts are untracked under `.github/` and `docs/`.
- There is one pre-existing modified file: `.config/polybar/themes/nord-arrow/config`.
- That modified polybar file should be reviewed against the live home directory before any cleanup commit.

---

## YADM status issue

Running normal `yadm status` and `yadm diff --stat` failed with a YADM v3 legacy-path warning and repo detection error.

Observed YADM version:

```text
yadm version 3.5.0
```

Observed warning:

```text
Legacy paths have been detected.
With version 3.0.0, yadm uses the XDG Base Directory Specification.
```

Detected legacy paths:

```text
$HOME/.config/yadm/repo.git
$HOME/.config/yadm/files.gpg
```

Observed error:

```text
ERROR: Git repo does not exist. did you forget to run 'init' or 'clone'?
```

Read-only filesystem check confirmed these paths exist:

```text
$HOME/.config/yadm
$HOME/.config/yadm/repo.git
$HOME/.config/yadm/files.gpg
$HOME/.local/share/yadm
```

Interpretation:

- YADM v3 is looking for data under XDG paths, but this machine still has legacy YADM data under `$HOME/.config/yadm`.
- Do not run `yadm upgrade` automatically; it is a mutating operation and needs explicit approval.
- Until YADM is upgraded or configured, read-only inspection can use Git directly against the legacy YADM repo.

Read-only legacy YADM status command used:

```bash
git --git-dir=$HOME/.config/yadm/repo.git --work-tree=$HOME status --short --branch
```

Legacy YADM repo status showed:

```text
## <working-branch>...origin/<working-branch> [ahead 1]
```

Interpretation:

- The legacy YADM repo has one local commit not pushed to `origin/<working-branch>`.
- There are many modified live-home files relative to the YADM repo.
- This reinforces that live-home reconciliation must happen before broad cleanup.

Legacy YADM remote:

```text
origin git@github.com:<owner>/dotfiles.git
```

Normal Git checkout remote:

```text
origin https://github.com/<owner>/dotfiles.git
```

Interpretation:

- The checkout and legacy YADM repo point at the same GitHub repo but use different remote URL schemes.
- Remote configuration should be reviewed before any push.

---

## Legacy YADM modified files summary

The legacy YADM repo reports many changed live-home files, including:

- `.bash_profile`
- `.bashrc`
- `.config/Code/User/settings.json`
- `.config/gtk-3.0/settings.ini`
- `.config/i3/config`
- `.config/pip/pip.conf`
- `.config/polybar/launch.sh`
- `.config/polybar/themes/global/modules`
- `.config/polybar/themes/nord/config`
- `.config/rofi/config.rasi`
- `.gitconfig`
- `.gitignore`
- `.gtkrc-2.0`
- `.local/bin/setup/update`
- `.local/bin/tools/check_for_arch_updates`
- `.local/bin/tools/lock`
- `.local/bin/tools/polybar_alsa_module`
- `.local/bin/tools/pulseaudio-tail.sh`
- `.local/bin/tools/screenshot`
- `.local/bin/tools/squash`
- `.nvmrc`
- `.profile`
- `.spacemacs`
- `.vimrc`
- `.xinitrc`
- `.zsh_plugins.sh`
- `.zsh_plugins.txt`
- `.zshrc`
- `LICENSE`
- `README.md`
- `TODO.org`

Deleted relative to legacy YADM:

- `.config/polybar/config`
- `.config/polybar/themes/nord-arrow/config`

Interpretation:

- Shell, editor, desktop, tool scripts, and docs all have live-home drift.
- Polybar needs special attention because the normal Git checkout and legacy YADM status report different perspectives on `nord-arrow/config`.
- Do not resolve these with `yadm checkout`, `git checkout`, or deletion until the desired source of truth is known.

---

## Local package inventory summary

Read-only package counts from the current machine:

```text
explicit total: 380
foreign total: 117
repo pacman list: 203
repo aur list: 23
```

Comparison against repo manifests produced:

```text
native explicit not in repo pacman: 116
repo pacman not installed native: 36
foreign/AUR not in repo aur: 110
repo aur not installed foreign: 16
```

Interpretation:

- The current machine has many explicitly installed native packages missing from the repo manifest.
- The current machine has many foreign/AUR packages missing from the repo manifest.
- The repo manifests contain stale packages that are not currently installed.
- Package cleanup should be done by grouped triage with Aaron, not by automatically replacing manifests.

---

## Sample package gaps

### Native explicit packages installed locally but missing from repo manifest

Sample:

```text
7zip
acpi
adobe-source-code-pro-fonts
alacritty
arch-install-scripts
autopep8
autorandr
azcopy
azure-cli
barcode
bind
bluetui
bluez
bluez-utils
bolt
broot
cmatrix
cups
discord
discount
dnsmasq
dos2unix
editorconfig-core-c
edk2-shell
efivar
ex-vi-compat
eza
ffmpegthumbnailer
foomatic-db
gimp
github-cli
globalprotect-openconnect
go
gpick
graphviz
gutenprint
guvcview
harfbuzz
helm
hplip
```

Likely triage groups:

- Core/system: `bluez`, `bluez-utils`, `cups`, `efivar`, `hplip`
- CLI/dev productivity: `7zip`, `dos2unix`, `editorconfig-core-c`, `github-cli`, `go`, `helm`
- Cloud/work: `azcopy`, `azure-cli`, `globalprotect-openconnect`
- Desktop/media: `alacritty`, `autorandr`, `gimp`, `gpick`, `guvcview`
- Unknown/fun/optional: `barcode`, `bluetui`, `broot`, `cmatrix`, `discount`

### Repo native packages not installed locally

Sample:

```text
antergos-keyring
antergos-midnight-timers
antergos-mirrorlist
bind-tools
bitlbee
ca-certificates
compton
crda
dropbox
exa
ipw2100-fw
ipw2200-fw
lib32-nvidia-390xx-utils
mesa
mlocate
networkmanager
networkmanager-dispatcher-ntpd
nvidia-390xx
nvidia-390xx-settings
nvidia-390xx-utils
pacman
parted
pgadmin4
pulseaudio
reiserfsprogs
steam
task
termite
terraform
vi
vim
wireless_tools
xautolock
xdotool
xorg-xrandr
xz
```

Likely triage notes:

- `antergos-*` is likely stale legacy.
- `exa` may be replaced by `eza`.
- old NVIDIA 390xx packages are likely machine-specific or stale.
- `termite` may be stale if `alacritty` is current.
- `terraform` may have moved to another install method.
- base packages such as `pacman`, `ca-certificates`, `xz`, and `mesa` need careful handling because they may be implicit rather than explicit.

### Foreign/AUR packages installed locally but missing from repo manifest

Sample:

```text
password-manager-package
work-ca-certificates
work-globalprintservice
work-vpn-bin
anki-bin
antibody
arc-gtk-theme
archlinux-java-run
arc-solid-gtk-theme
aspnet-runtime-9.0-bin
aspnet-runtime-bin
aspnet-targeting-pack-bin
astro-cli
aztfexport-bin
azure-functions-core-tools-bin
bitlbee
bootinfoscript
brew-git
byzanz
chatmcp
clight
clightd
clight-gui-git
colorpicker
databricks-cli-bin
debtap
displaylink
dotnet-host-bin
dotnet-runtime-2.1
dotnet-runtime-2.2
dotnet-runtime-9.0-bin
dotnet-runtime-bin
dotnet-sdk-9.0-bin
dotnet-sdk-bin
dotnet-targeting-pack-9.0-bin
dotnet-targeting-pack-bin
downgrade
evdi-dkms
ext4magic
extundelete
```

Likely triage groups:

- Work/vendor: work CA certificates, print service, and VPN-related packages
- Cloud/dev: `aztfexport-bin`, `azure-functions-core-tools-bin`, `databricks-cli-bin`, `dotnet-*`, `astro-cli`
- Desktop/hardware: `displaylink`, `evdi-dkms`, `clight*`
- Personal apps: password manager, `anki-bin`
- Unknown/legacy: `dotnet-runtime-2.1`, `dotnet-runtime-2.2`, `bitlbee`

### Repo AUR packages not installed locally

```text
arc-gtk-theme-git
ckb-next
discord
flashfocus-git
i3-gaps-next-git
minecraft-launcher
mirage
openfortivpn
paper-icon-theme
polybar-git
remmina-plugin-rdesktop
slack-desktop
spotify
teams-for-linux
wpa_actiond
yadm-git
```

Likely triage notes:

- Some may be stale personal apps: `minecraft-launcher`, `spotify`, `slack-desktop`, `teams-for-linux`.
- Some may be replaced or installed natively now: `discord`, theme packages.
- i3/polybar-related packages need desktop-currentness review before removal.
- `yadm-git` may no longer be needed if `yadm` is installed another way.

---

## Recommended next package triage questions

Ask by group first:

1. Should work/vendor packages such as CA certificates, VPN, printing, DisplayLink, and GlobalProtect be part of bootstrap, or machine-local only?
2. Should Azure/.NET/data tooling such as `azure-cli`, `azcopy`, `aztfexport-bin`, `azure-functions-core-tools-bin`, `databricks-cli-bin`, and `dotnet-*` be part of standard dev bootstrap?
3. Is `alacritty` the current terminal, and should old `termite` config/packages be archived?
4. Is `eza` the replacement for `exa`?
5. Are i3/polybar/rofi still active desktop surfaces or legacy-supported only?
6. Should personal GUI apps such as password manager, `anki-bin`, `spotify`, `discord`, and `gimp` be in bootstrap or documented as optional?
7. Are old Antergos and NVIDIA 390xx packages safe to classify as legacy/stale?

---

## Story 1.1 evidence: YADM current state

Story 1.1 asked for a read-only summary of YADM status and diffs before staging anything.

### Commands run

Normal YADM commands were attempted first:

```bash
yadm status --short --branch
yadm diff --stat
```

Both failed with the YADM v3 legacy-path warning and repo detection error documented above. No mutating YADM command was run.

Legacy YADM Git commands were then used for read-only inspection:

```bash
git --git-dir=$HOME/.config/yadm/repo.git --work-tree=$HOME status --short --branch
git --git-dir=$HOME/.config/yadm/repo.git --work-tree=$HOME diff --stat
git --git-dir=$HOME/.config/yadm/repo.git --work-tree=$HOME diff --cached --stat
git --git-dir=$HOME/.config/yadm/repo.git --work-tree=$HOME ls-files --others --exclude-standard
```

### Summary

| Category | Finding |
| --- | --- |
| Branch | `<working-branch>` |
| Remote tracking | `origin/<working-branch>` |
| Ahead/behind | Ahead by 1 commit |
| Staged changes | None reported by `diff --cached --stat` |
| Modified tracked files | 31 modified files |
| Deleted tracked files | 2 deleted files |
| Untracked output | Reported `./`, requiring follow-up because the work tree is `$HOME` |
| Diff size | 33 files changed, 1567 insertions, 1582 deletions |

### Modified tracked files

```text
.bash_profile
.bashrc
.config/Code/User/settings.json
.config/gtk-3.0/settings.ini
.config/i3/config
.config/pip/pip.conf
.config/polybar/launch.sh
.config/polybar/themes/global/modules
.config/polybar/themes/nord/config
.config/rofi/config.rasi
.gitconfig
.gitignore
.gtkrc-2.0
.local/bin/setup/update
.local/bin/tools/check_for_arch_updates
.local/bin/tools/lock
.local/bin/tools/polybar_alsa_module
.local/bin/tools/pulseaudio-tail.sh
.local/bin/tools/screenshot
.local/bin/tools/squash
.nvmrc
.profile
.spacemacs
.vimrc
.xinitrc
.zsh_plugins.sh
.zsh_plugins.txt
.zshrc
LICENSE
README.md
TODO.org
```

### Deleted tracked files

```text
.config/polybar/config
.config/polybar/themes/nord-arrow/config
```

### High-impact areas

- Shell startup and login: `.bash_profile`, `.bashrc`, `.profile`, `.zshrc`, `.zsh_plugins.sh`, `.zsh_plugins.txt`
- Editor configuration: `.vimrc`, `.spacemacs`, `.config/Code/User/settings.json`
- Desktop/session configuration: `.xinitrc`, `.config/i3/config`, `.config/gtk-3.0/settings.ini`, `.gtkrc-2.0`, `.config/rofi/config.rasi`
- Polybar configuration: `.config/polybar/config`, `.config/polybar/launch.sh`, `.config/polybar/themes/global/modules`, `.config/polybar/themes/nord/config`, `.config/polybar/themes/nord-arrow/config`
- Personal scripts: `.local/bin/setup/update`, `.local/bin/tools/check_for_arch_updates`, `.local/bin/tools/lock`, `.local/bin/tools/polybar_alsa_module`, `.local/bin/tools/pulseaudio-tail.sh`, `.local/bin/tools/screenshot`, `.local/bin/tools/squash`
- Repo docs/metadata: `README.md`, `TODO.org`, `LICENSE`, `.gitconfig`, `.gitignore`

### Story 1.1 conclusion

Story 1.1 is complete enough to proceed to Story 1.2. The current state is known at summary level, but detailed content diffs should be reviewed file-by-file and should avoid secret-bearing files. The next step is live-home reconciliation by high-impact group, starting with shell startup files and polybar because polybar has both modified and deleted paths.

---

## Story 1.2 evidence: Live-home reconciliation list

Story 1.2 asked for tracked files to be mapped to `$HOME` so cleanup decisions can reflect the actual workstation.

Detailed artifact:

- [Live-Home Reconciliation — 2026-06-20](./live-home-reconciliation-2026-06-20.md)

### YADM-aware inspection method

Because normal YADM commands currently fail under YADM 3.5.0 legacy-path detection, Story 1.2 used explicit legacy YADM paths instead of raw Git where possible:

```bash
yadm --yadm-data $HOME/.config/yadm --yadm-archive $HOME/.config/yadm/files.gpg status --short --branch
yadm --yadm-data $HOME/.config/yadm --yadm-archive $HOME/.config/yadm/files.gpg diff --stat
yadm --yadm-data $HOME/.config/yadm --yadm-archive $HOME/.config/yadm/files.gpg list -a
```

This is the preferred read-only workaround until `yadm upgrade` is explicitly approved.

### Summary

| Category | Finding |
| --- | --- |
| Tracked files from `yadm list -a` | 421 |
| High-impact reconciliation candidates | 32 |
| Live deleted tracked files | `.config/polybar/config`, `.config/polybar/themes/nord-arrow/config` |
| Tracked in YADM but absent from normal checkout | `.zsh_plugins.sh`, `.zsh_plugins.txt` |
| Highest-priority reconciliation groups | shell startup files, then polybar |

### Recommended reconciliation order

1. Shell startup set: `.zshrc`, `.profile`, `.bashrc`, `.bash_profile`, `.zsh_plugins.sh`, `.zsh_plugins.txt`
2. Polybar set: `.config/polybar/config`, `.config/polybar/launch.sh`, `.config/polybar/themes/global/modules`, `.config/polybar/themes/nord/config`, `.config/polybar/themes/nord-arrow/config`
3. Git and runtime basics: `.gitconfig`, `.gitignore`, `.nvmrc`
4. Desktop/session set: `.xinitrc`, `.config/i3/config`, `.config/rofi/config.rasi`, GTK config files
5. Editor set: `.vimrc`, `.spacemacs`, `.config/Code/User/settings.json`
6. Helper scripts: setup/update and selected scripts under `.local/bin/tools/`
7. Repo docs and metadata: `README.md`, `TODO.org`, `LICENSE`

### Story 1.2 conclusion

Story 1.2 is complete at the inventory level. The next step is detailed file-by-file reconciliation, starting with shell startup files. Each file should be reviewed using YADM-aware diffs and live-home checks before adopting repo, adopting live, merging, archiving, or deleting.

---

## Recommended next actions

1. Do not run `yadm upgrade` until explicitly approved.
2. Use explicit legacy YADM flags for read-only inspection until YADM is upgraded or reconfigured.
3. Reconcile shell startup files first: `.zshrc`, `.profile`, `.bashrc`, `.bash_profile`, `.zsh_plugins.sh`, `.zsh_plugins.txt`.
4. Decide whether to use the normal Git checkout or legacy YADM repo as the primary working path for cleanup.
5. Review the one local commit ahead in legacy YADM before pushing or rebasing anything.
6. Review the modified `polybar` state carefully because normal Git and legacy YADM report it differently.
7. Convert package inventory into grouped triage docs before editing install manifests.
