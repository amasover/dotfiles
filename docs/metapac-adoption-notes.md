# Story 2.8 — metapac adoption notes

Evidence artifact for [#48](https://github.com/amasover/dotfiles/issues/48). Design:
[decision-bootstrap-architecture.md](./decision-bootstrap-architecture.md). Triage
source: [package-inventory.md](./package-inventory.md) (see its 2.8 execution addendum).

## Acceptance result

**`metapac unmanaged` → "no unmanaged packages" (exactly empty), 2026-07-02.**

Final arithmetic: 378 explicitly-installed packages = 375 declared across the tracked
groups + 3 in the untracked machine-local group. Verified by set-comparison of
`pacman -Qqe` against the union of all group members (no duplicates across groups, no
declared-but-not-installed entries), then by the live `metapac unmanaged` run.

## Artifacts

- **`.config/metapac/config.toml##template`** — yadm template. `yadm.class` (set live:
  `yadm config local.class workstation`) selects the group list; `{{ yadm.hostname }}`
  and `{{ env.HOME }}` render at checkout. No hostname or username reaches the repo.
- **`.config/metapac/groups/*.toml`** — 16 purpose groups (2.2 taxonomy, normative:
  core-system→`base`, cloud-infra→`work`) + `inbox-workstation.toml` (empty at
  adoption; Story 2.9's hook appends to it).
- **`~/.local/share/metapac/machine-local.toml`** — untracked, absolute-path group
  holding the three never-publish org-internal package names (Story 2.11 reviews them).
  Not durable across a wipe — accepted in the 2.5 decision.

## metapac 0.9.4 behaviors verified empirically

- `unmanaged` compares **explicitly-installed** packages only (deps never appear).
- Absolute-path entries in `hostname_groups` work with or without the `.toml` suffix.
- A **missing group file is a hard error** (exit 1) — any machine whose class list
  references `machine-local.toml` must create it (empty is fine) before the first
  metapac run. Story 2.3's bootstrap owns that step, plus the profile guard.
- Empty groups (`packages = []`) parse fine.
- A `--hostname` CLI override exists (decision doc corrected) — rejected in favor of
  the template; a per-invocation flag would need to reach every script/hook.

## Placement calls made during adoption (veto welcome)

Post-inventory arrivals and dual-listed packages got a primary group:
`bluez`/`bluez-utils`/`bluetui`→desktop · `tailscale`/`s-nail`/`systemd-resolvconf`→network-vpn ·
`kind`→work · `strace`/`chatmcp`/`cloc`/`gource`→development · `gitleaks`/`pwgen`→security ·
`keychain`→shell-cli · `kwallet5`→desktop · `gpick`→desktop · `sshuttle`→network-vpn ·
`jfbview`/`kooha`→media · `git-credential-manager-bin`→development ·
`gparted`/`plocate`/`fcron`/`haveged`/`dialog`/`uudeview`/`yadm`/`yay-bin`/`paru-bin`→base ·
`systemd-lock-handler`/`perl-anyevent-i3`→desktop · `lsdesktopf`→optional (D9 reversed).

## Steady-state capture loop (Story 2.9, live 2026-07-03)

- **Auto-capture:** yay `PostInstall` hook (second autocmd in `.config/yay/init.lua`)
  appends fresh explicit installs (`local_version == ""`; upgrades/reinstalls skipped,
  deps skipped) that no group declares to `groups/inbox-<class>.toml`. The inbox file
  is discovered by glob (exactly one per machine); the declared-set scan covers the
  groups dir plus absolute-path groups from the rendered config.
- **Nudge:** `.local/bin/tools/metapac-drift-report` (also run at the end of
  `setup/update`) prints three read-only sections — unmanaged (raw-pacman backstop),
  declared-but-missing (+ copy-paste `metapac sync`), and **inbox triage** (count,
  names, file to edit). The inbox section is the periodic-review mechanism: inboxed
  packages are *declared*, so `unmanaged` alone never surfaces them.
- **Live validation:** stubbed-yay offline test (4 skip/capture cases), then a real
  `yay -S figlet shellcheck` — both captured inline, nudge fired, then triaged:
  shellcheck → `development` (kept), figlet uninstalled; end state back to
  exactly-empty everywhere.
- yay through the agent shell needs `--sudo /usr/bin/pkexec` (sudo can't prompt there).

## Gotchas for future machines

- **polybar**: the machine's only polybar is `polybar-wireguard-git` (provides
  `polybar`); groups declare the real name. It is the bar **plus** Aaron's VPN
  indicator — it shows VPN connectivity in the bottom bar on the work
  machine and may serve as the VPN-status indicator on other machines. It lives in
  `desktop` (not `work`) because it is also the bar itself. A fresh `metapac sync`
  builds this AUR package, not repo polybar (see
  [pacman-provides note](../knowledge/reference/pacman-provides-and-binary-ownership.md)).
- **nodejs/npm** are nvm-managed (update loop), not pacman — intentionally undeclared.
- **kind without docker**: use `KIND_EXPERIMENTAL_PROVIDER=podman` (docker dropped, D5).
- **First `yadm checkout` on this machine** will meet the hand-rendered (identical)
  untracked live copies under `~/.config/metapac/` — expect git's refusal to overwrite
  untracked files; resolve by removing the local copies first (contents match the repo).
- Legacy flat manifests (`.config/dotfiles/arch-packages/{pacman,aur}`) are retired; a
  pointer README remains, history via git log.
