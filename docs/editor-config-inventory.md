# Editor configuration inventory

**Story:** 3.2 · [Issue #29](https://github.com/amasover/dotfiles/issues/29)
**Evidence date:** 2026-08-27

## Role model

“Primary editor” was too coarse for the live workstation. Different tools own distinct
workflows:

| Role | Tool | Classification | Source of truth |
| --- | --- | --- | --- |
| Terminal editor | Vim/GVim | Current | Tracked `.vimrc` + declared packages |
| Workspace editor | Spacemacs on Emacs | Current | Tracked `.spacemacs`; disposable upstream checkout |
| Agentic coding environment | OMP | Current | Tracked `.omp/agent/` config, modes, and reviewed extensions |
| Secondary IDE | VS Code | Current | YADM-encrypted `User/settings.json` |
| Compatibility frontend | Neovim | Current | Three-line tracked shim sourcing `.vimrc` |
| Secondary IDE | IntelliJ IDEA Community | Archive/remove candidate | No portable config selected |
| Rescue editor | Nano | Current utility | Package defaults; no user config |

Terminal editor and workspace editor are both first-class. Neither should be called the
single “primary editor”: Vim owns shell-invoked editing; Spacemacs owns the long-lived
graphical workspace. OMP is not another buffer editor. It is the agent-driven environment
that uses file tools, LSP intelligence, automation, and plugins to change code.

## Vim/GVim — current terminal editor

Evidence:

- `$EDITOR=vim` in live shell configuration.
- Shell aliases, config editing, read-only paging, Git-log viewing, and `MANPAGER` invoke
  Vim.
- `.vimrc` was modernized by Story 2.49: packaged vim-plug and packaged plugins own the
  common path; four active `Plug` fallbacks remain (`vim-repeat`, `vim-terraform`,
  `vim-easyclip`, `nordtheme/vim`).
- GVim 9.2 is installed and provides the Vim command; editor packages declare its plugin
  dependencies.

Known follow-up: installed `nord-vim` 0.18.0 is behind upstream and remains Story 2.50
[#191](https://github.com/amasover/dotfiles/issues/191). That packaging work does not
change Vim's current classification.

## Neovim — current compatibility frontend

`.config/nvim/init.vim` only points Neovim's runtime and package paths at `~/.vim`, then
sources `~/.vimrc`. It owns no independent settings or plugin graph. Keep this deliberate
compatibility shim while Neovim remains installed; changes belong in `.vimrc` unless a
future story establishes a real Neovim-specific workflow.

## Spacemacs/Emacs — current workspace editor

Evidence:

- i3 starts `emacs` on session launch and assigns its window to workspace 1.
- Emacs was running during inventory; Emacs 31.1 is declared in `editor.toml`.
- `.spacemacs` is tracked and has recent compatibility fixes. It selects Vim editing,
  language/LSP layers, Git, completion, syntax checking, Treemacs, and the Nord theme.
- `setup/update` still owns an attended Spacemacs package-update path.
- System dependencies intentionally retained for this config include `nodejs-vmd`
  (Markdown preview), OmniSharp, editorconfig, language tooling, and Hack/Nord display
  inputs. ELPA packages remain Spacemacs-owned rather than metapac-owned.

Decision: `~/.emacs.d` is a **disposable upstream checkout**, not user configuration or a
personal fork. Story 2.13 [#60](https://github.com/amasover/dotfiles/issues/60) must clone
Spacemacs' `develop` branch and make that checkout replaceable. Durable customization
belongs in tracked `.spacemacs` or another explicitly tracked config path.

Live checkout findings to handle under Story 2.13, after a backup:

- Local branch is nine merge/fix commits ahead of upstream `develop`, but current
  `init.el` already matches upstream. The local history is not a maintained fork.
- Untracked `elpa-bak4/`, `init.el.bak`, `projectile-frecency.eld`, and the 2019 `fci`
  copy are generated state, backups, or archive candidates—not bootstrap inputs.
- `lisp/init-gptel.el` is an archive candidate. It has not been loaded: every reference
  in `.spacemacs` is commented, and OMP now owns the agentic-coding role it explored.

No live checkout cleanup belongs to Story 3.2. This story records the disposition;
Story 2.13 performs any approved backup/reset and bootstrap change.

Configuration modernization is separate Story 3.30
[#210](https://github.com/amasover/dotfiles/issues/210): baseline and simplify
`.spacemacs`, restore useful warnings and garbage collection, prove or remove old
workarounds, and fix concrete schema/LSP/config defects without changing editor identity.

## VS Code — current secondary IDE

Evidence:

- VS Code is installed and was actively running during inventory.
- Live `~/.config/Code/` contains current application and extension state, but cache,
  workspace, session, token, and extension payload directories are machine-local data—not
  dotfiles.
- `User/settings.json` contains sensitive configuration and is already listed in
  `.config/yadm/encrypt`.

Decision: YADM's encrypted archive remains the settings source of truth. VS Code extension
ownership and any Settings Sync interaction remain Story 2.12 [#53](https://github.com/amasover/dotfiles/issues/53);
only one extension source of truth may be chosen there. Never track the broader Code data
directory.

## OMP — current agentic coding environment

OMP is first-class development tooling but not a conventional editor. Tracked state is
limited to reviewed `.omp/agent/config.yml`, provider models, mode overlays, and extension
source. Credential/session databases remain machine-local.

Current gaps became focused follow-ups:

- Story 3.28 [#206](https://github.com/amasover/dotfiles/issues/206): make existing OMP
  LSP operations available across active workstation languages through declared language
  server packages.
- Story 3.29 [#207](https://github.com/amasover/dotfiles/issues/207): security-review and
  evaluate marketplace plugins across agent, hook, and LSP shapes.

## IntelliJ IDEA Community — archive/remove candidate

IntelliJ is explicitly declared and occupies about 2.42 GiB plus its Java runtime. No
process was running, and newest user configuration activity found during inventory was
about ten months old. No unique active workflow was identified during the grill.

Classification means removal candidate, not removal approval. A later package-cleanup
transaction may remove it only after its config is archived as needed and the package
mutation is explicitly approved.

## Dependency and ownership gaps

| Gap | Owner |
| --- | --- |
| Spacemacs checkout is not recreated by bootstrap | Story 2.13 / #60 |
| Spacemacs checkout carries local history and disposable artifacts | Story 2.13 / #60 |
| Spacemacs config suppresses diagnostics/GC and carries likely-obsolete workarounds | Story 3.30 / #210 |
| OMP language servers are incomplete and two existing servers are unowned global installs | Story 3.28 / #206 |
| OMP marketplace configured but no plugins evaluated or installed | Story 3.29 / #207 |
| VS Code extension source of truth is undecided | Story 2.12 / #53 |
| IntelliJ package/config removal is unapproved | Later package cleanup after archive decision |
| nord-vim public packaging is stale | Story 2.50 / #191 |

## Story 3.2 closure

All named surfaces have a classification, external dependencies and ownership gaps are
recorded, and the workstation's editor roles are explicit. Story 3.2 changes no live
checkout, package, encrypted payload, plugin, or editor process. Operational changes stay
with their owning follow-up stories.
