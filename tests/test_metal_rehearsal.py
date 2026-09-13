"""Terminal framing and destructive artifact boundaries; no QEMU required."""

import fcntl
import json
import os
import pty
import subprocess
import sys
import threading
import time
from pathlib import Path

import pytest
from conftest import load_tool

rehearsal = load_tool("metal_rehearsal", "metal-rehearsal")
metal = load_tool("install_on_metal", "install-on-metal")


def test_fragmented_prompts_preserve_following_input():
    buffer = rehearsal.PromptBuffer()
    buffer.feed(b"noise\r\nUser pass")
    assert buffer.match([rb"User password: "]) is None
    buffer.feed(b"word: Confirm user password: ")
    assert buffer.match([rb"User password: "])[0] == 0
    assert buffer.match([rb"Confirm user password: "])[0] == 0
    assert buffer.match([rb"User password: "]) is None


def test_shell_prompt_with_fragmented_ansi_color_and_osc():
    buffer = rehearsal.PromptBuffer()
    buffer.feed(b"\x1b]3008;session=root\x1b")
    buffer.feed(b"\\\x1b[1m\x1b[31mroot\x1b[39")
    assert buffer.match([rb"root@archiso[^\r\n]*# ?"]) is None
    buffer.feed(b"m\x1b[0m\x1b(B@archiso \x1b[1m~ \x1b[0m\x1b(B# ")
    assert buffer.match([rb"root@archiso[^\r\n]*# ?"]) is not None


@pytest.mark.parametrize(
    "disk_bytes,ram_kib,expected",
    [
        (63 * 1073741824, 8 * 1048576, (63, 8)),
        (63 * 1073741824 - 1, 8 * 1048576 + 1, (62, 9)),
    ],
)
def test_live_facts_floor_disk_and_ceil_ram(monkeypatch, disk_bytes, ram_kib, expected):
    monkeypatch.setattr(
        metal.subprocess, "check_output", lambda *a, **k: str(disk_bytes)
    )
    monkeypatch.setattr(metal.Path, "read_text", lambda _: f"MemTotal: {ram_kib} kB\n")
    assert metal.hardware_facts("/dev/vda") == expected


def test_missing_ram_facts_abort_before_recipe_generation(monkeypatch):
    monkeypatch.setattr(
        metal.subprocess, "check_output", lambda *a, **k: str(63 * 1073741824)
    )
    monkeypatch.setattr(metal.Path, "read_text", lambda _: "MemAvailable: 42 kB\n")
    with pytest.raises(ValueError, match="cannot derive"):
        metal.hardware_facts("/dev/vda")


def test_failure_before_success_wins_even_when_success_pattern_is_first():
    buffer = rehearsal.PromptBuffer()
    buffer.feed(b"archinstall failed rc=1\r\nmetal-provision: install complete")
    index, match = buffer.match(
        [rb"metal-provision: install complete", rb"archinstall failed rc=(\d+)"]
    )
    assert index == 1
    assert match.group(1) == b"1"


def test_expect_reads_split_terminal_output_and_captures_exit_status(tmp_path):
    reader, writer = os.pipe()

    def produce():
        os.write(writer, b"download progress\r\nRC-example=")
        time.sleep(0.01)
        os.write(writer, b"17\r\n")
        os.close(writer)

    thread = threading.Thread(target=produce)
    thread.start()
    try:
        with (tmp_path / "serial.log").open("wb") as log:
            terminal = rehearsal.Expect(reader, lambda: time.monotonic() + 1, log)
            _, match = terminal.expect(rb"RC-example=(\d+)\r?\n")
            assert match.group(1) == b"17"
        assert b"download progress" in (tmp_path / "serial.log").read_bytes()
    finally:
        os.close(reader)
        thread.join()


def test_expect_eof_is_not_success():
    reader, writer = os.pipe()
    os.close(writer)
    try:
        with pytest.raises(rehearsal.RehearsalError, match="terminal closed"):
            rehearsal.Expect(reader, lambda: time.monotonic() + 1).expect(rb"complete")
    finally:
        os.close(reader)


def test_stage_deadline_bounds_prompt_timeout():
    reader, writer = os.pipe()
    try:
        with pytest.raises(rehearsal.RehearsalError, match="timeout"):
            rehearsal.Expect(reader, lambda: time.monotonic() - 1).expect(
                rb"complete", timeout=120
            )
    finally:
        os.close(reader)
        os.close(writer)


