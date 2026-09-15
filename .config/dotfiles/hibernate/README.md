# Hibernate preallocation workaround

Opt-in workaround for machines whose hibernation stalls in image preallocation
under a large working set. It evicts memory to swap while userspace is still
running, so the frozen phase has little left to shrink. Zswap stays enabled for
normal use.

## What goes wrong without it

`systemctl hibernate` freezes userspace, then calls
`hibernate_preallocate_memory()`, which runs
`shrink_all_memory(saveable - image_size)` (`kernel/power/snapshot.c`). Two
properties make that phase pathological on a loaded machine:

- Only the calling thread runs. Userspace and kswapd are frozen, so the whole
  eviction is single-threaded.
- Pages reclaimed into zswap stay in RAM as zsmalloc pages, and
  `saveable_page()` (`kernel/power/snapshot.c`) counts them like any other
  allocated kernel page. Each compression therefore buys only the compression
  savings toward the target, and the compressed remainder must still be
  snapshotted.

The pool drains to real swap only through zswap writeback. Under memory
pressure that is the shrinker, which `zswap_shrinker_count()` and
`zswap_shrinker_scan()` (`mm/zswap.c`) gate on `shrinker_enabled`. The only
other drain is the pool-full worker in `zswap_store()`, queued on a store
failure onto a single-threaded workqueue and stopping at
`accept_threshold_percent`. So the pool pins up to `max_pool_percent` of RAM
while direct reclaim keeps refilling it.

Observed on this workstation: preallocation fell from 30-90 s to 1509 s, then
1816 s, then past 40 minutes, at roughly 7 MB/s and 100% of one core. The
machine looks frozen at the lock screen because userspace is frozen by design;
it is still making progress.

An earlier version of this directory tried to fix that by setting
`shrinker_enabled=N` for the hibernate window. That is the wrong direction: it
removes the pool's only pressure-driven drain during the one phase that needs
it. It is retired, and `install` deletes it from machines that still carry it.

Forcing the flag the other way does not help either. In a rehearsal with a
populated 1.58 GiB pool and `shrinker_enabled=Y`, a 1.42 GiB proactive reclaim
wrote back exactly zero pool pages: `shrink_node_memcgs()` (`mm/vmscan.c`) does
reach memcg-aware shrinkers, but a request satisfied this easily never builds
the scan pressure the shrinker needs. So this workaround leaves the flag alone
and treats the pool as immovable.

## What the workaround does

`ExecStartPre` runs before `systemd-sleep` freezes anything:

1. Saves `zswap.enabled`.
2. Sets `enabled=N`, so this eviction goes to swap rather than into the pool.
3. Writes to `/sys/fs/cgroup/memory.reclaim` until the footprint is below
   `/sys/power/image_size`, in 1 GiB requests, bounded by a deadline.

`ExecStopPost` restores the parameter after resume or a failed start. A
shortfall is logged and never fatal: a slow hibernation beats an aborted one,
and `ExecStartPre` carries a `-` prefix so a broken helper cannot stop the
machine hibernating. The eviction target is computed from `MemTotal - MemFree`,
which already counts pool pages, so an undrainable pool is paid for out of
evictable memory instead. Root `memory.reclaim` is global reclaim; the
`reclaim` cftype carries no `CFTYPE_NOT_ON_ROOT` flag (`mm/memcontrol.c`).

`HIBERNATE_PRERECLAIM_DEADLINE` overrides the 120 s budget; `0` removes it.

## Install on an affected machine

Save work and ensure no sleep operation is active. From the repository root:

```sh
pkexec /usr/bin/sh "$PWD/.config/dotfiles/hibernate/install"
systemd-analyze verify systemd-hibernate.service
```

The installed idle timers call `hibernate on-battery` or `hibernate on-laptop`,
which call `systemctl hibernate`. The i3 Alt+Shift+E, H shortcut runs the locker
and `systemctl hibernate`. Both reach this one system service; neither needs
its own wrapper or changed timing. Existing unrelated drop-ins are preserved.

Only `systemd-hibernate.service` is covered. Direct sysfs writes, hybrid sleep,
and suspend-then-hibernate are separate paths and do not use this drop-in.
It does not select swap, change fstab, rebuild initramfs, or modify a bootloader.
Other operating systems and their swap partitions are untouched.

## Verify

Hibernate with a representative working set and a populated zswap pool, from
a session that has been up long enough to fill it. Confirm complete power-off,
boot back into the same installation, and confirm the session returns.

```sh
journalctl -b -u systemd-hibernate.service --no-pager
journalctl -b -k --no-pager | grep 'hibernation: Allocated'
grep Zswap /proc/meminfo
```

The service journal should show the eviction totals and the pool size before
and after, then the restored parameters. The kernel line should report
preallocation in seconds, not tens of minutes.

To measure preallocation without writing an image or powering off, use the
kernel's own staged mode. `hibernation_snapshot()` runs
`hibernate_preallocate_memory()` before the `TEST_DEVICES` bail-out
(`kernel/power/hibernate.c`), so this exercises the exact phase and then thaws:

```sh
pkexec /usr/bin/sh -c 'echo devices > /sys/power/pm_test; echo disk > /sys/power/state; echo none > /sys/power/pm_test'
journalctl -b -k --no-pager | grep 'hibernation: Allocated'
```

Userspace is frozen for the duration, so the desktop is unresponsive while it
runs. `pm_test=freezer` will not do: it returns before preallocation.

## Retire when fixed upstream

Do not leave this workaround indefinitely after the kernel issue is fixed.
A newer kernel version alone is not evidence of a fix. Find a matching upstream
fix, then temporarily move **only** `50-prereclaim.conf` outside the drop-in
directory and reload systemd. Keep the helper and this note during testing.
Repeat the loaded hibernate/resume test above, including full power-off and
return to the same desktop. Save work first; restore the drop-in if the stall
returns.

After those tests pass, remove the workaround while no sleep operation is
active:

```sh
pkexec /usr/bin/sh "$PWD/.config/dotfiles/hibernate/install" --remove
grep Zswap /proc/meminfo
```

Also retire these tracked assets and their runbook link once affected machines
no longer need them; bootstrap deliberately does not install this workaround
universally or recreate it after removal.

References:
- [Kernel zswap documentation](https://docs.kernel.org/admin-guide/mm/zswap.html)
- [Staged hibernation diagnostics](https://docs.kernel.org/power/basic-pm-debugging.html)
