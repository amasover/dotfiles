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

One command, in PowerShell:

```powershell
vm-harness-vmware trust-import
```

gpg prompts for the archive passphrase in its own pinentry dialog — the
passphrase never passes through the harness. Then verify by counting lines
(don't print the contents: they are AUR maintainer identities, so keep them
out of transcripts and logs):

```powershell
Get-ChildItem ~\.local\state\aur-quarantine | Select-Object Name, Length
```

**What it does.** [vm-harness-trust](../../.local/bin/setup/vm-harness-trust)
runs `gpg --decrypt` and feeds its stdout straight into Python's `tarfile` in
stream mode, writing only the two allowlisted members. The decrypted archive
is never written to disk, so `.ssh/**` and `.zshenv` exist in plaintext at no
point — which a `gpg -d -o tmp.tar` + extract sequence could not promise. The
allowlist is an exact-name match, so a hostile archive cannot write outside
the destination, and symlink members named like a trust file are skipped.

**gpg needs no install:** Git for Windows bundles it (`gpg` 2.4.9 plus
`pinentry-w32.exe` for the prompt). The tool takes `gpg` from PATH first, then
falls back to the Git for Windows path; `--gpg` overrides.

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
pulling the newer archive and re-running `trust-import` — it overwrites in
place. Nothing here is authoritative; the archive is, and Story 4.9's
`pre_push` guard keeps the archive itself from going stale.

## If the import comes back empty

`nothing extracted` means the archive carries no trust baseline — the drift
4.9 was written for. Run `yadm encrypt` on the Arch machine, commit and push
the refreshed `.local/share/yadm/archive`, pull here, and re-run.
