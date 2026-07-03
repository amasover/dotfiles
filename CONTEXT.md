# Dotfiles workstation platform

Ubiquitous language for the workstation-platform repo: bootstrap, package management,
and the AUR-safety model. Glossary only — implementation lives in `docs/` and the code.

## Language

**Reconcile loop**:
The declarative cycle that makes a machine match its manifest — packages, services,
dotfiles. A fresh install is the first reconcile.
_Avoid_: sync (ambiguous with the metapac subcommand), install flow

**Update loop**:
The imperative cycle that advances versions carefully (repo/AUR upgrades, runtimes,
plugins). Sequential and stateful; distinct from reconciling.
_Avoid_: upgrade flow, maintenance script

**Quarantine**:
The safety gate that holds suspicious AUR *upgrades* (too new, orphaned, maintainer
changed) out of an update. Applies to upgrades of already-installed packages only —
first-time installs are not yet gated.
_Avoid_: hold-back, delay list

**Trusted baseline**:
The per-machine record of which AUR package/maintainer pairs are trusted. Machine-local
today; a fresh machine starts with none.
_Avoid_: whitelist

**Adoption**:
The first reconcile of an already-running machine: authoring its groups and iterating
until nothing on the machine is undeclared. Complete when the drift report is empty.
_Avoid_: migration, onboarding

**Drift report**:
A read-only, end-of-update statement of how the machine diverges from its declared
groups (extra packages, missing packages). Reports only; a human applies changes.
_Avoid_: sync report, audit

**Inbox**:
The per-machine holding group where newly installed, not-yet-categorized packages land
automatically until triaged into a purpose group. One inbox per host; never shared.
_Avoid_: uncategorized, misc, staging

**Purpose group**:
A named, declarative set of packages serving one role (base, desktop, development, …).
A machine's profile is the list of purpose groups it activates.
_Avoid_: manifest (the legacy flat lists), category

**Bootstrap**:
The one-time sequence that takes a fresh OS install to a working workstation by driving
the reconcile loop for the first time.
_Avoid_: install script (the dead 2019 artifact), setup
