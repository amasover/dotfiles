"""pytest suite for vm-harness-display's Python-internal logic (Story 2.36
slice 4, #119): the ANSI scrub (port of the bash harness's sed filter), the
phase-breadcrumb parser, the bootstrap step mapper, and the anchor patterns.
No terminal, no VMware, no network — the Renderer itself needs a live tty and
is covered by tests/display-resize-check.py (POSIX) and the clitest cases.
"""

import os
import subprocess
import sys

import pytest

from conftest import load_tool

display = load_tool("vm_harness_display", "vm-harness-display", subdir="tools")

TOOL_PATH = os.path.join(os.path.dirname(__file__), os.pardir,
                         ".local", "bin", "tools", "vm-harness-display")


def scrub_all(data, chunk_size=None):
    """Run bytes through a Scrubber, optionally in fixed-size chunks, and
    collect the output."""
    out = []
    s = display.Scrubber(out.append)
    if chunk_size:
        for i in range(0, len(data), chunk_size):
            s.feed(data[i:i + chunk_size])
    else:
        s.feed(data)
    s.close()
    return b"".join(out)


class TestScrubEscapes:
    def test_csi_colors_stripped(self):
        assert display.scrub_space(b"\x1b[1;32mgreen\x1b[0m text") == b"green text"

    def test_csi_private_params_stripped(self):
        # agetty's ESC[!p soft reset and DEC private sequences
        assert display.scrub_space(b"\x1b[!preset\x1b[?25lhidden") == b"resethidden"

    def test_osc_both_terminators_stripped(self):
        assert display.scrub_space(b"\x1b]0;title\x07bare") == b"bare"
        assert display.scrub_space(b"\x1b]8;;url\x1b\\link") == b"link"

    def test_dcs_stripped(self):
        assert display.scrub_space(b"\x1bPq-terminfo-query\x1b\\tail") == b"tail"

    def test_charset_selectors_and_keypad_stripped(self):
        # the ESC(B tput hides in sgr0; ESC= / ESC> flank full-screen tools
        assert display.scrub_space(b"\x1b(Bplain\x1b=mid\x1b>end") == b"plainmidend"

    def test_caret_notation_replies_stripped(self):
        # guest tty echoes terminal replies as literal '^[[' bytes, no ESC
        line = b"^[[56;192R^[[56;192R[  OK  ] Finished Initial Setup."
        assert display.scrub_space(line) == b"[  OK  ] Finished Initial Setup."
        assert display.scrub_space(b"^[[8;25;94t^[[25;94Rplain tail") == b"plain tail"


class TestScrubCarriageReturns:
    def test_trailing_cr_dropped(self):
        assert display.scrub_space(b"crlf line\r") == b"crlf line"

    def test_embedded_cr_becomes_newline(self):
        assert display.scrub_space(b"redraw1\rredraw2") == b"redraw1\nredraw2"

    def test_superseded_progress_frames_dropped_final_kept(self):
        burst = (b"pkg-a  1.0 MiB [###---------]  25%\r"
                 b"pkg-a  2.0 MiB [######------]  50%\r"
                 b"pkg-a  4.0 MiB [############] 100%")
        assert display.scrub_space(burst) == b"pkg-a  4.0 MiB [############] 100%"

    def test_hundred_percent_frame_never_dropped(self):
        # the frame pattern is 1-2 digits: a 100% line survives even when
        # another frame follows it
        burst = b"done [##########] 100%\rtail"
        assert display.scrub_space(burst) == b"done [##########] 100%\ntail"

    def test_plain_lines_untouched(self):
        assert display.scrub_space(b"plain line stays") == b"plain line stays"


class TestScrubberStreaming:
    SAMPLE = (b"pkg-a downloading...\r"
              b"pkg-a  1.0 MiB [###---------]  25%\r"
              b"pkg-a  4.0 MiB [############] 100%\n"
              b"\x1b[32mplain line stays\x1b[0m\n"
              b"(3/5) checking keys [####------]  40%\r"
              b"(5/5) checking keys [##########] 100%\n")
    EXPECT = (b"pkg-a downloading...\n"
              b"pkg-a  4.0 MiB [############] 100%\n"
              b"plain line stays\n"
              b"(5/5) checking keys [##########] 100%\n")

    def test_whole_stream(self):
        assert scrub_all(self.SAMPLE) == self.EXPECT

    def test_chunk_boundaries_do_not_change_output(self):
        # the sed cycle is the input newline; chunk splits (even mid-escape,
        # mid-CR-burst) must not alter the result
        for size in (1, 2, 3, 7, 16):
            assert scrub_all(self.SAMPLE, chunk_size=size) == self.EXPECT

    def test_unterminated_tail_flushed_on_close(self):
        assert scrub_all(b"no newline at end") == b"no newline at end\n"

    def test_empty_stream(self):
        assert scrub_all(b"") == b""

    def test_non_utf8_bytes_survive(self):
        # the stream is not guaranteed UTF-8; scrub is byte-faithful outside
        # the escape patterns
        assert scrub_all(b"\xff\xfe raw bytes\n") == b"\xff\xfe raw bytes\n"


