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
- Host desktop cleanup — Story 3.17's host monitor-name migration closed when
  its laptop retired; [3.17](./epic-3-shell-editor-desktop-cleanup.md) keeps the record.
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

### Story 5.8: The Mac work VM is the daily driver

As the repo owner,
I want an aarch64 Arch guest under VMware Fusion on the work Mac, provisioned and
bootstrapped by the repo's harness,
So that the employer machine runs my real environment across every display.

Issue: [#281](https://github.com/amasover/dotfiles/issues/281) · Origin: [decision-work-vm.md](./decision-work-vm.md) (2026-11-02,
work-laptop replacement).

**Current state (2026-11-02):** a disposable `vmware-aarch64` guest installs
unattended from archiso-aarch64, boots, and converges as class `work-vm` under
Fusion, driven by the harness on macOS: `bootstrap done rc=0`, `check done rc=0`
(unmanaged none, declared-but-missing none). The LUKS `work-vm` install is next.
The Arch Linux Ports (drzee) repos lack `xf86-video-vmware`, so Xorg runs
modesetting on vmwgfx.

**Firefox on aarch64 (2026-11-02):** Fusion 26H1 gives the guest the same
SVGA3D/OpenGL 4.3 that Story 5.7 found under Workstation, and Xorg GLAMOR runs
on it. Story 5.7's VMware policy (hardware WebRender forced through GLX) draws
black rectangles over page content in Firefox 159, for example Gmail's landing
hero. Turning off DMA-BUF and hardware video, partial present
(`gfx.webrender.max-partial-present-rects=0`), or accelerated canvas did not
help. Allowing EGL avoids the glitch only because Firefox then fails to create
the hardware WebRender context and falls back to software, as in Story 5.7. So
the VMware fragment is now per architecture: x86_64 keeps Story 5.7's policy
byte for byte, and aarch64 drops `gfx.webrender.all` for a locked
`gfx.webrender.software`, still selecting GLX and forcing layer acceleration.
The tradeoff is CPU compositing on aarch64; WebGL 2 keeps hardware, and
`about:support` reports its renderer as `VMware, Inc. -- SVGA3D`.

**Known limitation:** aarch64 guests composite Firefox in software. When Mesa's
svga driver or Fusion updates, retry hardware WebRender by swapping
`gfx.webrender.software` for `gfx.webrender.all` in `policies-vmware-aarch64.json`.