def test_real_attended_credentials_accept_terminal_answers_without_echo(tmp_path):
    master, slave = pty.openpty()
    credentials = tmp_path / "credentials.json"
    process = subprocess.Popen(
        [
            sys.executable,
            "-c",
            (
                "import fcntl, os, sys, termios; "
                "fcntl.ioctl(0, termios.TIOCSCTTY, 0); os.execvp(sys.argv[1], sys.argv[1:])"
            ),
            sys.executable,
            str(Path(rehearsal.__file__).with_name("provision-seed")),
            "metal-credentials",
            "--out",
            str(credentials),
            "--user",
            "aaron",
        ],
        stdin=slave,
        stdout=slave,
        stderr=slave,
        start_new_session=True,
    )
    os.close(slave)
    try:
        with (tmp_path / "terminal.log").open("wb") as log:
            terminal = rehearsal.Expect(master, lambda: time.monotonic() + 5, log)
            for prompt, answer in (
                (rb"User password: ", "test-user-secret"),
                (rb"Confirm user password: ", "test-user-secret"),
                (rb"Disk encryption password: ", "test-disk-secret"),
                (rb"Confirm disk encryption password: ", "test-disk-secret"),
            ):
                terminal.expect(prompt)
                terminal.send(answer + "\n")
            assert process.wait(timeout=5) == 0
        assert (
            json.loads(credentials.read_text())["encryption_password"]
            == "test-disk-secret"
        )
        assert b"test-user-secret" not in (tmp_path / "terminal.log").read_bytes()
        assert b"test-disk-secret" not in (tmp_path / "terminal.log").read_bytes()
    finally:
        if process.poll() is None:
            process.kill()
            process.wait()
        os.close(master)


def owned_run(root):
    path = root / "run"
    path.mkdir(parents=True)
    (path / "run.json").write_text(json.dumps({"tool": "metal-rehearsal"}))
    (path / "disk.qcow2").write_bytes(b"disposable disk")
    return path


def test_destroy_refuses_external_paths_symlinks_and_active_runs(tmp_path, monkeypatch):
    root = tmp_path / "artifacts"
    monkeypatch.setattr(rehearsal, "ARTIFACT_ROOT", root)
    outside = owned_run(tmp_path / "outside")
    with pytest.raises(rehearsal.RehearsalError, match="not a rehearsal"):
        rehearsal.destroy(outside)
    path = owned_run(root)
    link = root / "link"
    link.symlink_to(outside, target_is_directory=True)
    with pytest.raises(rehearsal.RehearsalError, match="not a rehearsal"):
        rehearsal.destroy(link)
    with (path / "run.json").open() as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        with pytest.raises(rehearsal.RehearsalError, match="still running"):
            rehearsal.destroy(path)
    assert (path / "disk.qcow2").is_file()
    rehearsal.destroy(path)
    assert not path.exists()
    assert (outside / "disk.qcow2").is_file()


@pytest.mark.parametrize(
    "passed,keep,retained",
    [(False, False, True), (True, False, False), (True, True, True)],
)
def test_finish_retains_recoverable_disk_only_when_required(
    tmp_path, monkeypatch, passed, keep, retained
):
    root = tmp_path / "artifacts"
    monkeypatch.setattr(rehearsal, "ARTIFACT_ROOT", root)
    run = rehearsal.Rehearsal(keep)
    run.path = owned_run(root)
    run.finish(passed)
    assert run.path.exists() == retained
    if retained:
        credentials = run.path / "credentials.json"
        assert credentials.stat().st_mode & 0o777 == 0o600
        assert json.loads(credentials.read_text())["luks_password"] == run.luks_password


def test_install_failure_stops_before_boot_and_reports_stage(
    tmp_path, monkeypatch, capsys
):
    monkeypatch.setattr(rehearsal, "ARTIFACT_ROOT", tmp_path)
    run = rehearsal.Rehearsal()
    executed = []

    def fail_install():
        raise rehearsal.RehearsalError("installer refused disk")

    for stage, _ in rehearsal.STAGES:
        monkeypatch.setattr(
            run, stage.replace("-", "_"), lambda stage=stage: executed.append(stage)
        )
    monkeypatch.setattr(run, "install", fail_install)
    assert run.run() == 1
    assert executed == ["host-preflight", "prepare", "installer-boot"]
    assert "FAIL stage=install: installer refused disk" in capsys.readouterr().err
