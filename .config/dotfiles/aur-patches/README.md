# aur-patches — repo-local patches for AUR builds (temporary by design)

`<pkgbase>/*.patch` files here are applied (`patch -Np1`, sorted order) to the
extracted source whenever `aur-quarantine build` builds that pkgbase — the
stepping path, and bootstrap's pre-build pass. Bootstrap builds a declared,
not-yet-installed package through this path BEFORE the package sync when a
patch dir exists for it, so fresh machines get the patched build and metapac
(which requests only missing packages) never asks yay to rebuild it broken.

Every patch here is a loan against upstream: each dir's README must name the
upstream fix it mirrors and the condition for deleting the patch. A patch that
stops applying fails the build loudly — that is the signal to refresh or
delete it, never to force it.

Current patches:

- `arc-gtk-theme/` — meson ≥ 1.12 build fix; delete when the upstream PR is
  merged AND the AUR package ships a commit containing it (see its README).
