"""Host-independent rEFInd policy/reconciler coverage (Story 2.52, #230)."""

import json
import re
from pathlib import Path

from conftest import load_tool

refind = load_tool("refind_config", "refind-config")


def make_fixture(tmp_path: Path, *, machine=True) -> Path:
    root = tmp_path / "root"
    for path in (
        "boot",
        "efi/EFI/refind",
        "efi/EFI/ubuntu",
        "proc",
        "sys/power",
        "usr/share/refind/themes/nord/icons",
        "run/refind-config",
    ):
        (root / path).mkdir(parents=True, exist_ok=True)
    for name in ("vmlinuz-linux", "initramfs-linux.img", "intel-ucode.img"):
        (root / "boot" / name).write_bytes((name + "\n").encode())
    (root / "efi/EFI/refind/refind_x64.efi").write_bytes(b"refind binary\n")
    (root / "efi/EFI/ubuntu/shimx64.efi").write_bytes(b"ubuntu shim\n")
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


def test_check_is_read_only_then_apply_converges_and_preserves_ubuntu(tmp_path, capsys):
    root = make_fixture(tmp_path)
    ubuntu = root / "efi/EFI/ubuntu/shimx64.efi"
    before = ubuntu.read_bytes()

    assert refind.main(["--check", "--root", str(root)]) == 1
    assert "would reconcile" in capsys.readouterr().out
    assert not (root / "efi/EFI/refind/refind.conf").exists()
    assert not (root / "boot/refind_linux.conf").exists()
    assert not (root / "var/backups/dotfiles/refind").exists()

    assert refind.main(["apply", "--root", str(root)]) == 0
    assert refind.main(["--check", "--root", str(root)]) == 0
    assert "converged" in capsys.readouterr().out
    assert ubuntu.read_bytes() == before

    policy = (root / "efi/EFI/refind/refind.conf").read_text()
    machine = (root / "efi/EFI/refind/dotfiles-machine.conf").read_text()
    linux = (root / "boot/refind_linux.conf").read_text()
    assert policy == refind.repo_policy().read_text()
    assert "also_scan_dirs +,@/arch" in machine
    assert "resume=UUID=22222222-2222-2222-2222-222222222222" in linux
    assert "initrd=\\arch\\intel-ucode.img initrd=\\arch\\initramfs-linux.img" in linux
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
    assert (backup / "esp/EFI/refind/dotfiles-machine.conf").read_text() == "old machine\n"
    assert (backup / "boot/refind_linux.conf").read_text() == "old linux\n"
    assert (backup / "esp/EFI/refind/themes/nord/theme.conf").read_text() == "old theme\n"
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
    assert "missing boot artifacts: /boot/initramfs-linux.img" in capsys.readouterr().err
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
    assert "default_selection \"vmlinuz-linux\"" in policy
    assert "include dotfiles-machine.conf" in policy
    assert "include themes/nord/theme.conf" in policy
    assert "dont_scan" not in policy


def test_audit_redacts_identifiers_and_records_boot_paths(tmp_path, capsys):
    root = make_fixture(tmp_path)

    assert refind.main(["audit", "--root", str(root)]) == 0
    output = capsys.readouterr().out
    assert "ESP: /efi; rEFInd binary: present" in output
    assert "firmware current path: rEFInd" in output
    assert "Ubuntu alternate path: firmware-entry=present; shim=present" in output
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
