# Runbook: adopt the work Mac (class `work-mac`)

Design: [decision-mac-host.md](./decision-mac-host.md). Entry point:
[`.config/yadm/bootstrap##os.Darwin`](../.config/yadm/bootstrap%23%23os.Darwin).
Config: [`.config/mise/config.toml##os.Darwin`](../.config/mise/config.toml%23%23os.Darwin).
Story 2.61.

Adoption is the first reconcile of a running machine. It is done when
`brew-drift-report` is empty and `yadm status` is clean.

## Before you start

- macOS on Apple Silicon, a local admin account, zsh as the login shell.
- `yadm` and `git`: `brew install yadm` (Homebrew) or any other install. Apple's git
  is enough.
- mise in `~/.local/bin` (`curl https://mise.run | sh`) or from Homebrew.
- The yadm archive passphrase, if you will decrypt now.
- For agent-skills (Story 4.13): the Mac on the LAN, and its SSH key accepted by the
  Forgejo. Accept the host key once by hand (`ssh -p <port> git@<host>`), because
  the bootstrap's probe runs with `BatchMode=yes` and never answers a prompt.

## 1. Save what adoption replaces

The repo's shell, git, mise and omp files will land over any you have. Copy them
aside first:

```bash
mkdir -p ~/pre-yadm
for f in .zshrc .zprofile .profile .gitconfig .config/mise/config.toml .omp/agent/config.yml .omp/agent/models.yml; do
    [ -e ~/"$f" ] && mkdir -p ~/pre-yadm/"$(dirname "$f")" && cp -p ~/"$f" ~/pre-yadm/"$f"
done
```

## 2. Clone without a checkout

Turn off yadm's automatic alternate linking for the clone. A clone links every
alternate at once, and the mise link would replace `~/.config/mise/config.toml`
before the bootstrap could save it. The bootstrap turns it back on.

```bash
yadm config yadm.auto-alt false
yadm clone --no-checkout --no-bootstrap https://github.com/amasover/dotfiles.git
```

Nothing lands in `$HOME` yet.

## 3. Preview, then run the bootstrap

The bootstrap is read straight from the clone, so no file has to land first:

```bash
bash <(yadm show 'HEAD:.config/yadm/bootstrap##os.Darwin') --check
bash <(yadm show 'HEAD:.config/yadm/bootstrap##os.Darwin')
```

It sets `local.class work-mac`, applies the sparse rules, checks out the files the
Mac gets, backs up any regular file a Darwin alternate replaces (`<file>.pre-yadm`),
links the alternates, offers to decrypt the archive, and runs `mise bootstrap`.

- **Files left alone.** A tracked file already in `$HOME` with other content is listed
  and left as it is. Compare each one (`yadm diff -- ~/.zshrc`), then keep yours or
  take the repo's with `yadm checkout -- ~/.zshrc`. Your copies are in `~/pre-yadm`.
  On the first adoption expect `.zshrc` and `.zprofile` (mise wrote its own blocks
  there) and `.omp/agent/config.yml` (see the open decisions below).
- **Decrypt.** Answer `y` to decrypt the full archive. It asks for the passphrase
  twice: once to list the archive, once to extract it. Every existing file the
  archive would overwrite, `~/.ssh/config` included, is saved first to
  `~/.local/state/dotfiles/pre-decrypt-<time>.tar`. Check that your Mac's SSH keys
  and config still work afterwards; restore from the tar if they don't. After a
  decrypt, later runs skip the offer until the archive changes; run
  `bash ~/.config/yadm/bootstrap --decrypt` to be asked again.
- **mise.** `mise bootstrap` shows what it will do and asks before it changes anything.
  It installs the declared formulae, adopts the already-installed Firefox, Orca and
  Feishin (`adopt = true` keeps their privacy grants), clones oh-my-zsh, writes the
  macOS defaults, installs node and Ruby, then runs the agent-skills hook. Restart
  Finder (`killall Finder`) after it writes defaults.

Later runs need no flags: `yadm bootstrap` runs every step again and changes only what
drifted.

## 4. Verify

```bash
yadm status                       # clean
zsh -i -c exit                    # nothing on stderr
mise bootstrap status --missing   # exit 0
brew-drift-report                 # every section [ok]
omp config get modelRoles         # Opus 5.5 xhigh default, from the tracked config.yml
```

Open a new terminal: the agnoster prompt, autosuggestions and syntax highlighting all
load.

## What stays manual

- **Employer-managed apps.** Jamf owns them; never declare or remove them from mise.
- **VMware Fusion and Meridian Desktop.** No cask exists. Update them from their own
  download pages.
- **agent-skills setting.** Without `~/.config/dotfiles/agent-skills/remote.env` (it
  rides the encrypted archive once someone runs `yadm encrypt` with it present), the
  hook prints one warning and moves on. The file holds one line,
  `AGENT_SKILLS_URL=<ssh URL>`.

## Undo

- `mise bootstrap` writes no shell files (`mise_shell_activate zsh = false`).
  `mise dot undo` reverses what it tracked; casks it installed come off with
  `mise bootstrap packages prune --manager brew-cask --dry-run`, then without
  `--dry-run`.
- Restore files from `~/pre-yadm`, the `*.pre-yadm` backups, and the pre-decrypt tar.
- `rm -rf ~/.local/share/yadm/repo.git` forgets the yadm clone; the files stay.
