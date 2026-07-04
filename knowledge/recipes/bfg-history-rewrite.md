# Recipe: BFG history rewrite (sensitive-string scrub)

Executed for Story 1.8 ([#55](https://github.com/amasover/dotfiles/issues/55)),
2026-07-03. Reusable for any future history scrub of this repo.

## Order of operations (the part that matters)

1. **Clean HEAD first, via normal PR.** BFG protects the latest commit; scrubbing
   history while tracked files still contain the strings achieves nothing (next push
   re-leaks). Move live-needed values to untracked includes (`~/.gitconfig-local`,
   `~/.zshrc.local`) *before* removal, and pre-create them on every machine **before
   that machine pulls** — otherwise git identity breaks loudly.
2. **Bundle before deleting anything.** `git bundle create <salvage>/<name>.bundle <refs…>`
   for pruned branches, old tags, anything irreversible. Salvage dir:
   `~/.local/share/dotfiles-salvage/` (machine-local; contents may hold the literals —
   that's its job).
3. **Prune stale remote branches** so the rewrite scope shrinks and dead refs don't
   carry old blobs.
4. **Mirror clone → BFG → gc:**
   ```bash
   git clone --mirror https://github.com/amasover/dotfiles.git m.git
   bfg --replace-text <private-replacements-file> \
       -fe '*.{ttf,otf,png,jpg,jpeg,ico,gpg,woff,woff2}' --private m.git
   git --git-dir=m.git reflog expire --expire=now --all
   git --git-dir=m.git gc --prune=now --aggressive
   ```
   The replacements file (`literal==>[placeholder]` lines) is generated from actual
   historical case variants and lives gitignored under `docs/private/` — never committed.
   `-fe` protects binaries (fonts/PNG match short tokens as coincidental bytes).
5. **Verify with a positive control.** Per literal:
   `git --git-dir=m.git log --all --oneline -S"$lit" | wc -l` must be 0 — but first
   prove the probe works on a string that must exist (e.g. `metapac`). A broken loop
   yields silent false zeros (bitten twice this run: zsh doesn't word-split `$VAR`
   command strings; an invalid git flag + `2>/dev/null` + `wc -l` also reads as 0).
6. **Force-push with refspecs.** A mirror clone refuses refspecs
   (`--mirror can't be combined with refspecs`); override:
   ```bash
   git --git-dir=m.git -c remote.origin.mirror=false push --force origin \
       'refs/heads/*:refs/heads/*' 'refs/tags/*:refs/tags/*'
   ```
7. **Reset every clone — and hunt local residue.** Old history hides in more than
   `main`:
   - working repo: stale **local branches**, **local tags** (`pre-undiverge-local-main`
     was one), dangling **`refs/stash`**;
   - yadm repo: retired local branches (`master`, `test*`, `merging`), **stashes**
     (each stash pins its whole base chain), stale remote-tracking refs.
   Working repo: `git reset --hard origin/main`, delete non-main locals, expire
   reflogs, gc, re-sweep. yadm: `yadm fetch && yadm reset origin/main` (**mixed** —
   worktree untouched, live drift survives), `yadm checkout` stale tracked files
   (remember: `docs/`, `knowledge/`, `CONTEXT.md` are yadm-tracked in `$HOME` too),
   `yadm alt` re-renders `##template` files, export stash patches to salvage before
   clearing, then gc + sweep.
8. **Machine caveats (this workstation):** `safe.bareRepository=explicit` → drive bare
   repos with `--git-dir=…`; the `pacman`→sudo alias trap's cousin: run sweeps from a
   shell function, not an unquoted command variable.

## Residue that survives a scrub (documented, not fixable locally)

- **GitHub refs/pull/**: old PR diffs (19 refs at execution) keep pre-rewrite blobs
  server-side; removal-diff PRs display the removed literals forever.
- **Fork network**: this repo is a fork (parent: patrick-motard/dotfiles) — GitHub
  pools objects across the network, so old objects can stay SHA-addressable; one child
  fork existed at scrub time (unreachable/404). Full purge = GitHub Support ticket.
  BFG's `--private` kept old commit ids out of rewritten messages, which raises the
  bar for SHA fishing.
- **Chat transcripts / local salvage**: agent-session transcripts and
  `~/.local/share/dotfiles-salvage/` retain literals by nature; treat both as
  sensitive, never republish.
