# Untracked-config adoption inventory — 2026-08-29

**Story:** [1.7 / #17](https://github.com/amasover/dotfiles/issues/17)

## Outcome

A fresh, read-only scan of the current laptop's `$HOME` found **39
adopt-to-YADM candidates** and **2 encrypt-then-adopt candidates**. No live file
was added, moved, edited, decrypted, or staged. Candidate adoption remains
separately approved and belongs in the focused owner stories named below.

Raw path output stayed local and ephemeral. This artifact records safe paths,
counts, classifications, and rules only; private path names, host identifiers,
account data, and file contents are omitted.

## Snapshot

| Surface | Current result |
| --- | --- |
| YADM tracked paths | 557 |
| Tracked live drift | One modified desktop file; unrelated to this audit and left untouched |
| Encryption manifest | 5 patterns; live manifest byte-identical to the checkout; 14 live file matches |
| Top-level hidden entries | 174 total; 146 roots/files wholly untracked |
| `.config/` | 104,308 untracked files across 108 top-level application roots |
| `.local/bin/` | 156 untracked files |
| `.local/etc/` | No untracked files |
| `.local/share/applications/` | 11 generated application launchers/cache files |
| `.local/share/systemd/user/` | No untracked files |
| Partially tracked `.screenlayout/` | 8 untracked scripts |
| Other top-level, non-dot entries | 207 untracked entries after standard content/source roots were excluded; 14 loose executables were reviewed |

The `.config/` partition is exhaustive: 26 adopt-to-YADM, 2
encrypt-then-adopt, 99,299 machine-local-only, 4,978 ignore, 1 already
covered by encryption, and 2 already ignored. The `.local/bin/` partition is
2 adopt-to-YADM, 128 package/generated/obsolete files to ignore, and 26 files
already ignored. Counts classify files by rule; large browser, Electron,
communications, IDE, and cloud-client trees are not mistaken for hand-written
configuration.

## Adopt-to-YADM candidates

These are decisions, not permission to run `yadm add`.

| Safe path or group | Files | Purpose | Decision and owner |
| --- | ---: | --- | --- |
| `.config/autorandr/<profile>/` plus `.config/autorandr/udev.sh` | 17 | Physical monitor fingerprints, layouts, and switch hooks | Adopt through Story 3.17 [#129](https://github.com/amasover/dotfiles/issues/129) after each available dock is re-saved and verified. Rename the private profile label before tracking; retire unavailable hardware profiles. |
| `.screenlayout/*.sh` | 8 | Manual `xrandr` layouts | Review alongside #129, keep only layouts not superseded by autorandr, and rename private labels before tracking. |
| `.local/bin/tools/hibernate` and `.config/systemd/user/locker.service` | 2 | i3 idle hibernation and lock integration | Adopt by refactoring in Story 3.7 [#14](https://github.com/amasover/dotfiles/issues/14). i3 currently calls the untracked hibernation helper, so a rebuild loses behavior; both files also contain a literal current-home path. |
| `.local/bin/tools/vpn` | 1 | Live VPN service wrapper | Adopt through Story 2.14 [#62](https://github.com/amasover/dotfiles/issues/62) only after private site/account values move to machine-local or encrypted input. Do not track the current file verbatim. |
| `.config/bat/config` and `.config/broot/conf.toml` | 2 | Nord/no-pager `bat` behavior and custom `broot` verbs | Portable shell preferences; adopt in focused shell/tool cleanup. Generated broot launcher files remain ignored. |
| `.config/fontconfig/fonts.conf`, `.gtkrc-2.0.mine`, and `.config/flashfocus/flashfocus.yml` | 3 | Font substitution, GTK appearance, and active i3 focus-flash behavior | Adopt through desktop classification, Story 3.3 [#30](https://github.com/amasover/dotfiles/issues/30). |
| `.config/powershell/Microsoft.PowerShell_profile.ps1` | 1 | Vi editing mode in PowerShell | Portable shell preference; adopt through Story 3.1 [#28](https://github.com/amasover/dotfiles/issues/28). |
| `.config/k9s/aliases.yaml` | 1 | Generic Kubernetes resource aliases | Safe portable aliases; adopt in focused tool cleanup. Generated k9s state and the current absolute state path remain machine-local. |
| `.config/Thunar/uca.xml` | 1 | “Open Terminal Here” custom action | Adopt through desktop classification #30. Generated window geometry and empty accelerator state remain ignored. |
| `.config/lutris/games/uplink-gog-1602789884.yml` | 1 | Uplink launcher definition | Adopt or reproduce through Story 2.16 [#64](https://github.com/amasover/dotfiles/issues/64); do not treat Lutris window/account state as configuration. |
| `AGENTS.md` and `skills-lock.json` | 2 | Caveman response rules and pinned cross-agent skill sources | Preserve one source plus an installation mechanism through OMP plugin evaluation, Story 3.29 [#207](https://github.com/amasover/dotfiles/issues/207). Identical copies under tool-specific directories are generated duplicates, not separate candidates. |

## Encrypt-then-adopt candidates

| Safe path | Purpose | Decision |
| --- | --- | --- |
| `.config/qutebrowser/quickmarks` | Personal browser shortcuts | Valuable, but URLs can reveal private systems and interests. Add the path to `.config/yadm/encrypt` before adoption. |
| `.config/qutebrowser/bookmarks/urls` | Personal qutebrowser bookmarks | Same encrypted-adoption requirement. |

The existing encrypted set is already handled, not newly untracked work:
`.ssh/**`, `.zshenv`, VS Code user settings, and the two AUR-quarantine trust
files. No encrypted content was opened.

## Machine-local-only rules

The following stay intentionally outside tracked plaintext:

- Git identity includes, shell local overrides, YADM repository identity, and
  host/class inputs already designed as local seams.
- Password-manager, cloud, VPN, Kubernetes-context, remote-desktop, browser,
  communications, IDE account/session, and credential-store roots.
- Laptop calibration and runtime state: ambient-light curves, PulseAudio
  cookies/device databases, viewer geometry, hardware IDs, and VM display state.
- Mutable agent settings and session stores. Claude settings are reconciled by
  the existing bootstrap merger; OMP's project model selection is explicitly
  ignored.
- One app settings file triggered `betterleaks`; it was classified machine-local
  without recording its contents or finding.

These rules account for the 99,299 `.config/` files classified
machine-local-only and 61 wholly untracked top-level hidden roots/files. A rule
covers the whole named private/application root, so individual credential or
private path names do not need to appear in this public artifact.

## Ignore rules

- Caches, logs, histories, lock files, crash data, backups, undo files, generated
  menus, launchers, MIME caches, application databases, and window geometry.
- Browser/Electron/IDE package and profile data; language package stores;
  generated shell completions; cloned tool/plugin repositories.
- `.local/bin/` outputs owned by pip, cloud CLIs, standalone installers, or
  package managers. This includes an old nested password-launcher repository and
  Python bytecode. Package ownership belongs to Story 2.12, not YADM file
  adoption.
- Unreferenced legacy helpers, including the old suspend variant, wallpaper job,
  password launcher, meeting-app wrapper, and obsolete privileged helper.
- Top-level documents, exports, certificates, archives, screenshots, downloads,
  source trees, test artifacts, backups, and personal/work records. The 14 loose
  executables were metadata-reviewed; they are installers, one-off diagnostics,
  private administration, or superseded tooling rather than portable config.
- `.local/share/` is application/package data by default. Only
  `applications/` and `systemd/user/` were separately enumerated; their current
  untracked files are generated or absent.

## Repeatable enumeration method

Run from the laptop's `$HOME`. Keep the raw path list local with mode `0600`; it
can contain private names even when no contents are read.

1. Capture `yadm status --short --untracked-files=no` and `yadm list -a`. Do not
   use unrestricted `yadm status` as the inventory: `$HOME` is the worktree and
   raw output mixes every personal file into one unreviewable stream.
2. Compare the live `.config/yadm/encrypt` byte-for-byte with the checkout, then
   expand its patterns locally. Record counts only; never open encrypted-source
   contents for this audit.
3. Enumerate names, type, size, mode, and modification time without following
   symlinks for:
   - top-level `$HOME` entries;
   - `.config/` recursively, grouped by first application directory;
   - `.local/bin/` and `.local/etc/` recursively;
   - `.local/share/applications/` and `.local/share/systemd/user/`;
   - `.config/systemd/user/`, `.screenlayout/`, and root-level entries of
     partially tracked agent-config directories.
4. Normalize every path relative to `$HOME`; subtract `yadm list -a`; run the
   remaining paths through `yadm check-ignore --stdin`; then apply encryption
   patterns before human classification.
5. Apply the machine-local and ignore rules above by whole root first. Inspect
   only the small remainder, names/metadata before contents. Before reading a
   candidate, scan it with `betterleaks stdin --redact --no-banner` and perform a
   manual privacy pass.
6. Compare the new category counts and safe candidate table with this snapshot.
   Any new root or count change is review input, not automatic adoption. Delete
   the raw local report after decisions are recorded.

## Verification and boundaries

- The fresh scan used current `$HOME`; prior inventories were consulted only
  after enumeration.
- All 39 adopt-to-YADM candidates passed individual redacted scans using
  `betterleaks stdin`; the untracked helper directory also passed a directory scan.
- A separate machine-local app settings file triggered the scanner and stayed
  excluded without recording its contents or finding.
- No Emacs/Spacemacs file, process, package, checkout, or concurrent branch was
  touched.
- No `yadm add`, encryption, package mutation, service action, root action,
  remote write, or live-file edit occurred.
