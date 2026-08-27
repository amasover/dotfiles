# A weekly `reflector.timer` kept the mirrorlist young — and permanently badly ranked

**Story:** 2.18 ([#66](https://github.com/amasover/dotfiles/issues/66)) ·
found 2026-08-26 during a `setup/update` run.

**Symptom.** `yay -Syu` pulled a 4.5 GiB transaction at ~1.2 MiB/s. Probed
seconds later on the same WiFi link, `mirror.fcix.net` gave 10.3 MiB/s and
`mirror.arizona.edu` 8.2 — so the link was not the limit. `/etc/pacman.d/mirrorlist`
held exactly five servers: `mirror.ufscar.br`, `archlinux.c3sl.ufpr.br`,
`frankfurt`, `johannesburg` and `umea.mirror.pkgbuild.com` — Brazil, Germany,
South Africa, Sweden, for a machine in US Mountain time.

**Cause.** `reflector.timer` was enabled, but `/etc/xdg/reflector/reflector.conf`
was still Arch's stock file: `--latest 5 --sort age --protocol https`, no
`--country`. "Latest by age" ranks by how recently a mirror *synced*, which
says nothing about distance or throughput, so the timer wrote a worldwide
top-five-by-sync-time list every week.

**Why bootstrap's good ranking never rescued it.** Step 3b re-ranks with
`--country 'United States' --fastest 10 --sort rate`, but only when the
mirrorlist is *older than 7 days* — and the weekly timer rewrote the file every
7 days, keeping it permanently under the threshold. **A scheduled job that keeps
a file young silently disables every staleness gate on that file.** Both halves
looked correct in isolation; only their interaction was wrong, and the failure
mode was slowness, which reads as "the network today" rather than as a bug.

**Fix.** One tracked policy file (`.config/dotfiles/reflector.conf`), symlinked
into `/etc/xdg/reflector/` by bootstrap 3b, read by all three consumers: the
timer (steady-state owner), bootstrap's stale re-rank, and zshrc's
`update_pacman_mirrorlist`. `tests/reflector-mirrors.clitest.txt` fails if a
consumer grows its own copy of the args again.

**Generalizes to.** Any "refresh on a schedule" + "act only if stale" pair over
the same artifact: the pacman cache, the AUR quarantine's baseline, encrypted
secret bundles. Gate on *content* (is the ranking still right?) or have exactly
one owner — never on mtime that another owner keeps touching.
