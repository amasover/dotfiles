# Epic 5: Guest as Daily Driver

**Priority:** High
**Status:** Draft
**Phase:** Rebuild era (PRD §4) — the daily-driver VM direction from
[decision-daily-driver-vm.md](./decision-daily-driver-vm.md)
**PRD Reference:** [prd.md](./prd.md)
**Outcome Type:** A guest you can actually work in
**GitHub Project:** [Kanban board](https://github.com/users/amasover/projects/1/views/1)

---

## Objective

Make a freshly-provisioned guest a comfortable place to *do work* — authenticated,
readable, and responsive — not just a machine that converges. Epic 2 proves the
bootstrap is correct; this epic makes the result livable.

## Why This Matters

The 2026-07-10 direction decision ends the cleanup era at a daily-driver VM.
That only works if sitting inside a guest is pleasant: today a fresh guest
cannot push to GitHub (no credentials, and the configured credential manager
can't even open its store headless), polybar silently fails because the launch
script only recognizes hardcoded host monitor layouts, and the display doesn't
follow the viewer window. Every one of those was hit live on 2026-08-22, working
inside the Windows-machine VMware guest.

## Boundary with Epic 2

One rule keeps filing honest:

- If a story changes **what bootstrap installs or how convergence is proven**,
  it belongs in [Epic 2](./epic-2-bootstrap-and-package-modernization.md).
- If a story changes **what the guest is like to use once it's up**, it belongs
  here.

Existing epic-2 stories (2.37 daily target, 2.41 shared guest glue, …) keep
their numbers and homes; nothing is renumbered.

---

## Scope

### In Scope

- Identity and auth inside guests: SSH keys, GitHub/git credentials, and how a
  host-driven `up` can bootstrap them.
- Desktop usability inside guests: display resolution, polybar, and the
  fallbacks that make host-tuned config degrade gracefully on virtual hardware.
- Fixes to the *current* guest where they unblock ongoing work, promoted into
  declared config so the next fresh guest gets them for free.

### Out of Scope

- Bootstrap/package convergence mechanics (Epic 2).
- Host desktop cleanup — the host monitor-name migration stays with
  [3.17](./epic-3-shell-editor-desktop-cleanup.md).
- Graduating the guest to the actual daily driver (2.37 owns that call).

---

## Stories

### Story 5.1: Fresh machines generate their own SSH key

As the repo owner,
I want every fresh machine to generate its own SSH keypair during bootstrap,
So that machines have distinct, revocable identities instead of restoring a shared key from the encrypted archive.

**Current state (2026-08-22, VMware guest):** `~/.ssh` holds only
`authorized_keys` (the host's way in). `.ssh/**` is a YADM-encrypted path, so a
key exists only if the encrypted payload ships one — fresh guests get nothing.

**Acceptance criteria:**

- Bootstrap generates an ed25519 keypair when none exists; never overwrites an
  existing key (idempotent, safe on the live workstation).
- The key comment identifies the machine and creation date.
- The public key is surfaced at the end of the run (and captured by the harness
  log) so it can be registered with GitHub or other hosts.
- No private key material is ever printed, tracked, or written outside `~/.ssh`.
- Works unattended and headless.

**Open question:** once machines mint their own keys, should the encrypted
`.ssh/**` payload stop carrying private keys at all (config + known_hosts only)?
That's a manifest change — coordinate with the secret-safety rules before
touching it.

### Story 5.2: Host-driven runs bootstrap GitHub auth (and maybe more)

As the repo owner,
I want a harness-driven `up` to leave the guest authenticated to GitHub when the host is,
So that a fresh guest can push branches and open PRs without a manual login ritual.

**Current state:** the tracked `.gitconfig` already routes `github.com` through
`gh auth git-credential`, so guest auth reduces to "gh has a token." The guest
has none; the host does.

**Acceptance criteria:**

- After a host-driven `up`, `gh auth status` succeeds in the guest and a push to
  the dotfiles repo works over HTTPS.
- The credential is minimally scoped and disposable — dying with
  `vm-harness destroy` is acceptable, a long-lived broad token is not.
- Nothing credential-shaped lands in tracked files, harness logs, or transcripts.
- Unattended runs on a host *without* auth skip the step cleanly and say so.
- Mechanism options (host mints a scoped token and injects it; host registers
  the guest's 5.1 pubkey via its own gh; attended device-flow step) are weighed
  in the story, with the choice recorded.
- "Other auth bootstraps" (AWS, etc.) are explicitly deferred to follow-on
  stories once the GitHub shape works.

### Story 5.3: Fix git credentials inside the current guest

As the repo owner,
I want git pushes to work from the guest I'm sitting in today,
So that guest-side work (including this epic) doesn't detour through the host for every commit.

**Current state (2026-08-22):** `gh` is not logged in. The global
`credential.helper = git-credential-manager` with `credentialStore =
secretservice` fails headless ("Failed to open secret service session" — no
keyring daemon in the guest session). No `~/.git-credentials`, no SSH private
key. The github.com→gh routing in `.gitconfig` is fine and untouched. Also hit
live: commit *identity* is missing too — the tracked `.gitconfig` deliberately
defers `user.email` to an untracked `~/.gitconfig-local` (loud failure by
design), and fresh guests never get that file. Worked around with repo-local
`git config user.*` in the dotfiles clone; the durable fix (guest bootstrap
writes `~/.gitconfig-local`) belongs with 5.2's identity/auth bootstrap.

**Acceptance criteria:**

- From inside the current guest, `git push` to the dotfiles repo succeeds
  (attended login — `gh auth login --web` device flow — is fine; this is the
  manual unblock that 5.2 later automates).
- The GCM/secretservice failure gets a decision, not a workaround-in-place:
  either guests get a headless-safe credential store, or the GCM helper is
  scoped to machine classes that have a keyring (ties into the 2.30 class
  split). Recorded in the story.
- The login recipe lands in `knowledge/` so the next guest session doesn't
  re-derive it.
- No plaintext credential store (`store` helper / `~/.git-credentials`) is
  introduced.

### Story 5.4: Guest resolution follows the viewer window

As the repo owner,
I want the guest's X resolution to track the VMware/SPICE window size,
So that resizing the viewer doesn't leave me on a fixed 1280x800 letterboxed desktop.

**Current state (2026-08-22, VMware guest):** open-vm-tools is installed but
`vmtoolsd` is not running — the service was never enabled, and nothing in
`.xinitrc` or the i3 config starts the user-session agent. Display is stuck at
`Virtual-1` 1280x800.

**Acceptance criteria:**

- Resizing the VMware Workstation window resizes the guest display live, in the
  i3 session, without manual `xrandr` calls; survives an i3 restart.
- The enabling pieces (service enablement, session agent autostart) live in
  declared config so fresh guests get it — scoped to guest classes, not the
  metal host (coordinate with the 2.30 class/hardware split rather than
  duplicating it).
- The libvirt harness guest gets the equivalent treatment (spice-vdagent — not
  currently installed there; verify) or an explicit deferral note.

### Story 5.5: Polybar comes up on fresh guests

As the repo owner,
I want polybar to appear on any guest without per-machine edits,
So that a fresh guest has a working desktop instead of a "monitor configuration not recognized" notification.

**Current state (2026-08-22):** `.config/polybar/launch.sh` matches the active
monitor list against seven hardcoded host layouts (`eDP1 `, `*DP1-1 eDP1 DP1-3 `,
…). The guest's `Virtual-1` matches nothing, so the script falls through to a
notify-send error, sets no `MONITOR_*` variables, and all six bar launches fail.
The host side of this table is *also* stale — 3.16's driver switch renamed the
outputs (tracked as [3.17](./epic-3-shell-editor-desktop-cleanup.md)).

**Acceptance criteria:**

- On a fresh single-monitor guest, the main bar appears on the primary monitor
  with zero configuration.
- Unknown layouts degrade to "main bar on primary monitor" instead of nothing —
  the hardcoded-case-or-bust shape is gone.
- Named multi-monitor layouts (the host's docking setups) still work; the
  monitor-*name* fixes stay 3.17's — this story owns the launch logic and the
  fallback, and coordinates with 3.17 rather than both rewriting the same file.
- The layout-detection logic is exposed as a testable seam (invokable
  subcommand or function file) with clitest coverage for the guest, unknown,
  and named-layout paths — no X server required in tests.
- Launch script rewrite is on the table if patching the case statement fights
  the acceptance criteria; keep the rotated-log behavior either way.

---

## Risks

### Risk: Credentials accumulate in disposable guests

Tokens and keys minted per-guest are a feature (self-cleaning) only if they are
scoped and short-lived. Mitigation: 5.2's acceptance criteria; secret scan +
privacy pass on every PR as usual.

### Risk: This epic silently absorbs host desktop cleanup

Polybar/resolution work brushes against epic 3's territory. Mitigation: the
boundary rule above, and explicit coordination notes in 5.4/5.5 pointing at
3.17 and 2.30 instead of duplicating them.
