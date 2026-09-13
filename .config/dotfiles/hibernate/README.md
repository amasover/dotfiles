# Hibernate-only zswap shrinker workaround

Opt-in workaround for machines that hang during hibernation memory reclaim
with a populated zswap pool. It pauses only the proactive memory-pressure
shrinker. Zswap caching and full-pool eviction remain enabled; the previous
shrinker setting is restored after resume or a returned service failure.

## Install on an affected Arch machine

Save work and ensure no sleep operation is active. From the repository root,
install the helper first and the drop-in last:

```sh
pkexec /usr/bin/install -Dm755 "$PWD/.config/dotfiles/hibernate/hibernate-zswap-shrinker" /usr/local/libexec/hibernate-zswap-shrinker
pkexec /usr/bin/install -Dm644 "$PWD/.config/dotfiles/hibernate/README.md" /etc/systemd/system/systemd-hibernate.service.d/README.md
pkexec /usr/bin/install -Dm644 "$PWD/.config/dotfiles/hibernate/50-zswap-shrinker.conf" /etc/systemd/system/systemd-hibernate.service.d/50-zswap-shrinker.conf
pkexec /usr/bin/systemctl daemon-reload
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

Perform an attended hibernate with a representative memory workload and a
populated zswap pool. Confirm complete power-off, boot back into the same Arch
installation, and confirm the working session returns. Never boot Ubuntu or
mount shared filesystems from another OS while Arch is hibernated.

```sh
journalctl -b -u systemd-hibernate.service --no-pager
cat /sys/module/zswap/parameters/enabled
cat /sys/module/zswap/parameters/shrinker_enabled
```

The service journal should show the pause before sleep and restoration after
return. Zswap stays enabled; the shrinker returns to its original value,
including `N` if it was deliberately disabled beforehand. A hard reset clears
the temporary `/run` state; normal boot policy controls the shrinker again.

## Retire when fixed upstream

Do not leave this workaround indefinitely after the kernel issue is fixed.
A newer kernel version alone is not evidence of a fix. Find a matching upstream
fix, then temporarily move **only** `50-zswap-shrinker.conf` outside the drop-in
directory and reload systemd. Keep the helper and this note during testing.
With `shrinker_enabled=Y` throughout, repeat loaded hibernate/resume tests,
including full power-off and return to the same desktop. Save work first;
restore the drop-in if the hang returns.

After those tests pass, remove the workaround while no sleep operation is active:

```sh
pkexec /usr/bin/rm /etc/systemd/system/systemd-hibernate.service.d/50-zswap-shrinker.conf /usr/local/libexec/hibernate-zswap-shrinker /etc/systemd/system/systemd-hibernate.service.d/README.md
pkexec /usr/bin/systemctl daemon-reload
cat /sys/module/zswap/parameters/shrinker_enabled
```

If the drop-in is still parked outside its directory after testing, remove that
saved copy instead of the original path. Keep zswap and hibernation enabled.
Also retire these tracked assets and their runbook link once affected machines
no longer need them; bootstrap deliberately does not install this workaround
universally or recreate it after removal.

References:
- [Kernel zswap documentation](https://docs.kernel.org/admin-guide/mm/zswap.html)
- [Staged hibernation diagnostics](https://docs.kernel.org/power/basic-pm-debugging.html)
