# Bootstrap architecture notes (input for Story 2.3)

**Status:** notes only — not a decision yet. Captured during Story 2.1.
**Decides:** what `setup/install` (and the fresh-machine bootstrap) should become.
**Related:** [Epic 2 Story 2.3](./epic-2-bootstrap-and-package-modernization.md) and
[Story 2.5 — future bootstrap architecture](./epic-2-bootstrap-and-package-modernization.md).

## What Aaron wants

- A way to **idempotently bootstrap a fresh Arch install** from this repo — not just
  daily-use config, but "new machine → useful workstation."
- **Not** going full NixOS just yet. Maybe in the future. For now wants scripts, not a declarative OS rebuild.
- Open question on language/tool: **plain Bash vs Ansible vs Go vs something else.**
- Context: the original author of this repo (the fork's source) eventually moved to
  **Ansible** on his fork. Aaron never adopted that and is undecided.

## The question to answer in 2.3 (or 2.5)

> Put on the 10x-architect hat: what's the best tool for idempotently setting up an
> Arch workstation from this repo, given we explicitly *don't* want NixOS? Is a Bash
> bootstrap good enough, or is Ansible / Go / another tool worth the dependency?

## Reality check: three bootstrap lineages exist on disk (one is the real one)

Discovered during Story 2.1 — there's prior art from several approaches, and it's worth
being clear which is actually live:

1. **Bash (ACTIVE)** — `setup/install` (2019, unsafe/broken, do-not-run) + `setup/update`
   (edited 2026-06-23, actively maintained). This is Aaron's real daily driver.
2. **Ansible (DORMANT)** — `~/code/dot-ansible` (`patrick-motard/dot-ansible`, 2019,
   never forked). A stray `update` alias briefly pointed here, but that was accidental
   (git/yadm branch shuffling) and has been reverted to the bash script. Real prior art
   to evaluate, not a currently-active path.
3. **Go CLI (IN USE, narrowly)** — `patrick-motard/dot` (`~/code/go/bin/dot`, 2019 binary).
   Confirmed live: the polybar audio switcher calls `dot sound port` (Aaron verified it
   works). Only that one consumer, but it's a real dependency today.

**The job of 2.3/2.5 is to pick one model deliberately** rather than let dormant lineages
re-creep. The friend's Ansible repo is the strongest existing reference point for "what
if not bash."

## Starting analysis (to refine in 2.3)

Rough trade-offs, not a recommendation yet:

- **Bash** — zero extra deps, runs on a fresh Arch box immediately, matches what's
  already here. Weak at idempotency and state; you hand-roll "already done?" checks
  (the current `install` shows how that rots). Fine for a thin, well-structured
  bootstrap that mostly delegates to `pacman`/`yay` + `yadm`.
- **Ansible** — real idempotency, the `community.general.pacman`/`aur` modules, clear
  task structure, what the upstream fork chose. Costs a Python+Ansible bootstrap step
  before it can run, and is heavier than this repo's current footprint.
- **Go** — there's prior art (`dot` CLI lives here), single static binary, but it must
  be built/fetched first (chicken-and-egg on a bare machine) and is the most effort to
  write/maintain for what is mostly shelling out to package managers.

Key framing for 2.3: **what should YADM own vs. what should a bootstrap tool own?**
YADM already owns dotfile placement + secrets. The bootstrap layer mainly needs to:
install packages (native + AUR), set up the AUR helper, enable a few services, and
restore secrets via YADM. That's a fairly small surface — which argues against anything
heavy unless idempotency/maintainability clearly wins.

## Claude's recommendation (for Aaron to accept/reject in 2.3)

**Default: bash now → Ansible if it grows. YADM stays. Do not build a Go CLI as the
management engine.**

- **YADM** keeps owning dotfile placement + secrets. Unchanged.
- **Bootstrap (2.3):** a thin, idempotent **bash** script whose only jobs are: install
  `yay`, `pacman -S --needed` from the curated manifest (Story 2.2), enable a few
  services (guarded by `systemctl is-enabled`), and `yadm clone`. Bash is genuinely
  adequate for "install these, enable these, clone that" — the surface is small.
- **Graduate to Ansible** (Story 2.5) only when the bootstrap grows real conditionals
  (laptop vs desktop, optional desktop stack, ordering). The friend's `dot-ansible` +
  its `Vagrantfile` are a ready starting point and a VM to test in. Ansible's
  `pacman`/AUR modules give idempotency for free.
- **Don't use a bespoke CLI as the idempotency/bootstrap engine** (whatever language).
  The real objection is *not* "you can't read a binary" — you'd be editing readable Go
  source, that's fine. It's three other things: (1) **chicken-and-egg** — a Go tool needs
  the Go toolchain + a compile step *before* it can provision a bare machine, so you still
  need a bootstrap-before-the-bootstrap; (2) you **re-implement** change-detection /
  ordering / "already applied?" that config tools give for free; (3) **maintenance** —
  bespoke management code rots (see `install`), and the ecosystem can't help you debug a
  private tool.
- **A personal CLI for *imperative* commands is totally legitimate** — that's a different
  job from the idempotent engine. Aaron's point stands: long bash rots, and his `update`
  works precisely because it's *linear glue* (run updater A, then B, then C). Heuristic:
  **bash for linear orchestration that mostly shells out; a real language (Go/Python) once
  there's real logic** — argument parsing, data structures, branching, state. So the audio
  switch is fine as ~15 lines of `wpctl` bash, but if Aaron *wants* a richer personal
  `dot`-style CLI, Go or Python is the right call there — just keep it for QoL ergonomics,
  not for "make my system match this declared state."

## Answering "revive dot-ansible, or something else?"

Options beyond bash, roughly lightest → heaviest:

- **Curated bash + package manifest (start here).** Story 2.2 produces the manifest;
  2.3 is a thin bash bootstrap. Zero new deps, fastest fresh-machine capability.
- **`aconfmgr`** (Arch-native; on the Arch Wiki config-management list). Declaratively
  *tracks and restores* installed packages + `/etc` config for an Arch system. Closest
  thing to "NixOS-like declarativeness without NixOS," and purpose-built for Arch. Strong
  candidate worth a real look for the package/system-state half (YADM still owns `$HOME`).
- **Ansible.** General, idempotent, great LLM support, `pacman`/AUR modules. The friend's
  `dot-ansible` + `Vagrantfile` exist as reference.
  - *Revive dot-ansible wholesale? No.* It's the friend's 2019 playbook tuned to *his*
    machine ("changes to get this to work with my setup"), never forked. Reviving it means
    inheriting his assumptions. Better: start a fresh repo you own and cherry-pick patterns
    (and the Vagrant test harness) from it.
- **`ansible-pull`** — run the playbook *from* the target pulling its own repo; nice for
  "one command on a fresh box." Same Ansible, different invocation.
- **Heavier (Salt/Chef/Puppet):** overkill for one workstation. Skip.
- **Nix / home-manager:** Aaron is *not* fully ruling this out anymore. Two distinct levels:
  - **home-manager on Arch (no NixOS):** install the Nix package manager + home-manager on
    top of the existing Arch system to declaratively manage `$HOME`/user packages, while Arch
    + pacman still own the base OS. This is the realistic middle path — declarative dotfiles
    without abandoning Arch as daily driver. It would *overlap/compete with YADM*, so adopting
    it is really a "what owns `$HOME`" decision, not just a bootstrap tool choice.
  - **Full NixOS:** the whole-OS declarative rebuild. Biggest payoff for reproducibility,
    biggest model shift; deferred while Arch is the daily driver, but explicitly left on the
    table as a possible future direction (Aaron: "maybe I'll even fully switch to Nix").
  - Note: Nix/home-manager and aconfmgr/Ansible are *different philosophies* — Nix is
    pure/declarative/reproducible-by-construction; the others are imperative-converging-on-a-
    target. Worth a deliberate pick rather than drifting.

**Suggested shortlist for the 2.3/2.5 decision:** (a) curated bash now, then (b) choose
between **aconfmgr** (Arch-native declarative system state) and **a fresh Ansible repo**
(general, portable, friend's repo as reference) for the durable model. Validate either in
a throwaway VM (Vagrant/`archinstall`) before trusting it on metal.

## Decision

To be recorded as `docs/decision-bootstrap-architecture.md` when Story 2.3/2.5 lands.
