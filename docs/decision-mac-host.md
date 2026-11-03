# Decision: the work Mac reconciles through `mise bootstrap` and yadm, as class `work-mac`

**Date:** 2026-11-02
**Status:** Accepted
**Origin:** Mac host adoption, 2026-11-02
**Related:** [CONTEXT.md](../CONTEXT.md) (reconcile loop, drift report, machine class) ·
[runbook-mac-host-adoption.md](./runbook-mac-host-adoption.md) ·
[decision-daily-driver-vm.md](./decision-daily-driver-vm.md) (the full-archive precedent) ·
Story 2.61 (epic 2) · Story 4.13 (agent-skills)

## Decision

The employer-issued Mac (Apple Silicon, macOS, managed by Jamf and an EDR agent) joins
the reconcile loop from this same repository. **`mise bootstrap` reconciles the
machine; yadm places the files.** Its machine class is **`work-mac`**.

Supporting choices, decided together:

- **mise bootstrap is the Mac's reconciler.** `.config/mise/config.toml##os.Darwin`
  declares Homebrew formulae and casks, the oh-my-zsh checkout, macOS defaults, hooks
  and tools; `conf.d/*.toml` files add their own parts (`conf.d/openviking.toml` owns
  ollama, uv and the OpenViking LaunchAgents). `mise bootstrap --dry-run` previews, and
  `.local/bin/tools/brew-drift-report` is the Mac's drift report: installed formulae and
  casks no mise config declares, plus declared ones that are missing.
- **yadm places the files, with a sparse checkout.** The Mac applies
  `.config/yadm/sparse/work-mac`, an allowlist of git non-cone patterns. Only the
  shared shell, git, yadm, mise, omp and OpenViking files and a few tools that run on
  both Linux and macOS land; the Linux desktop, services, package-manager files and the
  repo's docs and tests stay skip-worktree entries. An allowlist, not a denylist, so a
  new Linux file stays off the Mac until someone lists it.
  `tests/mac-sparse.clitest.txt` checks what lands.
- **Mac-only files are `##os.Darwin` alternates.** The mise config, the yadm bootstrap
  entry point (`.config/yadm/bootstrap##os.Darwin`) and the git credential helpers
  (`.gitconfig-os##os.Darwin`, included last by `.gitconfig`). The one Linux template,
  metapac's config, gained an `os.Linux` condition so yadm never renders it from a
  source the sparse checkout leaves out.
- **One shared `.zshrc`.** Linux-only lines sit behind `$OSTYPE` checks and behave
  exactly as before on Linux; the Darwin branch adds Homebrew's prefix, the Homebrew
  builds of the zsh plugins pacman supplies on Linux, eza for exa, and mise activation.
  The tracked files own mise activation, so the config sets
  `mise_shell_activate zsh = false`: otherwise mise would write marker blocks into
  yadm-tracked files that Linux shares.
- **Plain `omp` runs `omp-mode claude`'s roles on the Mac.** The Darwin branch of
  `.zprofile` exports `PI_CONFIG_FILES=~/.omp/agent/modes/claude.yml` when nothing else
  set it. It is the overlay mechanism `omp-mode` already uses, so `omp-mode openai`
  still wins (its overlay comes last). Every login shell reads `.zprofile`, including
  non-interactive ones such as `zsh -l -c omp`, and interactive shells inherit the
  variable, so Orca's agents get it too. A process that starts without any login shell
  (a launchd job, an app opened from Finder) does not: only `.zshenv` reaches those,
  and that file is encrypted, machine-specific state. Linux and Windows keep their
  defaults.
- **Never declare employer-managed apps.** Jamf installs and updates Zoom, Slack,
  1Password, Cisco Secure Client, Duo, the EDR agent, Jamf Protect, the employer's Self
  Service app, and the App Store's Pages, Numbers, Keynote, iMovie and GarageBand.
  Declaring them would fight the MDM. The user's own apps are declared where a cask
  exists (Firefox; Orca from its own tap; Feishin from a community tap), with
  `adopt = true` so mise takes over the existing bundles instead of replacing them.
  VMware Fusion and Meridian Desktop have no cask and stay manual.
- **Secrets: full archive, host trusted.** The Mac decrypts the whole yadm archive. It
  is already inside the trust boundary: it holds the same identities and works on the
  same accounts. A Mac-only secret subset was rejected for the same reason the daily VM
  rejected one: permanent curation cost against no adversary it would stop. The
  bootstrap saves any file the archive would overwrite before it decrypts.

## Alternatives that lost

- **metapac's brew backend.** It reconciles packages only: no LaunchAgents, no macOS
  defaults, no repositories or hooks, so the Mac would still need a second tool. Its
  `mas` backend also uninstalls with bare `sudo`, which fails without a TTY and is
  unsafe from an agent shell.
- **A separate Mac repository.** It would split the shell, git and omp config this
  repository already owns into two copies that drift apart, and lose the shared review
  and CI.
- **`mise bootstrap --from` (or `--adopt`) without yadm.** mise would clone the repo
  into its own checkout and link only `.config/mise`; every other dotfile would need a
  second mechanism, mise's `[dotfiles]`, alongside yadm on Linux. Two dotfile managers
  for one repository, and no shared encrypted archive.

## Why this is recorded

The choice adds a third operating system to a Linux-first repository, introduces a
second reconciler next to metapac, and fixes how Linux-only files are kept off the Mac.
Reversing any of it touches the shell files, the yadm layout and the docs at once.

## Consequences

- Every new tracked file is Linux-only unless the sparse allowlist names it. Files the
  Mac needs must be added there, and `tests/mac-sparse.clitest.txt` extended.
- Shell changes must keep the Linux branch identical; Mac-only lines go behind
  `$OSTYPE == darwin*`.
- The first `yadm clone` on a Mac runs with `yadm.auto-alt` off (the runbook says how),
  because a clone links every alternate at once and would replace a live
  `~/.config/mise/config.toml` before the bootstrap can save it.
- `mise bootstrap` needs a Ruby 3 to read the Orca and Feishin tap casks, so the config
  declares `ruby = "3"`; `status`, `plan` and the drift report fail until it is
  installed (a real apply fetches one itself).
