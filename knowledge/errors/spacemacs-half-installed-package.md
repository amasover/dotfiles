# Error pattern: Spacemacs startup fails "Cannot open load file: … <pkg>" after update

**Observed:** 2026-07-06 with `lsp-mode` after a morning run of `.local/bin/setup/update`.
Startup error: `(Spacemacs) Error in dotspacemacs/user-config: Cannot open load file: No
such file or directory, lsp-mode`.

## Symptom

- `.spacemacs` unchanged (layer still listed); error hits a `(require '<pkg>)`.
- The package dir **exists** under `~/.emacs.d/elpa/develop/<pkg>-<version>/` with all
  `.el` files present, but has **no `<pkg>-autoloads.el` and no `.elc` files**.

## Mechanism

Spacemacs updates in two halves: `configuration-layer/update-packages` only backs up
(to `~/.emacs.d/.cache/rollback/`) and **deletes** the old package dirs; the new
versions are installed by the **next Emacs startup**. If that startup reinstall is
interrupted (window closed mid-install, session ends, elisp error), the package is left
unpacked but never activated. package.el then treats the dir as installed — it never
retries — and every later startup fails at the `require`.

The old update script made this easy to hit: it launched the update as a fire-and-forget
GUI emacs via `i3-msg exec` and never waited or checked the result. Fixed in Story 2.24
([#79](https://github.com/amasover/dotfiles/issues/79)): the script now runs both halves
synchronously in batch mode and scans for package dirs missing their autoloads file.

## Triage

```bash
ls ~/.emacs.d/elpa/develop/<pkg>-*/            # .el files but no *-autoloads.el / *.elc?
grep -n elpa-subdirectory ~/.spacemacs         # nil = flat elpa/develop tree is the live one
```

Note: `~/.emacs.d/elpa/30.2/` is a dead versioned tree from before
`dotspacemacs-elpa-subdirectory nil`; don't be fooled by the package existing there.

## Fix

Either delete the broken dir and start emacs (Spacemacs reinstalls missing used
packages at startup), or repair in place without network:

```bash
emacs --batch --eval "(progn
  (require 'package)
  (setq package-user-dir \"$HOME/.emacs.d/elpa/develop\")
  (package-initialize)
  (package-generate-autoloads \"<pkg>\" \"$HOME/.emacs.d/elpa/develop/<pkg>-<version>\")
  (byte-recompile-directory \"$HOME/.emacs.d/elpa/develop/<pkg>-<version>\" 0))"
```

Verify with a batch `(require '<pkg>)` afterwards.
