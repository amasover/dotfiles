# metapac — declarative packages

[metapac](https://github.com/ripytide/metapac) reconciles installed packages
against what's declared here: `metapac sync` installs the declared set,
`metapac unmanaged` shows drift.

- **`groups/*.toml`** — shared packages by purpose plus concrete hardware
  adapters and one inbox per class. Plain tracked files, read directly at sync
  time; no render step.
- **`profiles/common.groups`** — the one shared 15-purpose list included by every
  class branch. Add a universal purpose group here once, not in three profiles.
- **`config.toml##template`** — maps the rendered hostname to the selected class:
  `workstation`, `daily-vm`, or `qemu-harness`. Each class adds exactly one
  hardware adapter and inbox. YADM renders `config.toml` on clone/pull/class
  change; hostnames and `$HOME` paths remain machine-local.
- **`~/.local/share/metapac/machine-local.toml`** — untracked group for
  never-publish package names only. Hardware belongs in tracked class adapters;
  bootstrap creates this file empty on fresh machines.
- **`known-broken.toml`** — NOT a group: declared packages a human recorded as
  unbuildable (Story 2.38). Unattended runs skip them while the AUR commit is
  unmoved. Managed only via `aur-quarantine broken`/`unbroken`, never by hand
  or by a failure; metapac itself ignores the file.

Why the profile knob is yadm's (`local.class`) rather than metapac's, and the
rest of the design: [docs/decision-bootstrap-architecture.md](../../docs/decision-bootstrap-architecture.md).
Fresh-machine flow: [docs/runbook-fresh-machine-bootstrap.md](../../docs/runbook-fresh-machine-bootstrap.md).
