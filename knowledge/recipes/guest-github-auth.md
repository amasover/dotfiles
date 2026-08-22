# Recipe: GitHub auth + git identity in a fresh guest

**Epic/Story:** Story 5.3 — [docs/epic-5-guest-daily-driver.md](../../docs/epic-5-guest-daily-driver.md)
**Issue:** [#150](https://github.com/amasover/dotfiles/issues/150) (decision record)

A fresh guest can clone over HTTPS but cannot push: `gh` has no token, the
guest has no SSH private key, and the tracked `.gitconfig` deliberately leaves
`user.email` to an untracked machine-local file. This is the attended fix,
verified live in the VMware guest on 2026-08-22. Automating it is 5.2 (#149,
attended) / 5.6 (#153, unattended).

## 1. Log gh in (device flow)

```bash
gh auth login --hostname github.com --git-protocol https --web --scopes project
```

Copy the one-time code it prints, open <https://github.com/login/device> in
any browser where GitHub is logged in (the host browser works — the URL is not
machine-bound), enter the code, approve. `--scopes project` is only needed if
the session will touch the Projects board (`gh project item-add`); drop it
otherwise. Default scopes arrive as `gist, read:org, repo, workflow`.

No further setup: the tracked `.gitconfig` already routes github.com through
`gh auth git-credential`, so `git push` works as soon as login completes. Do
**not** run `gh auth setup-git` (it would prepend duplicate helper config).

## 2. Give git an identity

The tracked `.gitconfig` sets `user.name` but sources `user.email` from
untracked `~/.gitconfig-local` (absent on fresh machines — the loud
"Author identity unknown" failure is by design). Either create that file
(fixes every repo on the machine):

```bash
git config --file ~/.gitconfig-local user.email <your-email>
```

or set it repo-locally where you're working:

```bash
git -C ~/code/dotfiles config user.email <your-email>
```

The bootstrap-time fix (guest bootstrap writes `~/.gitconfig-local`) is 5.2's.

## What to expect

- **Two `fatal: Failed to open secret service session` lines per credential
  lookup.** Harmless. The global `git-credential-manager` helper needs a
  keyring the guest doesn't run; git continues down the helper chain to the
  gh helper, which answers. Decision to leave the tracked config alone is on
  [#150](https://github.com/amasover/dotfiles/issues/150); scoping GCM out of
  keyring-less machine classes rides the 2.30 class split (#96).
- **The token is stored in plaintext** at `~/.config/gh/hosts.yml` (mode 600)
  — gh's standard fallback when no keyring exists. Accepted for a disposable
  guest with a scoped token. Note revocation is not per-guest: the token is a
  `gho_` GitHub-CLI OAuth token, and revoking the GitHub CLI app in GitHub
  settings signs out **every** machine's gh, host included. Normal cleanup is
  simply destroying the guest with the token in it.
- **Automation gotcha:** when driving `gh auth login --web` through a pty, the
  "Press Enter" prompt is a raw-mode read — send a carriage return (`\r`), not
  `\n`, and only after the prompt has printed. A human in a real terminal hits
  neither problem. Stay on `gh`'s own commands; scripting GitHub's raw OAuth
  device endpoints looks like credential-harvesting tooling and gets blocked
  by agent permission layers (correctly).

## Verify

```bash
gh auth status          # logged in, expected scopes
git -C ~/code/dotfiles push --dry-run origin HEAD
```
