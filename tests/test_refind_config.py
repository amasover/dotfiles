"""Host-independent rEFInd policy/reconciler coverage (Story 2.52, #230)."""

import base64
import json
import re
import subprocess
import sys
from pathlib import Path

import pytest
from conftest import load_tool

refind = load_tool("refind_config", "refind-config")


def make_fixture(tmp_path: Path, *, machine=True) -> Path:
    root = tmp_path / "root"
    for path in (
        "boot",
        "efi/EFI/refind",
        "efi/EFI/ubuntu",
        "efi/EFI/BOOT",
        "etc",
        "proc",
        "sys/power",
        "usr/share/refind/themes/nord/icons",
        "run/refind-config",
    ):
        (root / path).mkdir(parents=True, exist_ok=True)
    for name in ("vmlinuz-linux", "initramfs-linux.img", "intel-ucode.img"):
        (root / "boot" / name).write_bytes((name + "\n").encode())
    (root / "efi/EFI/refind/refind_x64.efi").write_bytes(b"refind binary\n")
    (root / "etc/os-release").write_text("ID=arch\n")
    (root / "efi/EFI/ubuntu/shimx64.efi").write_bytes(b"ubuntu shim\n")
    (root / "efi/EFI/ubuntu/mmx64.efi").write_bytes(b"ubuntu mok manager\n")
    (root / "efi/EFI/BOOT/BOOTX64.EFI").write_bytes(b"microsoft fallback\n")
    (root / "proc/cmdline").write_text(
        "cryptdevice=UUID=11111111-1111-1111-1111-111111111111:cryptroot "
        "root=/dev/mapper/vg-root rw quiet initrd=\\arch\\initramfs-linux.img\n"
    )
    (root / "sys/power/resume").write_text("0:0\n")
    (root / "sys/power/resume_offset").write_text("0\n")
    source = root / "usr/share/refind/themes/nord"
    for name in ("theme.conf", "bg.png", "selection_big.png", "selection_small.png"):
        (source / name).write_bytes(("theme " + name + "\n").encode())
    (source / "icons/os_arch.png").write_bytes(b"arch icon\n")
    (source / "icons/os_ubuntu.png").write_bytes(b"ubuntu icon\n")
    (root / "run/refind-config/efibootmgr.txt").write_text(
        "BootCurrent: 0005\n"
        "Boot0003* ubuntu HD(...)\\EFI\\ubuntu\\shimx64.efi\n"
        "Boot0005* rEFInd Boot Manager HD(...)\\EFI\\refind\\refind_x64.efi\n"
    )
    if machine:
        config = {
            "esp": "/efi",
            "boot_fsroot": "/arch",
            "kernel_options": [
                "cryptdevice=UUID=11111111-1111-1111-1111-111111111111:cryptroot",
                "root=/dev/mapper/vg-root",
                "resume=UUID=22222222-2222-2222-2222-222222222222",
            ],
        }
        path = root / "etc/dotfiles/refind.json"
        path.parent.mkdir(parents=True)
        path.write_text(json.dumps(config))
    return root


def non_refind_esp_snapshot(root: Path) -> dict[str, bytes]:
    esp = root / "efi"
    return {
        path.relative_to(esp).as_posix(): path.read_bytes()
        for path in esp.rglob("*")
        if path.is_file() and not path.is_relative_to(esp / "EFI/refind")
    }


def test_check_is_read_only_then_apply_converges_and_preserves_ubuntu(tmp_path, capsys):
    root = make_fixture(tmp_path)
    before = non_refind_esp_snapshot(root)

    assert refind.main(["--check", "--root", str(root)]) == 1
    assert "would reconcile" in capsys.readouterr().out
    assert not (root / "efi/EFI/refind/refind.conf").exists()
    assert not (root / "boot/refind_linux.conf").exists()
    assert not (root / "var/backups/dotfiles/refind").exists()

    assert refind.main(["apply", "--root", str(root)]) == 0
    assert refind.main(["--check", "--root", str(root)]) == 0
    assert "converged" in capsys.readouterr().out
    assert non_refind_esp_snapshot(root) == before

    policy = (root / "efi/EFI/refind/refind.conf").read_text()
    machine = (root / "efi/EFI/refind/dotfiles-machine.conf").read_text()
    linux = (root / "boot/refind_linux.conf").read_text()
    assert policy == refind.repo_policy().read_text()
    assert "also_scan_dirs +,@/arch" in machine
    assert "resume=UUID=22222222-2222-2222-2222-222222222222" in linux
    assert "initrd=\\arch\\intel-ucode.img initrd=\\arch\\initramfs-%v.img" in linux
    assert "quiet" not in linux
    assert (root / "efi/EFI/refind/themes/nord/.dotfiles-refind-managed").is_file()
    assert not list(root.rglob(".refind-config-*"))
    assert not list(root.rglob(".nord-*-*"))


