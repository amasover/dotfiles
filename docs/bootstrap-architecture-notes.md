# Bootstrap architecture notes (input for Story 2.3)

**Status:** notes only — not a decision yet. Captured during Story 2.1.
**Decides:** what `setup/install` (and the fresh-machine bootstrap) should become.
**Related:** [Epic 2 Story 2.3](./epic-2-bootstrap-and-package-modernization.md) and
[Story 2.5 — future bootstrap architecture](./epic-2-bootstrap-and-package-modernization.md).

## What Aaron wants

- A way to **idempotently bootstrap a fresh Arch install** from this repo — not just
  daily-use config, but "new machine → useful workstation."
- **Not** going full NixOS. Wants scripts, not a declarative OS rebuild.
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
3. **Go CLI (VESTIGIAL)** — `patrick-motard/dot` (`~/code/go/bin/dot`, 2019 binary), now
   invoked by exactly one thing (the polybar audio switcher), whose switching half is
   broken under PipeWire anyway.

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

## Decision

To be recorded as `docs/decision-bootstrap-architecture.md` when Story 2.3/2.5 lands.
