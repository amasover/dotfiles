# Package Inventory & Triage — Story 2.2

Evidence artifact for [Epic 2, Story 2.2](./epic-2-bootstrap-and-package-modernization.md)
(Inventory local packages and split manifests by purpose). Status/discussion live
on issue [#24](https://github.com/amasover/dotfiles/issues/24) and the
[board](https://github.com/users/amasover/projects/1/views/1).

**Read-only inventory.** No packages were installed or removed to produce this
(except `expac` + `metapac`, which Aaron installed at my request as triage tooling).
Method notes and the `provides` gotcha are in
[knowledge/reference/pacman-provides-and-binary-ownership.md](../knowledge/reference/pacman-provides-and-binary-ownership.md).

---

## Headline findings

1. **The old manifests are both stale and incomplete.** `.config/dotfiles/arch-packages/{pacman,aur}`
   is a flat, undated ~226-package dump from the Antergos/i3-gaps era. Live machine
   has **287 explicit-native + 100 explicit-AUR** packages. The manifests can't be
   line-edited into shape — the new manifests should be **rebuilt from live state,
   grouped by purpose**, with the old list used only to spot drops.
2. **The machine was re-provisioned in two big batches** (`expac` install dates):
   ~**2026-04-20** and ~**2026-06-05**. Most "missing from manifest" packages aren't
   cruft — they're the *current* workstation. Genuine legacy survivors are the
   old-dated rows (2019–2023).
3. **Tooling chosen:** `expac` for dated/sized inventory; `metapac` (maintained
   successor to `pacdef`) under evaluation as the durable grouped-manifest model.
   Adopting metapac vs plain grouped files is a **Story 2.5 decision** — not made here.

### Counts (authoritative, per-package `pacman -Q` checks)

| Set | Count | Command |
| --- | --- | --- |
| Explicit native | 287 | `pacman -Qqen` |
| Explicit AUR/foreign | 100 | `pacman -Qqem` |
| True top-level (explicit, required by nothing) | 299 | `pacman -Qqett` |
| Total installed | 1739 | `pacman -Qq` |
| Orphans (dep, required by nothing) | 10 | `pacman -Qqtd` |

> Caveat: `pacman -Qq <name>` resolves `provides`, so per-name checks and the
> real-name `-Qq` list answer different questions. See the knowledge note.

---

## Old manifest reconciliation (`pacman` file, 203 entries)

Each old entry classified SELF / PROVIDED-BY / ABSENT.

### Superseded → update manifest to the real package name (8)

| Old entry | Now provided by | Note |
| --- | --- | --- |
| `bind-tools` | `bind` | merged upstream |
| `crda` | `wireless-regdb` | crda retired |
| `exa` | `eza` | maintained fork |
| `mlocate` | `plocate` | faster locate; compat name |
| `networkmanager` | `networkmanager-iwd` | iwd-enabled NM build (see Networking below) |
| `terraform` | `tenv-bin` | you manage terraform via tenv |
| `vi` | `ex-vi-compat` | provides `vi` |
| `vim` | `gvim` | gvim provides `vim` |

### Truly absent → drop or mark optional (15)

`antergos-keyring`, `antergos-midnight-timers`, `antergos-mirrorlist` (dead distro,
EOL 2019) · `nvidia-390xx`, `nvidia-390xx-settings`, `nvidia-390xx-utils`,
`lib32-nvidia-390xx-utils` (legacy NVIDIA — machine is now **AMD**: `vulkan-radeon`,
`xf86-video-amdgpu`) · `compton` (no compositor installed now) · `pulseaudio`
(→ PipeWire: `pipewire-pulse`) · `termite` (dead terminal → `alacritty`) ·
`reiserfsprogs` (reiserfs deprecated) · `dropbox`, `steam`, `task`, `pgadmin4`
(not installed — optional/per-machine).

## Old manifest reconciliation (`aur` file, 23 entries)

### Superseded by a non-`-git` / native equivalent → drop the old entry

`arc-gtk-theme-git`→`arc-gtk-theme` · `flashfocus-git`→`flashfocus` ·
`polybar-git`→`polybar` (native) · `yadm-git`→`yadm` (native) ·
`i3-gaps-next-git`→`i3-wm` (i3-gaps merged into i3) · `paper-icon-theme`→`papirus-icon-theme`.

### Truly absent → drop or mark optional

`ckb-next` (Corsair kbd) · `minecraft-launcher` (gaming) · `mirage` (image viewer) ·
`openfortivpn` · `remmina-plugin-rdesktop` · `slack-desktop` · `spotify` ·
`wpa_actiond` (netctl-era).

---

## Networking — actual live setup (you asked)

- **NetworkManager** enabled + active; the providing package is **`networkmanager-iwd`**
  (not vanilla `networkmanager`). `systemd-resolved` handles DNS. `netctl`/`dhcpcd` off.
- **Wi-Fi backend is `wpa_supplicant`**, set explicitly in
  `/etc/NetworkManager/conf.d/wifi_backend.conf` (`wifi.backend=wpa_supplicant`).
- **`iwd.service` is also enabled + active but unused as the NM backend** — redundant
  or intended for standalone use. → **Open question N1.**

---

## Proposed purpose groups (rebuilt from live state)

Grouping is **proposed** — the genuinely ambiguous calls are deferred to the Open
Questions below before manifests are split. Native = official repos; **bold** = AUR.

- **core-system** — base/kernel/fs/boot/toolchain: `filesystem` `linux` `linux-headers`
  `linux-firmware` `intel-ucode` `systemd*` `glibc` `coreutils` `bash` `sudo` `shadow`
  `util-linux` `pacman-contrib` `pkgfile` `reflector` `licenses` `man-db`/`man-pages`
  GNU build (`gcc` `make` `autoconf` `automake` `binutils` `bison` `flex` `m4` `libtool`
  `patch` `pkgconf` `fakeroot`) · filesystems (`btrfs-progs` `e2fsprogs` `dosfstools`
  `exfat-utils` `f2fs-tools` `jfsutils` `nilfs-utils` `xfsprogs` `ntfs-3g` `cryptsetup`
  `cryfs` `lvm2` `mdadm` `dmraid` `device-mapper` `cifs-utils` `nfs-utils`) · UEFI/secure-boot
  (`efibootmgr` `efivar` `edk2-shell` `refind` `sbsigntools` `pesign` `bolt` **shim-signed**
  **mokutil-git** **refind-theme-nord** **bootinfoscript**) · archives (`tar` `zip` `unzip`
  `7zip` `unrar` `gzip` `bzip2` `xz` `cabextract` `sharutils`)
- **shell-cli** — `zsh` `bash-completion` `keychain` `screen` `ranger` `broot` `htop`
  `gtop` `ncdu` `tree` `ripgrep` `the_silver_searcher` `jq` `jaq` `yq` `eza` `entr` `pv`
  `dos2unix` `calc` `cloc` `gource` `w3m` `expac` **antibody** **bashmount** **ccat** **metapac**
- **editor** — `neovim` `gvim` `emacs` `nano` `ex-vi-compat` `intellij-idea-community-edition`
  `editorconfig-core-c` `autopep8` **visual-studio-code-bin** **nord-vim** **omnisharp-roslyn-bin**
- **desktop** — Xorg (`xorg-server` `xorg-xinit` `xorg-server-xephyr` `xorg-appres`
  `xorg-xev` `xorg-xfd` `xorg-xkill`) · GPU (`xf86-video-amdgpu` `xf86-video-intel`
  `xf86-video-vesa` `vulkan-radeon` `lib32-vulkan-radeon` `lib32-glu`) · WM/bar/launcher
  (`i3-wm` `i3lock` `polybar` `rofi` `dunst` `conky` **polybar-wireguard-git** **siji-git**
  **flashfocus**) · session/util (`feh` `redshift` `parcellite` `lxappearance` `lxqt-policykit`
  `network-manager-applet` `arandr` `autorandr` `xbindkeys` `xclip` `scrot` `kwallet5`
  `gpick` `thunar` `tumbler` `alacritty` `ibus-chewing` **xautolock** **xidlehook**
  **colorpicker** **clight** **clight-gui-git** **hardcode-tray** **lsdesktopf**) ·
  themes/fonts (`terminus-font` `ttf-liberation` `ttf-nerd-fonts-symbols*` `noto-fonts`
  `noto-fonts-emoji` `awesome-terminal-fonts` `adobe-source-code-pro-fonts`
  `papirus-icon-theme` `opendesktop-fonts` **arc-gtk-theme** **arc-solid-gtk-theme**
  **noto-fonts-sc** **noto-fonts-tc**) · login (`lightdm-webkit-theme-litarvan`)
- **development** — languages/runtimes (`go` `go-tools` `rustup` `python-pip` `python-pipx`
  `pyenv` `uv` `nodejs` `npm` `groovy` `mono-msbuild` `nuget` **golangci-lint-bin**
  **dotnet-sdk-bin** **dotnet-sdk-9.0-bin** **aspnet-runtime-bin** **aspnet-runtime-9.0-bin**
  **powershell-bin** **nodejs-vmd**) · containers (`docker` `docker-compose` `podman`) ·
  VCS/tools (`git` `github-cli` `mercurial` `gitleaks` `ansible` `facter` `graphviz`
  `cloc` `gource` `unixodbc` **bfg** **changie** **ansible-aur-git** **redis**
  **python-pymssql** **brew-git** **claude-code** **chatmcp** **debtap**)
- **cloud-infra (work?)** — `azure-cli` `azcopy` `kubectl` `helm` `k9s` `kustomize`
  `istio` **azure-functions-core-tools-bin** **storageexplorer** **aztfexport-bin**
  **databricks-cli-bin** **krew-bin** **kube-capacity** **terraform-ls-bin** **tenv-bin**
  **astro-cli** **ngrok** **yor-bin** **uplink** **wstunnel-bin** · → **Open question Q2**
- **network-vpn** — `networkmanager-iwd` `iwd` `wpa_supplicant` `networkmanager-openvpn`
  `openvpn` `openconnect` `globalprotect-openconnect` `wireguard-tools` `sshuttle`
  `udp2raw` `dnsmasq` `bind` `nmap` `traceroute` `whois` `net-tools` `inetutils`
  `iproute2` `iputils` `ipset` `ipcalc` `ipv6calc` `nss-mdns` `ntp` `modemmanager`
  `netctl` `dhcpcd` `b43-fwcutter` `usb_modeswitch` `samba` `rsync` `openssh` `putty`
  `freerdp` `remmina` `filezilla` `wireshark-qt` `siege` **networkmanager-dispatcher-ntpd**
  **iwgtk** **openconnect-service** **openvpn-update-systemd-resolved** **vpn-slice**
  **netmask** **subnetcalc** **gss-ntlmssp** **smtp-cli** **ssmtp** **gnu-netcat** ·
  → **Open question Q3** (VPN sprawl)
- **media** — `vlc` `mpv` `yt-dlp` `playerctl` `ffmpegthumbnailer` `imagemagick` `gimp`
  `pavucontrol` `pamixer` `alsa-utils` `pipewire-pulse` `tesseract` `perl-image-exiftool`
  `zathura` `zathura-ps` `guvcview` **tidal-hifi-bin** **feishin-bin** **cli-visualizer**
  · screen-record (`peek` **byzanz** **kazam** **simplescreenrecorder**) → **Open question Q4**
- **comms** — `signal-desktop` `discord` `weechat` **teams-for-linux-bin** **zoom**
  **bitlbee** **chatmcp**
- **browsers** — `firefox` `qutebrowser` **google-chrome** → all three? (Q5)
- **office/docs** — `libreoffice-fresh` **anki-bin** **yed**
- **printing** — `cups` `hplip` `gutenprint` `foomatic-db` `system-config-printer` (Q6)
- **virt** — `virtualbox` `virtualbox-host-modules-arch` `virt-manager` `virt-viewer`
  `qemu-desktop` (+ `docker`/`podman` above) → **Open question Q7**
- **gaming** — `lutris` (+ legacy `steam`/`minecraft-launcher`, not installed)
- **security** — **1password** `kwallet5` `keychain` `gitleaks` **sedutil** `gnupg`(dep)
- **optional/toys** — `sl` `cmatrix` `screenfetch` `barcode` `gpick` `discount`
  `arch-install-scripts` **inotify-info** **ext4magic** **extundelete** **downgrade**
  **yaycache-hook** **teensy-loader** **displaylink** **evdi-dkms** **sshuttle**
- **needs-verification / remove-candidate** — see below

### Orphans (installed as deps, required by nothing) — `pacman -Qqtd`

`cmake` `ipython` `meson` `perl-yaml` `pybind11` `python-grpcio` `python-hypothesis`
`python-sqlalchemy` `python-tabulate` `vala`. Likely leftovers from a build/AUR
compile. Read-only note only — **not removing anything** (Hard rule 3/5).

### needs-verification / likely stale (old install dates, low confidence)

3 org-internal AUR pkgs — CA certs / print service / VPN client; org-prefixed names
**redacted** (see [Privacy note](#privacy-note--redacted-package-names))
(2019–2021, Ubuntu-derived — odd on Arch) · `lsdesktopf` (2019) · `python2-bin`
(Python 2 EOL) · `python-cbeams-git` (2021) · `nodejs-vmd` (2021) · `trizen`
(superseded AUR helper) · `ccat` (superseded by `bat`?) · `antibody` (zsh plugin
manager — still used? Story 3.1/3.8 will confirm) · `bitlbee` (IRC gateway) ·
`sedutil` (self-encrypting drives — still relevant?).

---

## AUR helper / package-manager sprawl

Installed simultaneously: **`yay`**, **`paru`**, **`trizen`** (legacy), plus
**`brew`** (Homebrew on Linux) and now **`metapac`**. Five ways to install packages.
→ **Open question Q1** (standardize bootstrap on one AUR helper; `trizen` is clearly
droppable).

---

## Triage decisions (resolved with Aaron, 2026-06-24)

- **D1 AUR helper:** `yay` = daily driver (primary). Keep `paru` as backup, `brew` for the
  occasional linux-brew-only package. `trizen` **uninstalled** (already gone live). `metapac`
  retained for the declarative-group evaluation. Bootstrap installs yay (+ paru, brew).
- **D2 Work profile (NEW optional `work` group):** Split the Azure/k8s/dotnet/databricks/istio
  stack into a separate optional `work` manifest so a personal fresh install can skip it.
  `globalprotect-openconnect` (+ its `openconnect` companion) belongs to `work` too.
- **D3 VPN:** Keep all — each serves a different purpose; `globalprotect-openconnect` uses
  `openconnect`. No VPN drops.
- **D4 Browsers:** Keep all three (`firefox`, `qutebrowser`, `google-chrome`).
- **D5 Containers:** **Drop `docker` + `docker-compose`** (→ `podman`). But see cross-ref **C2**.
- **D6 Virtualization:** **Drop `virtualbox` + `virtualbox-host-modules-arch`**; keep
  `qemu-desktop` + `virt-manager` + `virt-viewer`.
- **D7 Screen recorders:** Deferred to **Story 3.10** ([#42](https://github.com/amasover/dotfiles/issues/42),
  kooha eval; recording libs reportedly broken pending reboot). No screen-recorder changes here.
- **D8 ccat → bat:** `ccat` **uninstalled**, replaced by `bat` (installed). See cross-ref **C1**.
- **D9 Removable leaves:** `lsdesktopf`, `python-cbeams-git` — drop from bootstrap;
  live-uninstall safe (separate gated step). `python2-bin` is contingent on the powerline
  migration (C4). **`nodejs-vmd` is KEPT** — Aaron confirms still needed (C3).
- **D10 org-internal AUR pkgs (names redacted):** Aaron to investigate → stays **needs-verify**, no change. Real names in the private note (see [Privacy note](#privacy-note--redacted-package-names)).
- **Still open (later pass):** printing stack, `bitlbee`, `antibody`, `sedutil` → keep for now
  (revisit in Story 3.1/3.2). **N1 networking** is now its own story, **3.9** ([#41](https://github.com/amasover/dotfiles/issues/41)).

## Dotfile cross-references — removal safety

Aaron's ask: check the *dotfiles*, not just pacman reverse-deps. Grep of the repo + live
`$HOME` scripts/rc/desktop config (legacy `setup/install`, `han_setup.bash` excluded as
known-dead):

- **C1 — `cat` broken → FIXED live by Aaron.** Was `~/.zshrc:209 alias cat="ccat"`; Aaron
  changed live `~/.zshrc` to `alias cat="bat"`. **Repo `.zshrc` still has `ccat`** (diverged) —
  promote the live fix to the repo via the yadm reverse-test flow (`yadm add ~/.zshrc` → commit
  → push → `git pull`), Aaron-gated. Dead `homelab-*` aliases (279–281) + `docker` omz plugin
  (82) remain in both → clean in **Story 3.1** when docker is dropped.
- **C2 — docker is a CLEAN drop (resolved).** The only live consumers were `~/.zshrc:279–281`
  `homelab-up/down/status` (Swarm) — Aaron confirms **homelab is no longer used**. So those
  aliases, the oh-my-zsh `docker` plugin entry (`~/.zshrc:82`), and the `.spacemacs` docker
  layer are now **dead lines to remove** when docker is dropped. No workflow breaks.
- **C3 — `nodejs-vmd`: KEEP.** It's `.spacemacs`'s markdown-live-preview engine
  (`vmd`, `vmd-mode`); Aaron confirms it's still needed despite being old. Tie its fate to the
  spacemacs decision (Story 3.2), don't drop it now.
- **C4 — `python2-bin` / powerline:** `~/.zshrc:352–353` sources python2.7 powerline via an
  **outdated method** — Aaron notes powerline now ships a daemon ([Arch wiki](https://wiki.archlinux.org/title/Powerline)),
  so the sourcing should be modernized. Queued on **Story 3.1** ([#28](https://github.com/amasover/dotfiles/issues/28)).
  `python2-bin` removal is contingent on that migration (it likely moves to python3 powerline or a different prompt).
- **C5 — `virtualbox`:** only **commented-out** refs (`.xinitrc`, `i3 config:388–389`) +
  legacy scripts → no active dotfile dependency, safe re: dotfiles.
- **C6 — `lsdesktopf`, `python-cbeams-git`:** no dotfile references → safe re: dotfiles.

---

## Privacy note — redacted package names

This repo is **public**. Three AUR packages on the live machine are org-internal and
their org-prefixed names are **redacted** above (the "3 org-internal AUR pkgs" in
needs-verification and **D10**). They are real and still needed for later triage, so the
real names are preserved in a **private, gitignored** note that is not published:

- **Private key:** `docs/private/package-inventory-private.md` (gitignored — never committed).
- **Recover live:** the future-cleanup step is to scan the machine for the org-prefixed
  AUR packages (`pacman -Qqm`) and match them to the private note.
- **Durability:** the private note is machine-local and **not versioned** — it survives a
  context reset but not a machine wipe. To make it durable/portable, promote it to
  YADM-encrypted storage (add its path to `.config/yadm/encrypt`, then `yadm encrypt`) —
  a gated follow-up, not done here.

## Next steps

1. Generate the grouped manifests from live state (incl. the optional `work` split); record drops + reasons.
2. Manifest format — plain grouped files vs `metapac` groups → **Story 2.5** decision.
3. Promote the live `cat`→`bat` fix to the repo `.zshrc` via yadm reverse-test (Aaron-gated); queue
   the other `.zshrc` cleanups (dead `homelab-*`/docker plugin, powerline daemon) on **Story 3.1**.
4. Optional gated live-uninstall of docker/virtualbox + leaf removables (D9).

> C1 (`cat` alias) and C2 (docker/homelab) are resolved — see Dotfile cross-references.
