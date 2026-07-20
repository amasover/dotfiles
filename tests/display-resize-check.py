#!/usr/bin/env python3
"""Regression check: vm-harness-display must survive terminal resizes (2.21).

Spawns the display tool in bar mode with a pty as its controlling terminal,
streams lines through it, shrinks the pty mid-stream (kernel delivers the
real SIGWINCH), and checks the tty byte stream for the bug's mechanism:

    After a resize, the scroll-region re-set for the NEW geometry
    (ESC[1;<new_rows-3>r) must reach the tty BEFORE the next mirrored
    stream chunk. If stream bytes hit the tty first, they scroll with a
    stale/terminal-reset region and drag the pinned bar rows into the log
    (the observed "bar text merges into the VM output").

Exit 0 = ordering correct on every resize cycle (fixed).
Exit 1 = at least one cycle saw stream bytes before the region re-set (bug).
"""
import fcntl
import os
import re
import struct
import sys
import termios
import time

TOOL = sys.argv[1] if len(sys.argv) > 1 else ".local/bin/tools/vm-harness-display"
CYCLES = [(40, 100), (30, 80), (46, 120)]  # (rows, cols) shrink/grow sequence


def set_size(fd, rows, cols):
    fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", rows, cols, 0, 0))


def main():
    master, slave = os.openpty()
    set_size(master, 50, 132)
    stdin_r, stdin_w = os.pipe()
    stdout_r, stdout_w = os.pipe()

    pid = os.fork()
    if pid == 0:
        os.setsid()
        fcntl.ioctl(slave, termios.TIOCSCTTY, 0)  # make the pty /dev/tty
        os.dup2(stdin_r, 0)
        os.dup2(stdout_w, 1)
        for fd in (master, stdin_w, stdout_r, stdin_r, stdout_w):
            os.close(fd)
        os.execvp("python3", ["python3", TOOL, "--mode", "bar",
                              "--phase", "bootstrap", "--phases", "create:done,up:current"])
    os.close(slave)
    os.close(stdin_r)
    os.close(stdout_w)

    os.set_blocking(master, False)
    tty_bytes = bytearray()

    def drain(deadline):
        while time.monotonic() < deadline:
            try:
                tty_bytes.extend(os.read(master, 65536))
            except (BlockingIOError, OSError):
                # EIO just means no slave fd is open yet (openpty fds are
                # cloexec; the tool's own /dev/tty open takes a moment)
                time.sleep(0.01)

    # readiness: the tool's first act on the 50-row pty is the region set
    drain(time.monotonic() + 0.2)
    deadline = time.monotonic() + 5
    while b"\x1b[1;47r" not in tty_bytes:
        if time.monotonic() > deadline:
            print("RED: tool never initialized its scroll region")
            sys.exit(1)
        drain(time.monotonic() + 0.1)

    def feed(data):
        os.write(stdin_w, data)
        # consume pass-through stdout so the tool never blocks on a full pipe
        os.set_blocking(stdout_r, False)
        try:
            os.read(stdout_r, 65536)
        except (BlockingIOError, OSError):
            pass

    feed(b"==> Package reconcile (metapac shows its plan and prompts)\n")
    for i in range(20):
        feed(f" pkg-{i} 1.0 MiB 2.0 MiB/s 00:01 [####] 100%\n".encode())
    drain(time.monotonic() + 0.3)

    failures = []
    for n, (rows, cols) in enumerate(CYCLES, 1):
        marker = len(tty_bytes)
        set_size(master, rows, cols)          # kernel sends SIGWINCH now
        time.sleep(0.02)                      # let the signal land
        sentinel = f"RESIZE-SENTINEL-{n}\n".encode()
        feed(sentinel)
        drain(time.monotonic() + 0.15)        # well under the 0.5s ticker
        after = bytes(tty_bytes[marker:])
        region = f"\x1b[1;{rows - 3}r".encode()
        r_at = after.find(region)
        s_at = after.find(b"RESIZE-SENTINEL-%d" % n)
        if s_at == -1:
            failures.append(f"cycle {n}: sentinel never mirrored")
        elif r_at == -1 or r_at > s_at:
            failures.append(
                f"cycle {n}: stream bytes hit the tty before the {rows}x{cols} "
                f"region re-set (region at {r_at}, sentinel at {s_at})")
        drain(time.monotonic() + 0.6)         # let the ticker catch up between cycles

    os.close(stdin_w)
    drain(time.monotonic() + 0.5)
    os.waitpid(pid, 0)

    if failures:
        print("RED:", *failures, sep="\n  ")
        sys.exit(1)
    print("GREEN: region re-set preceded the stream on every resize cycle")
    sys.exit(0)


if __name__ == "__main__":
    main()
