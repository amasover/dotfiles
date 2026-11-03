#!/usr/bin/env python3
"""Run a command on a pseudo-terminal, answer its prompts, record the screen.

    pty-drive.py --log FILE [--answer REGEX TEXT]... [--timeout S] -- CMD [ARG]...

Every byte the command writes to the terminal goes to FILE: the same bytes
script(1) records for the VMware harness's interactive guest session. Each
--answer waits, in order, for REGEX to appear in the output since the
previous answer, then types TEXT plus Enter, as a person at the keyboard
would. Exits with the command's exit code (128+N for signal N); 124 when the
timeout passes first. Used by tests/vm-harness-guest.clitest.txt to prove a
typed passphrase never reaches the recording.
"""

import argparse
import os
import pty
import re
import select
import signal
import sys
import time


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--log", required=True)
    ap.add_argument("--answer", nargs=2, action="append", default=[],
                    metavar=("REGEX", "TEXT"))
    ap.add_argument("--timeout", type=float, default=60)
    ap.add_argument("cmd", nargs=argparse.REMAINDER)
    args = ap.parse_args()
    cmd = args.cmd[1:] if args.cmd[:1] == ["--"] else args.cmd
    if not cmd:
        ap.error("no command")

    pid, fd = pty.fork()
    if pid == 0:
        os.execvp(cmd[0], cmd)

    answers = [(re.compile(rx.encode()), text.encode() + b"\n") for rx, text in args.answer]
    out = bytearray()
    seen = 0  # output already matched by earlier answers
    deadline = time.monotonic() + args.timeout
    timed_out = False
    while True:
        if time.monotonic() > deadline:
            timed_out = True
            os.kill(pid, signal.SIGKILL)
            break
        ready, _, _ = select.select([fd], [], [], 0.2)
        if not ready:
            continue
        try:
            chunk = os.read(fd, 4096)
        except OSError:  # EIO: the child closed the terminal
            break
        if not chunk:
            break
        out += chunk
        if answers:
            m = answers[0][0].search(out, seen)
            if m:
                seen = m.end()
                time.sleep(0.3)  # let the prompt switch echo off first
                os.write(fd, answers.pop(0)[1])
    _, status = os.waitpid(pid, 0)
    with open(args.log, "wb") as f:
        f.write(out)
    if timed_out:
        return 124
    return os.waitstatus_to_exitcode(status) if os.WIFEXITED(status) else 128 + os.WTERMSIG(status)


if __name__ == "__main__":
    sys.exit(main())
