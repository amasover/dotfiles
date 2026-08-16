# A stepped AUR commit does not pin what gets built — `pkgver()` defeats the age guarantee

**Story:** 2.39 ([#130](https://github.com/amasover/dotfiles/issues/130)) ·
split out of 2.38 ([#124](https://github.com/amasover/dotfiles/issues/124)) ·
origin: the Story 2.36 (#119) slice-3 evidence run.

> **Reconstruction note (2026-08-15).** The original version of this note —
> including the policy options enumerated at the 2026-08-13 grill — was lost
> with the unpushed first `story/2.38-unattended-age-holds` branch. This
> rebuild is from the #124/#130 issue bodies, which preserved everything
> **except the options list**. See "Options" below.

**Symptom.** A package the quarantine pre-flight (Story 2.33) stepped to an
aged AUR commit builds a version newer than the pin. Seen 2026-08-13 in the
VMware harness run: `playwright` stepped to the pinned 1.61.0 commit, built
1.62.1, and died on the mismatched source tarball checksum.

**Cause.** Stepping the AUR git checkout pins the *recipe*, not the *result*.
A PKGBUILD that computes its version at build time — a `pkgver()` function
resolving git tags, or an npm/pip "latest" lookup — replaces the pinned
version with the newest upstream release during the build. The 14-day age
guarantee is then void for that package, and nothing says so.

**Why the loud failure was luck.** `playwright` died only because its checksums
no longer matched. A package in this class that builds *cleanly* installs
brand-new upstream code while the run reports it as satisfying the quarantine —
the mechanism silently inverted. That, not the one broken build, is the real
risk.

**Affected class.** Any PKGBUILD computing its version at build time:
`pkgver()` functions, `-git`-style recipes tracking a moving ref, package
managers resolving "latest" inside `build()`. Stepping cannot be trusted for
these; detection of the class is part of Story 2.39's scope.

**Options.** Lost with the original note (see the reconstruction note above).
The 2026-08-13 grill enumerated policy options and chose **none**; the list
must be re-derived — the 2026-08-13 session transcript on the Windows machine
is the likeliest surviving source — before Story 2.39 picks one. The one
constraint #130 preserves: whatever is chosen, a package whose age cannot be
guaranteed must not report as if it can.
