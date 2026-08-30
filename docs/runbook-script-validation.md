# Runbook: Repository Validation (CI + local)

**Stories:** 4.5 shell tooling and 4.7 minimal CI
**Issues:** [#36](https://github.com/amasover/dotfiles/issues/36) and [#94](https://github.com/amasover/dotfiles/issues/94)

This runbook defines the checks enforced by
[`.github/workflows/ci.yml`](../.github/workflows/ci.yml). The workflow delegates repository
logic to [`.github/scripts/ci`](../.github/scripts/ci), so local and hosted validation use the
same commands.

## Enforced workflow

CI runs for every pull request and every push to `main`. One `archlinux:latest` job installs
pacman-native validation tools, checks out full history with a commit-pinned
`actions/checkout`, and runs these stages in order:

1. checksum-verified betterleaks installation from the version and SHA-256 pinned by the
   vendored [`PKGBUILD`](../.config/dotfiles/pkgbuilds/betterleaks/PKGBUILD);
2. checksum-verified pycdlib 1.20.0 wheel extraction for the seed-ISO tests;
3. betterleaks scan of exactly the pull-request or pushed commit range;
4. repository-wide script lint and syntax checks;
5. every host-independent regression suite.

Workflow permissions are `contents: read`. It uses `pull_request`, never
`pull_request_target`, and receives no repository secrets. Story 4.7 changes no branch
protection or ruleset: checks are reported, while the documented direct-to-`main` exception
for small bookkeeping-only docs remains usable.

## Script lint contract

`bash .github/scripts/ci lint` discovers tracked scripts from their first-line shebang. It
then enforces:

- `shellcheck --format=gcc` on every tracked Bash and POSIX sh script;
- `shfmt -i 4 -bn -ci -d` on the same complete set;
- `bash -n` or `sh -n` according to each shebang;
- `zsh -n` on tracked Zsh scripts (`setup/update` today);
- `luac5.1 -p` on every tracked Lua file;
- `actionlint` on every GitHub Actions workflow, including shellcheck integration for
  embedded `run` blocks.

There is no ignored lint baseline. Story 4.7 formatted the full tracked Bash/sh set and
resolved every shellcheck finding so future regressions fail directly instead of being
compared with a warning snapshot.

## Test contract

`bash .github/scripts/ci test` runs:

```bash
clitest tests/*.clitest.txt
pytest tests/
emacs --batch -Q -l tests/spacemacs-config-test.el -f ert-run-tests-batch-and-exit
lua5.1 .config/yay/hook-harness.lua .config/yay/init.lua
.config/dotfiles/tests/chaotic-quarantine-gate-test
```

Baseline when Story 4.7 landed:

- clitest: 479 cases across 21 files;
- pytest: 112 cases across five vm-harness modules;
- Spacemacs config ERT: six isolated contracts;
- yay hook harness and chaotic quarantine gate: both pass their complete policy matrices.

Tests must remain deterministic and host-independent: no libvirt, display server, network,
package mutation, live `$HOME`, or workstation service state. Add tests to these commands;
do not create an uncalled side suite.

## Secret-scan contract

CI derives betterleaks version and checksum from the tracked PKGBUILD, validates both fields,
downloads the official release archive, verifies SHA-256, then installs only the binary in
the disposable job container. The scan uses full Git history plus an explicit range:

- pull request: `github.event.pull_request.base.sha..github.sha` (the tested merge commit);
- push: `github.event.before..github.sha`;
- zero/absent before-SHA fallback: the head commit only.

Local equivalent:

```bash
bash .github/scripts/ci scan-range "$(git merge-base origin/main HEAD)" HEAD
```

The command requires betterleaks already installed locally. Output is always redacted.

## Local reproduction

Install the same tools through the declared Arch packages, then run:

```bash
bash .github/scripts/ci lint
bash .github/scripts/ci test
```

Run `betterleaks dir . --redact --no-banner` plus a manual privacy pass before publishing.
The pre-commit hook separately scans the staged diff.

## Safety boundary

CI never runs `setup/bootstrap`, `setup/update`, VM create/up/destroy operations, package
reconciliation, YADM decrypt/encrypt, desktop commands, or live editor/package mutation.
Those remain attended workflows with their existing approval gates.