def test_unmanaged_destination_fails_before_any_write(tmp_path, capsys):
    root = make_fixture(tmp_path)
    config = root / "efi/EFI/refind/refind.conf"
    config.write_text("owner=someone-else\n")

    assert refind.main(["apply", "--root", str(root)]) == 2
    assert "unmanaged destination: refind.conf" in capsys.readouterr().err
    assert config.read_text() == "owner=someone-else\n"
    assert not (root / "boot/refind_linux.conf").exists()
    assert not (root / "efi/EFI/refind/dotfiles-machine.conf").exists()
    assert not (root / "var/backups/dotfiles/refind").exists()


def test_adopt_backs_up_every_existing_destination_outside_esp(tmp_path, capsys):
    root = make_fixture(tmp_path)
    refind_dir = root / "efi/EFI/refind"
    (refind_dir / "refind.conf").write_text("old refind\n")
    (refind_dir / "dotfiles-machine.conf").write_text("old machine\n")
    (root / "boot/refind_linux.conf").write_text("old linux\n")
    theme = refind_dir / "themes/nord"
    theme.mkdir(parents=True)
    (theme / "theme.conf").write_text("old theme\n")

    assert refind.main(["adopt", "--root", str(root)]) == 0
    output = capsys.readouterr().out
    assert "backup /var/backups/dotfiles/refind/" in output
    backups = list((root / "var/backups/dotfiles/refind").iterdir())
    assert len(backups) == 1
    backup = backups[0]
    assert (backup / "esp/EFI/refind/refind.conf").read_text() == "old refind\n"
    assert (
        backup / "esp/EFI/refind/dotfiles-machine.conf"
    ).read_text() == "old machine\n"
    assert (backup / "boot/refind_linux.conf").read_text() == "old linux\n"
    assert (
        backup / "esp/EFI/refind/themes/nord/theme.conf"
    ).read_text() == "old theme\n"
    assert backup.is_relative_to(root / "var")
    assert not backup.is_relative_to(root / "efi")


def test_ambiguous_esps_fail_closed(tmp_path, capsys):
    root = make_fixture(tmp_path, machine=False)
    other = root / "boot/efi/EFI/refind"
    other.mkdir(parents=True)
    (other / "refind_x64.efi").write_bytes(b"other refind\n")

    assert refind.main(["--check", "--root", str(root)]) == 2
    error = capsys.readouterr().err
    assert "ambiguous ESPs" in error
    assert "/efi, /boot/efi" in error


def test_missing_boot_artifact_fails_closed(tmp_path, capsys):
    root = make_fixture(tmp_path)
    (root / "boot/initramfs-linux.img").unlink()

    assert refind.main(["--check", "--root", str(root)]) == 2
    assert (
        "missing boot artifacts: /boot/initramfs-linux.img" in capsys.readouterr().err
    )
    assert not (root / "efi/EFI/refind/refind.conf").exists()


def test_live_cmdline_keeps_only_identity_options():
    options = refind.kernel_identity_from_cmdline(
        "BOOT_IMAGE=/vmlinuz cryptdevice=UUID=aaaa:cryptroot root=/dev/vg/root "
        "rd.lvm.lv=vg/root resume=UUID=bbbb rw quiet splash initrd=\\initramfs.img"
    )
    assert options == [
        "cryptdevice=UUID=aaaa:cryptroot",
        "root=/dev/vg/root",
        "rd.lvm.lv=vg/root",
        "resume=UUID=bbbb",
    ]


def test_policy_is_portable_and_keeps_dual_boot_scanning():
    policy = refind.repo_policy().read_text()
    assert not re.search(r"(?:PART)?UUID=|/dev/", policy)
    assert "scanfor internal,external,optical,manual" in policy
    assert 'default_selection "vmlinuz-linux"' in policy
    assert (
        f'extra_kernel_version_strings "{",".join(refind.KERNEL_VERSION_STRINGS)}"'
        in policy
    )
    assert "include dotfiles-machine.conf" in policy
    assert "include themes/nord/theme.conf" in policy
    assert "dont_scan" not in policy


