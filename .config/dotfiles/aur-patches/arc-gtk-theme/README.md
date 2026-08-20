# arc-gtk-theme build fix for meson >= 1.12 (Story 3.18, #137)

The gresource `find` in `common/gnome-shell/meson.build` feeds the searched
directories themselves into `depend_files`; meson 1.12 validates those entries
with `os.path.isfile()` and dies (`File .../icons does not exist.`). Bracket:
meson 1.11.2 built this tree fine (2026-07-19 guest run), 1.12.0 fails
(2026-08-16). The patch excludes directories from the find — validated against
both the 20221218 release tarball (full split-package build in a harness
guest) and upstream master.

Upstream fix submitted from `~/code/arc-theme`, branch
`gnome-shell-gresource-meson-1.12` (github.com/jnsh/arc-theme PR by Aaron).

**Delete this dir when:** the upstream PR is merged AND the AUR package
(pkgbase `arc-gtk-theme`, also building `arc-solid-gtk-theme`) ships a
recipe/source containing the fix — or when Story 3.18 retires Arc entirely.
