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

Issue: [#148](https://github.com/amasover/dotfiles/issues/148)

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

Issue: [#149](https://github.com/amasover/dotfiles/issues/149)

This story owns the **attended** path and the identity half
(`~/.gitconfig-local`); the fully unattended path is Story 5.6.

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
- The attended mechanism — a bootstrap step drives the `gh auth login --web`
  device flow and surfaces the one-time code in the run output (verified live
  2026-08-22: the Enter prompt wants a raw-mode `\r` when driven through a pty;
  a real terminal needs no tricks) — is implemented here. Unattended mechanisms
  (host-minted token injection, host-side pubkey registration) belong to 5.6.
- "Other auth bootstraps" (AWS, etc.) are explicitly deferred to follow-on
  stories once the GitHub shape works.

### Story 5.3: Fix git credentials inside the current guest ✅

As the repo owner,
I want git pushes to work from the guest I'm sitting in today,
So that guest-side work (including this epic) doesn't detour through the host for every commit.

Issue: [#150](https://github.com/amasover/dotfiles/issues/150) (closed, PR [#155](https://github.com/amasover/dotfiles/pull/155))

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

### Story 5.4: Guest resolution follows the viewer window ✅

As the repo owner,
I want the guest's X resolution to track the VMware/SPICE window size,
So that resizing the viewer doesn't leave me on a fixed 1280x800 letterboxed desktop.

Issue: [#151](https://github.com/amasover/dotfiles/issues/151) (closed, PR [#156](https://github.com/amasover/dotfiles/pull/156))

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

### Story 5.5: Polybar comes up on fresh guests ✅

As the repo owner,
I want polybar to appear on any guest without per-machine edits,
So that a fresh guest has a working desktop instead of a "monitor configuration not recognized" notification.

Issue: [#152](https://github.com/amasover/dotfiles/issues/152) (closed, PR #161)

**Current state (2026-08-22):** `.config/polybar/launch.sh` matches the active
monitor list against seven hardcoded host layouts (`eDP1 `, `*DP1-1 eDP1 DP1-3 `,
…). The guest's `Virtual-1` matches nothing, so the script falls through to a
notify-send error, sets no `MONITOR_*` variables, and all six bar launches fail.
The host side of this table is *also* stale — 3.16's driver switch renamed the
outputs (tracked as [3.17](./epic-3-shell-editor-desktop-cleanup.md)).

**Acceptance criteria:**

**Scope expanded 2026-08-22 (Aaron):** the default is positional roles, not a
layout table — MAIN to the primary monitor, then extras to LEFT (positioned
left of MAIN) or EXTRA. autorandr is the integration point for layout changes.

- On a fresh single-monitor guest, the main bars appear on the only monitor
  with zero configuration.
- Role assignment is a positional heuristic (`tools/monitor-roles`): primary →
  `MONITOR_MAIN`, leftmost monitor left of MAIN → `MONITOR_LEFT`, next →
  `MONITOR_EXTRA`. Final-role resolution merges any profile override before it
  warns about unassigned monitors, so claimed virtual splits do not produce
  false warnings. The stdin seam has clitest coverage; tests need no X server.
- Bars launch only when their role is assigned and the theme config defines
  them — the six-blind-launches shape is gone, and polybar gets the theme
  config via `-c` (nothing ever passed it before; fresh machines fell back to
  polybar's built-in example bar).
- Setups the heuristic cannot infer (the virtual-split docking layouts) come
  from per-autorandr-profile overrides, `~/.config/polybar/layouts/<profile>.env`
  (template: `layouts/example.env.sample`), selected by
  `$AUTORANDR_CURRENT_PROFILE` and resolved with the heuristic in one
  clitest-covered `monitor-roles` pass. A role the file sets wins, one it omits
  keeps the heuristic's pick, and an empty value clears it. The tracked global
  `autorandr/postswitch` relaunches after profile-specific `postswitch.d` hooks
  create logical monitors. Writing and verifying real profiles and overrides is
  Story 3.17's attended docking work; the old case table survives as historical
  reference in `launch.sh`.
- Failure is loud (hardened after the 2026-08-22 adversarial review of PR
  #161): role-resolution warnings land in the polybar log and as desktop
  notifications, and a run that can't resolve `MONITOR_MAIN` exits without
  killing the bars already up.
- Concurrent launches (i3's `exec_always` vs the autorandr hook, both firing
  at login) serialize on a lock, and the `~/.screenlayout` `exec_always` that
  applied layouts behind autorandr's back is retired from i3 config.
- Rotated-log behavior is preserved. Theme contract: `polybar_theme` env is a
  one-shot override, else the selection persisted by the repaired theme
  selector (state file), else the nord-arrow default — so a chosen theme
  survives hook relaunches. The bar's top gap moved to i3 config, its single
  home.

### Story 5.6: Unattended host-driven runs authenticate the guest

As the repo owner,
I want a fully unattended `vm-harness up` on an authenticated host to leave the guest able to push,
So that automated runs can create branches and PRs without a human at a browser.

Issue: [#153](https://github.com/amasover/dotfiles/issues/153)

**Current state:** the attended device flow (5.2/5.3) needs a browser, and
harness runs are unattended by design (the whole 2.38 discipline). The host's
`gh` is authenticated; the guest's is not.

**Acceptance criteria:**

- A fully unattended `up` on an authenticated host produces a guest that can
  push to the dotfiles repo, with zero interactive steps.
- The mechanism decision is recorded, choosing between: the host registers the
  guest's own 5.1 pubkey with GitHub via the **host's** `gh api /user/keys`
  (current preference — no token ever enters the guest, revocation is
  per-machine), or the host injects a minimally-scoped, short-lived token for
  HTTPS.
- `vm-harness destroy` cleans up what auth created where practical (e.g.
  deregisters the guest's key), or the leftover is documented as inert.
- On a host without GitHub auth, the step skips cleanly, says so in the run
  report, and the run stays green.
- Nothing credential-shaped lands in harness logs, transcripts, or tracked
  files; the bootstrap stays on `gh`'s sanctioned commands (scripting GitHub's
  raw OAuth endpoints directly is credential-harvester-shaped — see #149).
- Depends on 5.1 for the key-based shape; coordinates with 5.2 instead of
  duplicating its identity work.

### Story 5.7: Accelerate Firefox in VMware guests

As the repo owner,
I want VMware guests to expose SVGA3D and make Firefox use it,
So that the daily-driver browser does not composite and scroll through llvmpipe.

Issue: [#189](https://github.com/amasover/dotfiles/issues/189)

**Current state (2026-08-23, VMware guest):** the generated VMX omitted
`mks.enable3d`, so the first boot exposed legacy SVGA and Xorg fell back to
llvmpipe. Enabling VMware 3D moved Xorg GLAMOR to SVGA3D/OpenGL 4.3, but Mesa's
SVGA driver deliberately reports its Gallium `accelerated` capability as false;
Firefox 154 therefore blocklists hardware compositing. A disposable-profile
experiment proved hardware WebRender and WebGL 1/2 work on SVGA3D when forced
through GLX. Firefox's default EGL path failed to create a WebRender context and
fell back safely to Software WebRender.

**Acceptance criteria:**

- VMware VMX generation enables 3D acceleration; a fresh guest reports the
  `3D` vmwgfx capability, shader model `SM_5_1X`, and Xorg GLAMOR on SVGA3D
  instead of llvmpipe.
- VMware bootstrap installs a tracked Firefox policy that enables WebRender,
  forces hardware acceleration, and selects GLX over EGL. It applies to every
  current and future profile, including first launch.
- Non-VMware machines do not install the policy. Reconciliation removes only
  this repo's managed symlink and refuses to overwrite unrelated Firefox policy
  files.
- In the live VMware guest, Firefox `about:support` reports `Compositing:
  WebRender` without the Software suffix and WebGL 1/2 on VMware SVGA3D. The
  scrolling benchmark stays at 60 Hz with no frames over 25 ms.
- Host-independent tests cover the VMX setting and policy
  install/idempotence/check/removal/refusal behavior.

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
