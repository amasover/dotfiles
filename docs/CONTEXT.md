# Glossary

Vocabulary for the vm-harness / bootstrap tooling. (Lives under `docs/` rather
than the repo root because the root maps into `$HOME` via yadm.)

- **Phase** — one vm-harness subcommand's unit of work (`fetch`, `create`,
  `install`, `boot`, `bootstrap`, `check`). The logging unit.
- **Run** — one timestamped invocation. An all-in-one run spans several
  phases that share the run's timestamp prefix in log filenames.
- **Attached** — the default mode: the harness process runs in your terminal,
  guest output streams there live (with colors), and closing the terminal
  kills the run.
- **Detached** — `--detach`: the harness process survives the terminal;
  output goes only to the state logs (plain text); you re-attach by tailing.
- **State logs** — host-side per-phase log files under
  `~/.local/state/bootstrap-harness/logs/`. Survive `destroy`.
- **Serial log** — the guest's serial-console capture (`install.log` in the
  workdir), written by qemu, root-owned. The only live view of the `install`
  phase; copied into the state logs when install completes.
- **Gold run** — a full clean acceptance loop (`destroy → create → install →
  boot → bootstrap → check`) with everything committed, used as merge
  evidence.
