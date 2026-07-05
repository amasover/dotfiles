# metapac — declarative packages

[metapac](https://github.com/ripytide/metapac) reconciles installed packages
against what's declared here: `metapac sync` installs the declared set,
`metapac unmanaged` shows drift.

- **`groups/*.toml`** — packages by purpose. Plain tracked files, read directly
  at sync time: to add a package, edit a group and run `metapac sync`. No
  render step.
- **`config.toml##template`** — maps hostname → group list, branching on this
  machine's yadm class (`yadm config local.class <class>`). yadm renders it to
  the real `config.toml` (`yadm alt`; runs automatically on clone/pull/class
  change). The rendered file is machine-local and never committed, so hostnames
  and `$HOME` paths stay out of the repo. Edit the template, never the rendered
  file — renders overwrite it.
- **`~/.local/share/metapac/machine-local.toml`** — untracked group for
  never-publish package names; bootstrap creates it empty on fresh machines.

Why the profile knob is yadm's (`local.class`) rather than metapac's, and the
rest of the design: [docs/decision-bootstrap-architecture.md](../../docs/decision-bootstrap-architecture.md).
Fresh-machine flow: [docs/runbook-fresh-machine-bootstrap.md](../../docs/runbook-fresh-machine-bootstrap.md).