def test_audit_redacts_identifiers_and_records_boot_paths(tmp_path, capsys):
    root = make_fixture(tmp_path)

    assert refind.main(["audit", "--root", str(root)]) == 0
    output = capsys.readouterr().out
    assert "ESP: /efi; mount=fixture; rEFInd binary: present" in output
    assert "firmware rEFInd entry: present; current path=rEFInd" in output
    assert (
        "Ubuntu alternate path: firmware-entry=present; shim=present; mok-manager=present; fallback=present"
        in output
    )
    assert "Nord source owner: fixture; installed: no" in output
    assert "filesystem root: /arch" in output
    assert "root=yes; crypt=yes; resume=yes; values redacted" in output
    assert "11111111-1111-1111-1111-111111111111" not in output
    assert "22222222-2222-2222-2222-222222222222" not in output


def test_invalid_machine_options_fail_without_echoing_values(tmp_path, capsys):
    root = make_fixture(tmp_path)
    path = root / "etc/dotfiles/refind.json"
    path.write_text(json.dumps({"kernel_options": ["root=/dev/root", "quiet"]}))

    assert refind.main(["--check", "--root", str(root)]) == 2
    error = capsys.readouterr().err
    assert "unsupported identity option key: quiet" in error
    assert "/dev/root" not in error


def test_boot_fsroot_keeps_path_below_containing_mount():
    assert refind.filesystem_path("/", "/", "/boot") == "/boot"
    assert refind.filesystem_path("/boot", "/arch", "/boot") == "/arch"
    assert (
        refind.filesystem_path("/", "/root-subvolume", "/boot")
        == "/root-subvolume/boot"
    )
    with pytest.raises(refind.RefindError, match="unsupported characters"):
        refind.validate_boot_fsroot('/arch" injected')


def test_esp_mount_must_be_exact_fat_and_writable():
    valid = {
        "target": "/efi",
        "source": "/dev/example",
        "fstype": "vfat",
        "options": "rw,nodev",
    }
    refind.validate_esp_mount("/efi", valid, writable=True)
    with pytest.raises(refind.RefindError, match="not an active mount"):
        refind.validate_esp_mount("/efi", valid | {"target": "/"}, writable=False)
    with pytest.raises(refind.RefindError, match="not FAT"):
        refind.validate_esp_mount("/efi", valid | {"fstype": "ext4"}, writable=False)
    with pytest.raises(refind.RefindError, match="not writable"):
        refind.validate_esp_mount(
            "/efi", valid | {"options": "ro,nodev"}, writable=True
        )


def test_target_root_requires_explicit_boot_identity(tmp_path, capsys):
    root = make_fixture(tmp_path, machine=False)

    assert refind.main(["--check", "--root", str(root)]) == 2
    assert "target root must provide boot_fsroot" in capsys.readouterr().err


def test_non_arch_target_fails_before_writes(tmp_path, capsys):
    root = make_fixture(tmp_path)
    (root / "etc/os-release").write_text("ID=ubuntu\n")

    assert refind.main(["apply", "--root", str(root)]) == 2
    assert "not an Arch installation" in capsys.readouterr().err
    assert not (root / "efi/EFI/refind/refind.conf").exists()


def test_matching_unmanaged_theme_still_requires_adopt(tmp_path, capsys):
    root = make_fixture(tmp_path)
    source = root / "usr/share/refind/themes/nord"
    destination = root / "efi/EFI/refind/themes/nord"
    destination.parent.mkdir(parents=True)
    destination.mkdir()
    for path in source.rglob("*"):
        if path.is_dir():
            continue
        target = destination / path.relative_to(source)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(path.read_bytes())

    assert refind.main(["apply", "--root", str(root)]) == 2
    assert "unmanaged destination: Nord theme" in capsys.readouterr().err
    assert not (destination / refind.THEME_MARKER).exists()


def test_symlinked_destination_fails_closed(tmp_path, capsys):
    root = make_fixture(tmp_path)
    target = root / "elsewhere"
    target.write_text("outside\n")
    destination = root / "boot/refind_linux.conf"
    destination.symlink_to(target)

    assert refind.main(["adopt", "--root", str(root)]) == 2
    assert "contains a symlink" in capsys.readouterr().err
    assert destination.is_symlink()
    assert target.read_text() == "outside\n"


