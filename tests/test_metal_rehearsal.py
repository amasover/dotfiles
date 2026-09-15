"""Terminal framing and destructive artifact boundaries; no QEMU required."""

import fcntl
import json
import os
import threading
import time

import pytest
from conftest import load_tool

rehearsal = load_tool("metal_rehearsal", "metal-rehearsal")


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


def test_failure_before_success_wins_even_when_success_pattern_is_first():
    buffer = rehearsal.PromptBuffer()
    buffer.feed(
        b"metal-provision: install failed: pacstrap failed (rc=1)\r\n"
        b"metal-provision: install complete"
    )
    index, _ = buffer.match(
        [rb"metal-provision: install complete", rb"metal-provision: install failed"]
    )
    assert index == 1


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


def test_failure_prints_the_newest_serial_tail(tmp_path, monkeypatch, capsys):
    root = tmp_path / "artifacts"
    monkeypatch.setattr(rehearsal, "ARTIFACT_ROOT", root)
    run = rehearsal.Rehearsal()
    run.path = owned_run(root)
    (run.path / "installer-serial.log").write_text("stale\n")
    (run.path / "install-serial.log").write_text(
        "".join(f"line {n}\n" for n in range(60))
    )
    os.utime(run.path / "installer-serial.log", (1, 1))
    run.finish(False)
    err = capsys.readouterr().err
    assert "install-serial.log" in err
    assert "line 59" in err
    assert "line 19" not in err
    assert "stale" not in err


def test_failure_before_the_guest_launches_names_the_absent_serial_channel(
    tmp_path, monkeypatch, capsys
):
    root = tmp_path / "artifacts"
    monkeypatch.setattr(rehearsal, "ARTIFACT_ROOT", root)
    run = rehearsal.Rehearsal()
    run.path = owned_run(root)
    run.finish(False)
    assert "no serial output captured" in capsys.readouterr().err


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
