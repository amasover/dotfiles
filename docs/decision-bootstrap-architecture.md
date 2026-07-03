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

- **Universal vs machine-specific** (grill 2026-07-02): metapac's config offers **no
  hostname alias** (correction, found during 2.8: v0.9.4 does have a `--hostname` CLI
  override, but a per-invocation flag would have to reach every future script and hook
  and fails silently when forgotten — rejected), so the config it reads must contain the
  real hostname — but the repo never needs to. The tracked artifact is a **yadm template**,
  `config.toml##template`; yadm renders the real `config.toml` (machine-local,
  untracked) at checkout:

  ```toml
  hostname_groups_enabled = true

  [arch]
  package_manager = "yay"   # REQUIRED: preserves the Story 2.6 quarantine stack

  [hostname_groups]
  # key rendered from {{ yadm.hostname }}; the group list is selected by the
  # machine's CLASS — set once per machine: `yadm config local.class <class>`
  "{{ yadm.hostname }}" = [ ...class-conditional purpose groups..., "inbox-<class>" ]
  ```

  **`yadm.class` is the machine profile selector**: a public-safe label, unique per
  machine by convention (e.g. `workstation`, `laptop`). It picks the group list in the
  template *and* names the machine's inbox. If two machines ever want the same profile,
  give them distinct classes (yadm ≥3.2 allows multiple classes if a shared profile
  class is ever worth it). This resolves the Story 2.2 privacy heads-up: the
  work-shaped hostname exists only in the rendered, untracked file.

- **Groups** (`groups/*.toml`) = the Story 2.2 purpose groups made executable.
  **The inventory's fine-grained taxonomy is normative** (grill 2026-07-02): ~16 groups
  as proposed in [package-inventory.md](./package-inventory.md) — with two renames:
  core-system → `base`, cloud-infra → `work` (opt-in per class, decision D2) — plus
  `inbox-<class>` (see below). Fine groups compose better per class (a laptop takes
  `browsers`/`office` but not `printing`/`virt`/`gaming`) and the per-package triage
  behind them is already done. Any shorter group list elsewhere in this doc is
  illustrative. Per-package `hooks` handle service enablement next to the package that
  needs it (e.g. `after_sync` → `systemctl enable`).

- **Auto-capture of new installs (Aaron's requirement):** a small **yay `PostInstall`
  Lua hook** appends newly *explicitly* installed packages (payload has `reason` +
  `source`, and `local_version` is empty on a first install — upgrades are skipped)
  that aren't declared in any group to **`groups/inbox-<class>.toml`** — one inbox
  file per machine, each machine's group list naming only its own (grill 2026-07-02: a
  single shared `inbox.toml` would auto-*install* untriaged packages onto every other
  machine at its next `metapac sync`, and is a merge-conflict magnet once a second
  machine exists; named by *class*, not hostname, because a tracked filename is as
  public as its contents). Inbox files stay YADM-tracked so untriaged drift is visible
  in `yadm status`.
  Triage flow: packages land in the host's inbox automatically at install time; Aaron
  periodically moves them to their proper group (or drops them, and `metapac clean`
  proposes the uninstall). Backstop: `metapac unmanaged` catches anything the hook
  misses (e.g. raw `pacman -S` installs, which don't pass through yay hooks).

- **Machine-local group (grill 2026-07-02):** packages whose names must not publish
  (currently the three org-internal D10 packages from the 2.2 inventory) are declared
  in a group file at an **absolute path outside the repo** (supported by
  `hostname_groups`), referenced from the rendered config. Untracked and
  not durable across a wipe — accepted, because Story 2.11
  ([#51](https://github.com/amasover/dotfiles/issues/51)) reviews them toward
  uninstall-or-keep; survivors can move to a YADM-encrypted group if durability is
  wanted. This keeps `metapac unmanaged` able to reach empty (metapac has **no ignore
  concept** — verified) without a single org name in a tracked file.

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
4. **Profile guard (grill 2026-07-02):** if `yadm.class` is unset (or the rendered
   `config.toml` lacks this hostname), hard-fail with copy-paste instructions —
   `yadm config local.class <class>`, then `yadm alt` to re-render, re-run. Without
   the guard, an unmatched hostname makes `sync` a silent no-op and a later `clean`
   would propose removing everything. Choosing the class **is** Story 2.3's "desktop
   optional unless explicitly selected" step.
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

- **`metapac clean` is off-limits until `metapac unmanaged` comes back exactly empty.**
  While groups are incomplete, `unmanaged` lists hundreds of packages and `clean` would
  offer to uninstall every one of them — a wall-of-yes prompt, not a safety net.
- **Exactly empty `unmanaged` is the acceptance test for adoption** (grill 2026-07-02:
  sharpened from "near-empty" — a tolerated remainder becomes permanent drift-report
  noise). Every hard case has a declared home: undecided-but-wanted packages are
  *parked in the inbox*, never-publish names go in the machine-local group, and
  explicit-marked packages that are really dependencies get gated
  `pacman -D --asdeps` re-marking. Empty is script-checkable; the 2.7 harness asserts
  it. Fresh-path validation only means something after live adoption reaches empty.

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