**Multi-display (2026-11-02):** on the disposable guest, Fusion's "Use All
Displays in Full Screen" sent `DisplayTopology_Set 2 , 1512 0 3840 2160 , 0
1495 1512 949`. `vm-autofit` placed the outputs and `monitor-split auto`
carved `Virtual-1~1` (1920x2160+1512+0), `~2` (1920x1080+3432+0) and `~3`
(1920x1080+3432+1080) beside the panel `Virtual-2`. i3 put workspace 1 on
`~1`, 3 on `~2` and 2 on `~3`. Polybar launched main, main-bottom, left,
split-one and split-two (`auto: Virtual-1~1 left=Virtual-2 top=Virtual-1~2
bottom=Virtual-1~3`). Leaving full screen cleared the split, and entering it
again rebuilt it with no manual step.

**Sound, camera, clipboard and drag-and-drop (2026-11-03):** the generated vmx
had `sound.present = "FALSE"`, so the guest had no sound card. With sound on,
Fusion picks es1371, and the arm vmx refuses it at power-on ("es1371 is not
valid device type for sound"); `sound.virtualDev = "hdaudio"` powers on and
binds the Mac's default output and input. The Mac's camera reaches the guest as
Fusion's virtual UVC camera (`usb_xhci:5.deviceType = "video"`, the GUI's
"Add Device > Camera"), backed by the host's default AVCapture camera. Both
were proven on a scratch Fusion VM; `vm-harness-vmx` now writes them for
aarch64. Fusion 13.6 removed Bluetooth sharing, so Bluetooth headsets stay on
the Mac and reach the guest as its sound input/output; USB devices (security
keys, USB headsets) pass through on the XHCI controller. Clipboard already
worked: vmusr starts from `.xinitrc` at login (the VMX logged `toolbox-dnd`
two seconds after `startx`). File drag-and-drop from the Mac did not, because
`vmware-vmblock-fuse.service` ships disabled and vmusr then starts without
`--blockFd`; bootstrap step "VMware guest tools" and the seed now enable it.

**Live on the work VM (2026-11-03):** after a power cycle with the new vmx
keys, the speaker and microphone (the `hdaudio` card) and the virtual camera
work in the guest, and the clipboard works both ways. Drag-and-drop works only
from the Mac into the guest: a file dropped from Finder arrived and opened. A
drag out of the guest never leaves the VM window. Every drag also leaves a
32x32 override-redirect window owned by vmware-user (`vmtoolsd -n vmusr`)
mapped at +0+0, over polybar's top-left, which i3 cannot manage; six had piled
up. **Decision:** drag-and-drop is off for aarch64 Fusion VMs
(`isolation.tools.dnd.disable = "TRUE"` in the vmx; the copy and paste keys
stay unset, so the clipboard stays on). x86_64 output is unchanged; Workstation
was not tested.

**Shared folders are the file route (2026-11-03):** Fusion shares the Mac's
`~/vmshare` and `~/Downloads` with the guest (HGFS; VMware has no 9p). The
attended `work-vm` create sets them with `VM_HARNESS_SHARES`, and `vmrun
enableSharedFolders`/`addSharedFolder` add them to an existing VM. In the
guest, the user unit `mac-shares.service` mounts every share under `~/mac` with
`vmhgfs-fuse` (bootstrap enables it on VMware guests only), so files move both
ways through `~/mac/vmshare` and `~/mac/Downloads`. Proven live: the unit
mounted both, a file written in the guest appeared on the Mac, and stop and
start unmounted and remounted `~/mac`.

**Attended creation path (2026-11-03):** `VM_HARNESS_TARGET=work-vm` makes the macOS
harness build the real VM: seed target `work-vm` (LUKS root, no harness sudo or serial
getty), VM `work-vm` in `~/vms/work-vm`, 300 GiB, 10 vcpus, 12 GiB, the two shares, and
the window always open for the disk password. The user and disk passwords are typed
twice at `create` and reach `provision-seed` only through its environment; the seed is
deleted when the install ends. Bootstrap runs from GitHub `main` over `ssh -t`: the
user types the sudo password (a temporary password-free drop-in the guest glue
deletes on exit or signal) and the archive passphrase for `yadm decrypt` at the
start, then the usual `bootstrap --unattended` runs for hours with nobody needed and
ends by listing the follow-ups it skipped; `check` fails while the drop-in exists.
`destroy` needs the VM name typed. Steps: [Create the real work
VM](./runbook-vm-validation.md#create-the-real-work-vm-attended-macos). Proven
against stubs and with a scratch `seed` + `create`; the real VM's creation record is
still pending.

**Disk password prompt on the serial port (2026-11-03):** the first boot of the
real `work-vm` showed a black VMware window; "Enter passphrase for
/dev/nvme0n1p2:" appeared only in the serial log. Fusion's arm64 firmware has an
ACPI SPCR table, and Linux on arm64 makes that serial port /dev/console unless
the command line names a `console=`. The `work-vm` entry had none, so the
`encrypt` hook asked on the serial port. A `console=` on the command line is
parsed after SPCR and wins. Adding `console=tty0` at the systemd-boot editor
put the prompt in the window, and the disk unlocked. Fix: `provision-seed` now
adds `console=tty0` to the boot entry of every encrypted target (`daily-vm`,
`work-vm`). On x86_64 tty0 is already the console, so nothing changes there.
Harness targets keep `console=tty0 console=ttyS0`, serial last on purpose. A VM
installed before the fix: [Create the real work
VM](./runbook-vm-validation.md#create-the-real-work-vm-attended-macos).

**Passphrase length in the bootstrap recording (2026-11-03):** the host's
bootstrap session log of the real `work-vm` held `Passphrase: ` followed by one
`*` per typed character, so it gave away the archive passphrase's length.
`yadm decrypt` asked gpg-agent's default pinentry, which on the guest (no
DISPLAY) is pinentry-curses, and it draws a `*` per character. The earlier test
used pinentry-tty, which prints nothing, so it missed this. Fix: the guest
glue's attended decrypt runs gpg with `--pinentry-mode loopback`, through a
temporary wrapper put first on yadm's PATH for that decrypt only. gpg then asks
on the terminal with echo off and prints nothing per character. No gpg or
gpg-agent config is written, and the wrapper is deleted on exit or signal. A
set `yadm.gpg-program` or `no-allow-loopback-pinentry` stops the run before
asking, with no fallback to an echoing pinentry. A test drives a pinentry stub
that draws `*` per character and checks that a wrong and then a right
passphrase leave no `*` and no passphrase in the recording. The log from that
run was redacted by hand.

**Acceptance criteria:**

- `vm-harness-vmware.ps1` runs under PowerShell 7 on macOS (`$IsMacOS`) against
  Fusion's `vmrun`/`vmcli`, defaulting to class `work-vm` and seed target
  `vmware-aarch64`. Its Python tools gain host-independent tests for the macOS
  paths. A disposable run ends `=== bootstrap done rc=0` + `=== check done rc=0`.
- `provision-seed --target work-vm` produces the LUKS-root aarch64 recipe; the
  real VM is installed from it and decrypts the full archive.
- Class `work-vm` renders `guest-vmware`, `work`, `inbox-work-vm`, and
  `arch-aarch64`; metapac unmanaged and missing are both empty on the guest.
  Shared purpose groups stay architecture-neutral; x86-only packages live in
  `arch-x86_64`, and bootstrap still fails loudly on a genuinely missing package.
- Multi-display: in Fusion's "Use All Displays in Full Screen" mode, the guest
  gets one output per Mac display (panel + external 4K, later a second 4K).
  The 3840x2160 4K output is carved into the old home split by
  `tools/monitor-split` (left 1920x2160 main, right-top and right-bottom
  1920x1080; workspaces 1 → main, 2 → bottom, 3 and 5 → top). It is opted in
  for class `work-vm` by `.config/monitor-split/policy##class.work-vm` and
  rebuilt by `vm-autofit` on every full-screen toggle and dock/undock.
  Polybar gives the main bar to the left half, split bars to top/bottom, and
  LEFT to the panel. Roles and i3 workspaces follow without an autorandr
  profile ([4k-split-monitor-layout.md](../knowledge/reference/4k-split-monitor-layout.md)).
- HiDPI: a recorded choice between Fusion's full-resolution Retina mode with a
  guest `Xft.dpi` and scaled (non-Retina) mode. Text is sharp and consistently
  sized on both the Retina panel and the 4K.
- Slack huddles: speaker and microphone through the `hdaudio` card, and the Mac
  camera as `/dev/video0` in the guest, shown by a test call from the guest.
  Clipboard works both ways. Files move both ways through the shared folders
  under `~/mac`; drag-and-drop is off by decision.

**Evidence artifact:** the disposable harness log set, the `work-vm` metapac
render and check output, and `xrandr --listactivemonitors` plus a screenshot
across all displays in full screen.

---

## Risks

### Risk: Credentials accumulate in disposable guests

Tokens and keys minted per-guest are a feature (self-cleaning) only if they are
scoped and short-lived. Mitigation: 5.2's acceptance criteria; secret scan +
privacy pass on every PR as usual.

### Risk: This epic silently absorbs host desktop cleanup

Polybar/resolution work brushes against epic 3's territory. Mitigation: the
boundary rule above, and explicit coordination notes in 5.4/5.5 pointing at
3.17 and 2.30 instead of duplicating them. Since 3.17 closed, guest display
layout (5.8) belongs to this epic.