def test_all_advertised_kernels_use_matching_initramfs_template(tmp_path, capsys):
    root = make_fixture(tmp_path)
    (root / "boot/vmlinuz-linux-lts").write_bytes(b"lts kernel\n")
    (root / "boot/initramfs-linux-lts.img").write_bytes(b"lts initramfs\n")

    assert refind.main(["apply", "--root", str(root)]) == 0
    linux = (root / "boot/refind_linux.conf").read_text()
    assert "initramfs-%v.img" in linux

    (root / "boot/initramfs-linux-lts.img").unlink()
    assert refind.main(["--check", "--root", str(root)]) == 2
    assert (
        "missing boot artifacts: /boot/initramfs-linux-lts.img"
        in capsys.readouterr().err
    )


def test_failed_multi_file_apply_rolls_back_and_reports_backup(
    tmp_path, capsys, monkeypatch
):
    root = make_fixture(tmp_path)
    assert refind.main(["apply", "--root", str(root)]) == 0
    before_machine = (root / "efi/EFI/refind/dotfiles-machine.conf").read_bytes()
    before_linux = (root / "boot/refind_linux.conf").read_bytes()
    machine_path = root / "etc/dotfiles/refind.json"
    machine = json.loads(machine_path.read_text())
    machine["boot_fsroot"] = "/new-arch"
    machine_path.write_text(json.dumps(machine))

    original = refind.atomic_write
    failed = False

    def fail_once(path, content, mode=0o644):
        nonlocal failed
        if path.name == "refind_linux.conf" and not failed:
            failed = True
            raise OSError("injected write failure")
        return original(path, content, mode)

    monkeypatch.setattr(refind, "atomic_write", fail_once)
    assert refind.main(["apply", "--root", str(root)]) == 2
    captured = capsys.readouterr()
    assert "backup /var/backups/dotfiles/refind/" in captured.out
    assert "apply failed; restored from" in captured.err
    assert (
        root / "efi/EFI/refind/dotfiles-machine.conf"
    ).read_bytes() == before_machine
    assert (root / "boot/refind_linux.conf").read_bytes() == before_linux


def test_elevation_snapshots_script_and_policy_before_dialog(monkeypatch, capsys):
    observed = {}

    def run(command, **kwargs):
        observed["command"] = command
        observed.update(kwargs)
        return subprocess.CompletedProcess(command, 7)

    monkeypatch.setattr(refind.subprocess, "run", run)
    assert refind.elevate(["--check"]) == 7
    assert observed["command"][:3] == ["/usr/bin/pkexec", "/usr/bin/python3", "-c"]
    assert observed["command"][3].startswith("#!/usr/bin/env python3\n")
    assert "--policy-data" in observed["command"]
    assert "requesting authorization in a polkit dialog" in capsys.readouterr().err


def test_active_firmware_entry_must_match_esp_partition(monkeypatch):
    firmware = (
        "BootCurrent: 0005\n"
        "Boot0005* rEFInd HD(2,GPT,aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee,0x800,0x1000)"
        "\\EFI\\refind\\refind_x64.efi\n"
    )
    monkeypatch.setattr(refind, "firmware_text", lambda _root: firmware)
    monkeypatch.setattr(
        refind.subprocess,
        "run",
        lambda command, **_kwargs: subprocess.CompletedProcess(
            command, 0, "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee\n", ""
        ),
    )
    mount = {
        "source": "/dev/example",
        "target": "/efi",
        "fstype": "vfat",
        "options": "rw",
    }
    refind.verify_active_refind_esp(Path("/"), mount)

    monkeypatch.setattr(
        refind.subprocess,
        "run",
        lambda command, **_kwargs: subprocess.CompletedProcess(
            command, 0, "ffffffff-bbbb-cccc-dddd-eeeeeeeeeeee\n", ""
        ),
    )
    with pytest.raises(
        refind.RefindError, match="does not use the selected ESP partition"
    ):
        refind.verify_active_refind_esp(Path("/"), mount)


def test_privileged_snapshot_executes_without_reopening_checkout(tmp_path):
    root = make_fixture(tmp_path)
    policy = base64.b64encode(refind.repo_policy().read_bytes()).decode("ascii")
    command = [
        sys.executable,
        "-c",
        Path(refind.__file__).read_text(),
        "--check",
        "--root",
        str(root),
        "--elevated",
        "--policy-data",
        policy,
    ]
    completed = subprocess.run(command, capture_output=True, check=False)
    assert completed.returncode == 1
    assert b"would reconcile" in completed.stdout