class TestParsePhases:
    def test_full_breadcrumb(self):
        assert display.parse_phases("create:done,boot:current,check:pending") == [
            ("create", "done"), ("boot", "current"), ("check", "pending")]

    def test_missing_status_defaults_pending(self):
        assert display.parse_phases("boot") == [("boot", "pending")]

    def test_empty_spec(self):
        assert display.parse_phases("") == []


class TestStepFor:
    def test_longest_prefix_wins(self):
        # "oh-my-zsh custom theme" must map to theme, not omz
        omz = display.step_for("oh-my-zsh")
        theme = display.step_for("oh-my-zsh custom theme installed")
        names = [name for name, _ in display.BOOTSTRAP_STEPS]
        assert names[omz] == "omz"
        assert names[theme] == "theme"

    def test_unmapped_returns_none(self):
        assert display.step_for("Some future say-line") is None

    def test_connect_aliases(self):
        for text in ("Waiting for ssh (up to ~2 min)",
                     "Trust baseline: injecting",
                     "Running repo bootstrap inside the VM"):
            idx = display.step_for(text)
            assert display.BOOTSTRAP_STEPS[idx][0] == "connect"


class TestAnchors:
    def anchor(self, line):
        for pattern, build in display.ANCHORS:
            m = pattern.search(line)
            if m:
                return build(m)
        return None

    def test_makepkg_build(self):
        assert self.anchor("==> Making package: yay 12.0.5-1") == "building yay"

    def test_harness_markers(self):
        assert self.anchor("HARNESS-CLOUDINIT-UP") == "live ISO up (cloud-init)"
        assert self.anchor("HARNESS-ARCHINSTALL-EXIT:0") == "archinstall exited rc=0"

    def test_pacman_transactions(self):
        assert self.anchor(":: Retrieving packages...") == "downloading packages"
        assert self.anchor(":: Processing package changes...") == "installing packages"

    def test_say_line_fallback(self):
        assert self.anchor("==> Pacman mirrors") == "Pacman mirrors"


class TestRenderFallback:
    def test_plain_renderers_without_rich(self, monkeypatch):
        # `from rich.console import Console` must raise so make_render takes
        # the unstyled branch; a None sys.modules entry does exactly that
        monkeypatch.setitem(sys.modules, "rich.console", None)
        row1, row2, row3 = display.make_render()
        line = row1("*", [("boot", "done"), ("check", "current")], "", "01:23", 80)
        assert "boot" in line and "CHECK" in line and "01:23" in line
        assert "\x1b[" not in line  # unstyled: no ANSI
        strip = row2(0, 400)
        assert display.BOOTSTRAP_STEPS[0][0].upper() in strip
        assert row3("building yay", 80).strip() == "building yay"

    def test_narrow_terminal_degrades_to_dot_meter(self, monkeypatch):
        monkeypatch.setitem(sys.modules, "rich.console", None)
        _, row2, _ = display.make_render()
        n = len(display.BOOTSTRAP_STEPS)
        line = row2(4, 40)
        assert f"5/{n}" in line
        assert "▶" in line


class TestLogLegFailure:
    """A --log the tool cannot write is lost phase output, never a silent
    success: exit 3, one FATAL on stderr, and the pump keeps serving the
    stdout leg (review fix — a dead log leg used to leave the phase reporting
    rc=0 over an empty log). The unopenable-log arm is clitest-covered
    cross-platform; the mid-stream write failure needs /dev/full."""

    @pytest.mark.skipif(not os.path.exists("/dev/full"),
                        reason="needs /dev/full (Linux)")
    def test_log_write_failure_exits_3_stdout_leg_survives(self):
        p = subprocess.run(
            [sys.executable, TOOL_PATH, "--mode", "plain", "--phase", "p",
             "--log", "/dev/full"],
            input=b"line1\nline2\n", capture_output=True)
        assert p.returncode == 3
        assert p.stderr.count(b"--log write failed") == 1
        assert p.stdout == b"line1\nline2\n"
