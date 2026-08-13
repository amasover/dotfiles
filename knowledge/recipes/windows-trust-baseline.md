# Recipe: the AUR trust baseline on the Windows host

The VMware harness injects the AUR trust baseline into each throwaway guest
before bootstrap, the same way the libvirt harness does — but the Linux host
holds `~/.local/state/aur-quarantine/{maintainers.tsv,exempt.txt}` in plaintext
because it *is* a set-up Arch machine, and the Windows host has no such source.

Without the baseline a guest runs fresh TOFU: the quarantine gate has no record
of any package, so every AUR package reads `@never` and an unattended
`bootstrap` **stops** on the first identity hold. That is what
`kube-capacity (orphan)` / `nodejs-vmd (orphan)` was on 2026-08-11 — both are
recorded in the Linux baseline as orphaned, so orphan-then/orphan-now is no
change and the gate passes once the baseline is present.

Populate it once. The harness then finds it on every later run.

**Trust boundary:** the Windows host is already inside it
([decision-daily-driver-vm.md](../../docs/decision-daily-driver-vm.md) — it can
read the guest's memory and disk). Only the two identity files land here;
`.ssh/**` and `.zshenv` stay inside the archive.

**Prerequisite:** the archive must actually contain them — Story 4.9 (#122)
added the `pre_push` staleness guard for exactly the drift that left them
declared-but-unarchived; the archive was refreshed 2026-08-11.

## Steps

Run in **Git Bash**, not PowerShell — the extraction pipes binary data, and
PowerShell's pipeline mangles it. `gpg` needs no install: Git for Windows
bundles it (`/usr/bin/gpg`, 2.4.9 as of 2026-08).

```bash
cd ~/code/dotfiles
gpg --version | head -1          # confirm gpg is on PATH
```

**1. List the archive members first** (prompts for the passphrase; writes
nothing). This confirms the exact member paths before extracting, and whether
`exempt.txt` is present at all — naming a missing member makes `tar` fail:

```bash
gpg -d .local/share/yadm/archive | tar -tf - | grep aur-quarantine
```

**2. Extract only those members**, relative to `$HOME`:

```bash
gpg -d .local/share/yadm/archive | tar -xf - -C ~ \
    .local/state/aur-quarantine/maintainers.tsv \
    .local/state/aur-quarantine/exempt.txt
```

Drop the `exempt.txt` line if step 1 didn't list it.

**3. Verify placement** — count lines, don't print contents (they are AUR
maintainer identities; keep them out of transcripts and logs):

```bash
wc -l ~/.local/state/aur-quarantine/*
```

## Using it

`vm-harness-vmware bootstrap` reads that directory by default and scp's both
files into the guest, reporting `Trust baseline: injecting ...`. Nothing else
to configure.

- Elsewhere? `VM_HARNESS_TRUST_DIR=<path>` overrides the source directory.
- Want the fresh-TOFU path instead (fast iteration, no baseline)? Move or
  rename the directory — the harness reports `none on host ... — VM runs fresh
  (TOFU)` and continues. Runs meant to predict a real rebuild should use the
  baseline: fresh TOFU trusts whatever it sees, so it goes green where a
  restored machine would hold.

## Keeping it current

The baseline drifts as packages are accepted on the Arch machine. Refresh by
re-running step 2 after a `yadm encrypt` + push on that machine — the extract
overwrites in place. Nothing here is authoritative; the archive is.
