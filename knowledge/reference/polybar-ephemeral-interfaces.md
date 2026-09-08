# Polybar ephemeral-interface fork

## Answer

`Swivelgames/polybar` is a GitHub fork of official
[`polybar/polybar`](https://github.com/polybar/polybar). The AUR package
[`polybar-wireguard-git`](https://aur.archlinux.org/packages/polybar-wireguard-git)
builds the fork's `ephemeral-interfaces` branch.

The branch's patch exists as commit
[`58eebe85`](https://github.com/Swivelgames/polybar/commit/58eebe85d5a6abf432c252bf8e410ee37723b517),
`feat(network): now supports ephemeral interfaces`. It is proposed to official
Polybar in [upstream PR #2980](https://github.com/polybar/polybar/pull/2980),
but that PR remains open and unmerged. GitHub also exposes the commit under the
upstream repository's PR object namespace; that does not mean it is on
`polybar/polybar`'s `master` branch or in release 3.7.2.

## What changes

Official 3.7.2's
[`network_module` constructor](https://github.com/polybar/polybar/blob/3.7.2/src/modules/network.cpp#L40-L54)
throws `Invalid network interface` when a configured interface does not exist.
Polybar then disables that module for the lifetime of the bar.

The fork's commit changes
[`src/modules/network.cpp`](https://github.com/Swivelgames/polybar/blob/58eebe85d5a6abf432c252bf8e410ee37723b517/src/modules/network.cpp#L96-L145):

- remove constructor-time interface validation and adapter creation;
- add lazy `setup()` plus an `m_setup` state flag;
- when the interface is absent, set `m_connected = false` and return success so
  Polybar renders `format-disconnected` instead of disabling the module;
- when the interface later appears, create the network adapter and query it;
- when a query fails after disappearance, remain disconnected instead of
  killing the module.

The same commit adds rudimentary WireGuard detection in
[`src/adapters/net.cpp`](https://github.com/Swivelgames/polybar/blob/58eebe85d5a6abf432c252bf8e410ee37723b517/src/adapters/net.cpp#L324-L333),
treating a present WireGuard interface as a connected tunnel.

## Why this machine uses it

The configured VPN module watches transient `tun0`. It relies on the generic
**ephemeral-interface** part of the patch, not specifically the WireGuard driver
check:

- disconnected: `tun0` is absent; module stays alive and renders `disconnected`;
- connected: the VPN creates `tun0`; the module lazily attaches and renders
  `connected`;
- disconnected again: `tun0` disappears; the module returns to its disconnected
  format without restarting Polybar.

Live comparison on 2026-09-08 matched the source behavior: official Polybar
logged `Disabling module "vpn" (reason: Invalid network interface "tun0")`;
the rebuilt fork launched with `tun0` absent, kept the module enabled, and
rendered the `disconnected` control.

## Package source

The AUR
[`PKGBUILD`](https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=polybar-wireguard-git)
sets:

```bash
url="https://github.com/Swivelgames/polybar"
_branchname="ephemeral-interfaces"
```

Its `prepare()` checks out and resets to `origin/ephemeral-interfaces`. Because
this is an AUR-built binary, repository library soname upgrades can require a
manual rebuild; the 2026-09 `jsoncpp` `.26` to `.27` transition exposed that
maintenance cost.
