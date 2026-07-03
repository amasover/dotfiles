# Decision: bootstrap & system-management architecture

**Status:** accepted (Story 2.5, 2026-07-01) · Issue: [#27](https://github.com/amasover/dotfiles/issues/27)
**Supersedes:** the open question in [bootstrap-architecture-notes.md](./bootstrap-architecture-notes.md)
**Executed by:** Story 2.8 [#48](https://github.com/amasover/dotfiles/issues/48) (metapac adoption),
Story 2.9 [#49](https://github.com/amasover/dotfiles/issues/49) (inbox + drift report),
Story 2.3 [#25](https://github.com/amasover/dotfiles/issues/25) (thin `bootstrap` + runbook),
Story 2.7 [#46](https://github.com/amasover/dotfiles/issues/46) (VM validation),
Story 2.10 [#50](https://github.com/amasover/dotfiles/issues/50) (install-time gating — metal prerequisite)

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

**Caveat (grill 2026-07-02): the quarantine gates *upgrades*, not *installs*.** The hook
is `UpgradeSelect`, and the trusted-maintainer baseline is machine-local state
(`~/.local/state/aur-quarantine/`), so a fresh-machine `metapac sync` installs every AUR
package at whatever version is current that day — ungated, with no baseline. Routing
through yay is necessary but not yet sufficient for bootstrap-day safety.
**Prerequisite:** install-time gating (the 2.6 `AURPostDownload` follow-up) plus
baseline portability must land before `bootstrap` is trusted on real metal — ticketed
as **Story 2.10** ([#50](https://github.com/amasover/dotfiles/issues/50)). Disposable
2.7 VM runs are exempt.

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
  # (each host lists only its OWN inbox — see auto-capture below)
  "<this-workstation>" = ["base", "shell-cli", "desktop", "development", "media", "comms", "work", "inbox-<this-workstation>"]
  # future personal laptop example:
  # "<laptop>" = ["base", "shell-cli", "desktop", "inbox-<laptop>"]
  ```

  (Real hostnames stay out of this public doc; the tracked `config.toml` will contain
  them — hostnames in dotfiles are already the repo's accepted exposure level, but the
  work-issued hostname should be reviewed in the Story 2.2 privacy follow-up before push.)

- **Groups** (`groups/*.toml`) = the Story 2.2 purpose groups made executable:
  `base` (any Linux box: core CLI), `shell-cli`, `desktop`, `development`, `media`,
  `comms`, `work` (opt-in per host, from decision D2), `inbox-<hostname>` (see below).
  Per-package `hooks` handle service enablement next to the package that needs it
  (e.g. `after_sync` → `systemctl enable`).

- **Auto-capture of new installs (Aaron's requirement):** a small **yay `PostInstall`
  Lua hook** appends newly *explicitly* installed packages (payload has `reason` +
  `source`, and `local_version` is empty on a first install — upgrades are skipped)
  that aren't declared in any group to **`groups/inbox-<hostname>.toml`** — one inbox
  file per host, each host's group list naming only its own (grill 2026-07-02: a single
  shared `inbox.toml` would auto-*install* untriaged packages onto every other machine
  at its next `metapac sync`, and is a merge-conflict magnet once a second machine
  exists). Inbox files stay YADM-tracked so untriaged drift is visible in `yadm status`.
  Triage flow: packages land in the host's inbox automatically at install time; Aaron
  periodically moves them to their proper group (or drops them, and `metapac clean`
  proposes the uninstall). Backstop: `metapac unmanaged` catches anything the hook
  misses (e.g. raw `pacman -S` installs, which don't pass through yay hooks).

- **Drift loop:** `metapac sync` (declared-but-missing) / `clean` (installed-but-
  undeclared) / `unmanaged` — all show a plan and prompt before acting, which satisfies
  most of Story 2.4's dry-run requirement out of the box.
  **Steady-state cadence (grill 2026-07-02):** `setup/update` appends a **read-only
  drift report** (`metapac unmanaged` + declared-but-missing) to its end-of-run output —
  the same report-then-human-acts pattern as the 2.6 quarantine report — ending with the
  copy-paste `metapac sync` command. `sync`/`clean` themselves stay manual, prompted
  commands and never run unattended: reporting drift on every update keeps the manifest
  honest without auto-mutation (rot killed the 2019 `install`; silent `--no-confirm`
  mutation is the opposite failure).

- **Lock-in risk accepted:** metapac is young (pacdef's maintained successor, active
  releases). Mitigation: group files are just package lists — worst case they degrade to
  `pacman -S --needed` input. Low exit cost.

## Bootstrap (Story 2.3 executes; metapac adoption itself is Story 2.8)

Thin bash, ~50 lines, linear, idempotent by delegation:

1. (manual / `archinstall`: disk, base system, network, user)
2. install `yay` (bootstrap from AUR with makepkg once)
3. `yadm clone` → decrypt secrets → dotfiles + metapac config in place.
   (Decrypt is **passphrase-interactive** — yadm uses default symmetric GPG, no
   `gpg-recipient` configured — so no key-transfer step, but no unattended decrypt.)
4. **Profile guard (grill 2026-07-02):** if this hostname has no `[hostname_groups]`
   entry, hard-fail with copy-paste instructions — edit `config.toml`, choose this
   host's groups, re-run. Without the guard, an unknown hostname makes `sync` a silent
   no-op and a later `clean` would propose removing everything. Choosing the groups on
   this line **is** Story 2.3's "desktop optional unless explicitly selected" step; the
   edit rides back to the repo via a later yadm commit.
5. `metapac sync` → all packages incl. AUR (through yay), service hooks fire
6. quarantine trust state in place (baseline restore/seed — mechanism comes from the
   install-gating prerequisite story, see caveat above)
7. done — reboot into the desktop

Bash is adequate *because* every hard part is delegated (yadm: files/secrets; metapac:
package idempotency; yay: AUR + quarantine).

## Adoption on the live machine (reconcile #0 — Story 2.8)

The first real reconcile is not a fresh machine — it's pointing metapac at the current
workstation once the groups are authored (grill 2026-07-02; ticketed as
[#48](https://github.com/amasover/dotfiles/issues/48), with the steady-state
inbox/drift-report loop as Story 2.9, [#49](https://github.com/amasover/dotfiles/issues/49)). Two rules for that window:

- **`metapac clean` is off-limits until `metapac unmanaged` comes back (near-)empty.**
  While groups are incomplete, `unmanaged` lists hundreds of packages and `clean` would
  offer to uninstall every one of them — a wall-of-yes prompt, not a safety net.
- **Empty `unmanaged` is the acceptance test for adoption.** Fresh-path validation
  (the 2.7 VM harness) only means something after live adoption reaches that point.

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

## Interim safe path (until 2.8/2.9/2.3/2.7 land)

Nothing changes on the live machine: `setup/update` + the yay quarantine keep working
as-is; old flat manifests remain as historical reference until the metapac groups
replace them.
