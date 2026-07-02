# Decision: bootstrap & system-management architecture

**Status:** accepted (Story 2.5, 2026-07-01) · Issue: [#27](https://github.com/amasover/dotfiles/issues/27)
**Supersedes:** the open question in [bootstrap-architecture-notes.md](./bootstrap-architecture-notes.md)
**Executed by:** Story 2.3 (bootstrap + manifests), Story 2.7 (VM validation)

## Decision

**Compose specialized tools; don't adopt one big system manager.**

| Layer | Owner | Notes |
| --- | --- | --- |
| `$HOME` dotfiles + secrets | **YADM** (unchanged) | placement + encryption already work |
| Package state (native + AUR) | **metapac**, driving **yay** | declarative TOML groups; universal + per-machine |
| Package updates | **`setup/update`** (unchanged) | imperative loop; AUR quarantine hook stays authoritative |
| Fresh-machine sequencing | new thin bash **`bootstrap`** | replaces dead 2019 `setup/install` |
| `/etc` + services | deferred (see gaps) | services via metapac hooks; `/etc` tracked minimally |

Guiding principle discovered in Story 2.6: **everything that touches AUR packages must go
*through* yay, never around it** — the quarantine hook (age/orphan/maintainer gating) and
trusted-maintainer baseline live in yay, and any tool that builds AUR packages itself
silently bypasses that security layer.

## The problem, decomposed

"Bootstrap and continually manage a live system" is **two loops**:

- **Reconcile loop (declarative):** make the machine match the manifest — packages,
  services, dotfiles. A fresh install is just the first reconcile.
- **Update loop (imperative):** advance versions carefully — repo/AUR upgrades under
  quarantine, oh-my-zsh, nvm/npm, rustup, plugins. Inherently sequential/stateful;
  no declarative tool replaces it. `setup/update` **is** this loop already.

## Package layer design (metapac)

Config lives in `.config/metapac/` (yadm-tracked → placed on every machine).

- **Universal vs machine-specific** (`config.toml`):

  ```toml
  hostname_groups_enabled = true

  [arch]
  package_manager = "yay"   # REQUIRED: preserves the Story 2.6 quarantine stack

  [hostname_groups]
  # every machine gets the universal groups; hosts add their own profile
  "<this-workstation>" = ["base", "shell-cli", "desktop", "development", "media", "comms", "work", "inbox"]
  # future personal laptop example:
  # "<laptop>" = ["base", "shell-cli", "desktop", "inbox"]
  ```

  (Real hostnames stay out of this public doc; the tracked `config.toml` will contain
  them — hostnames in dotfiles are already the repo's accepted exposure level, but the
  work-issued hostname should be reviewed in the Story 2.2 privacy follow-up before push.)

- **Groups** (`groups/*.toml`) = the Story 2.2 purpose groups made executable:
  `base` (any Linux box: core CLI), `shell-cli`, `desktop`, `development`, `media`,
  `comms`, `work` (opt-in per host, from decision D2), `inbox` (see below).
  Per-package `hooks` handle service enablement next to the package that needs it
  (e.g. `after_sync` → `systemctl enable`).

- **Auto-capture of new installs (Aaron's requirement):** a small **yay `PostInstall`
  Lua hook** appends newly *explicitly* installed packages (payload has `reason` +
  `source`) that aren't declared in any group to `groups/inbox.toml`. Triage flow:
  packages land in `inbox` automatically at install time; Aaron periodically moves them
  to their proper group (or drops them, and `metapac clean` proposes the uninstall).
  Backstop: `metapac unmanaged` catches anything the hook misses (e.g. raw
  `pacman -S` installs, which don't pass through yay hooks).

- **Drift loop:** `metapac sync` (declared-but-missing) / `clean` (installed-but-
  undeclared) / `unmanaged` — all show a plan and prompt before acting, which satisfies
  most of Story 2.4's dry-run requirement out of the box.

- **Lock-in risk accepted:** metapac is young (pacdef's maintained successor, active
  releases). Mitigation: group files are just package lists — worst case they degrade to
  `pacman -S --needed` input. Low exit cost.

## Bootstrap (Story 2.3 executes)

Thin bash, ~50 lines, linear, idempotent by delegation:

1. (manual / `archinstall`: disk, base system, network, user)
2. install `yay` (bootstrap from AUR with makepkg once)
3. `yadm clone` → decrypt secrets → dotfiles + metapac config in place
4. `metapac sync` → all packages incl. AUR (through yay), service hooks fire
5. done — reboot into the desktop

Bash is adequate *because* every hard part is delegated (yadm: files/secrets; metapac:
package idempotency; yay: AUR + quarantine).

## Rejected / deferred (with re-open triggers)

- **decman** (Python-config declarative Arch manager, active): rejected — builds AUR
  via its own `makepkg` path, **bypassing the yay quarantine**; config executes as
  root; wants to own dotfiles/units (YADM's turf). Would mean re-implementing Story 2.6
  inside it.
- **aconfmgr**: *not* stale (commits through June 2026 — corrects the notes' assumption),
  but AUR handling is explicitly limited and its bash-DSL would own layers already
  owned elsewhere. Its `/etc`-tracking pattern is the part worth stealing.
  **Trigger:** hand-tracked `/etc` files exceed ~a dozen or untracked drift bites.
- **Ansible / pyinfra**: machinery for N machines; we have 1. **Trigger:** a second
  managed machine, or orchestration beyond hostname groups. Preference then: pyinfra
  `@local` (Python-native, lighter) over reviving `dot-ansible` patterns.
- **home-manager / Nix**: competes with YADM for `$HOME`; a succession decision, not a
  bootstrap tweak. **Trigger:** wanting reproducible userland or seriously moving
  toward NixOS. Full NixOS remains explicitly on the table long-term.
- **Go/bespoke CLI as the engine**: unchanged from the notes — chicken-and-egg +
  re-implementing idempotency. A personal CLI for imperative QoL commands stays fine.

## Known gaps (deliberate)

- **`/etc` is unmanaged.** Interim: track the handful of known-edited files (e.g. the
  NetworkManager `wifi_backend.conf` found in 2.2) in the repo with a tiny apply
  script — future story. aconfmgr is the named candidate if this grows.
- **Language-package sprawl** (`npm -g`, pipx, cargo installs in `update`): metapac has
  backends for these; consolidation is a later, optional step.

## Validation strategy

**Story 2.7 (new): QEMU/KVM fresh-install harness** — scripted `archinstall` into a
QEMU VM (qemu-desktop + virt-manager already installed, kept in 2.2 D6), run
`bootstrap`, boot, and verify the result matches expectations (packages: `metapac
unmanaged` comes back clean; services enabled; desktop reachable). Disposable via
snapshots. This is the pre-metal gate for all bootstrap changes.

## Interim safe path (until 2.3/2.7 land)

Nothing changes on the live machine: `setup/update` + the yay quarantine keep working
as-is; old flat manifests remain as historical reference until the metapac groups
replace them.
