"""Provisioning-seed tests (Stories 2.29 and 2.36).

No VMware, libvirt, block-device mutation, or network access.
"""

import base64
import io
import json
import subprocess

import pytest
from conftest import load_tool

seed = load_tool("provision_seed", "provision-seed")
refind = load_tool("refind_config_for_seed", "refind-config")


def make_request(target="vmware", **overrides):
    values = {
        "target": target,
        "disk_size_gib": 80,
        "hostname": "archvm",
        "user": "aaron",
        "pubkey": "ssh-ed25519 AAAA test",
    }
    if target == "metal":
        values.update(
            disk_size_gib=256,
            disk_device="/dev/nvme0n1",
            ram_gib=32,
        )
    values.update(overrides)
    return seed.build_request(**values)


class TestSha512Crypt:
    # Published test vectors from Ulrich Drepper's sha-crypt specification.
    def test_spec_vector_default_rounds(self):
        assert seed.sha512_crypt("Hello world!", "saltstring") == (
            "$6$saltstring$svn8UoSVapNtMuq1ukKS4tPQd8iKwSMHWjl/O817G3uBnIFNjnQJue"
            "sI68u4OTLiBFdcbYEdFCoEOfaS35inz1"
        )

    def test_spec_vector_explicit_rounds(self):
        assert seed.sha512_crypt("Hello world!", "saltstringsaltst", rounds=10000) == (
            "$6$rounds=10000$saltstringsaltst$OW1/O6BYHV6BcXZu8QVeXbDWra3Oeqh0sbH"
            "bbMCVNSnCM/UrjmM0Dp8vOuZeHBy/YTBmSK6H9qs/y3RnOaw5v."
        )

    def test_random_salt_shape(self):
        h = seed.sha512_crypt("pw")
        assert h.startswith("$6$")
        salt = h.split("$")[2]
        assert 1 <= len(salt) <= 16

    def test_oversized_salt_rejected(self):
        with pytest.raises(ValueError):
            seed.sha512_crypt("pw", "x" * 17)


class TestLayoutSizing:
    def test_vm_root_fills_disk_minus_esp_and_slack(self):
        assert seed.root_gib(80) == 78

    def test_vm_disk_too_small_dies(self):
        with pytest.raises(ValueError):
            seed.root_gib(21)

    def test_metal_layout_reserves_resume_and_routine_headroom(self):
        root, resume, routine = seed.metal_layout_gib(256, 32)
        assert (root, resume, routine) == (222, 32, 48)
        assert root - routine == 174

    def test_metal_layout_refuses_insufficient_post_swap_root(self):
        with pytest.raises(ValueError, match="needs >= 123G"):
            seed.metal_layout_gib(122, 32)

    @pytest.mark.parametrize("ram_gib", [0, -1])
    def test_metal_layout_refuses_invalid_ram(self, ram_gib):
        with pytest.raises(ValueError, match="RAM"):
            seed.metal_layout_gib(256, ram_gib)


class TestUserConfiguration:
    def _cfg(self, target, **kw):
        return seed.build_user_configuration(make_request(target, **kw))

    def test_qemu_device_and_tools(self):
        cfg = self._cfg("qemu")
        assert cfg["disk_config"]["device_modifications"][0]["device"] == "/dev/vda"
        assert "qemu-guest-agent" in cfg["packages"]
        assert "open-vm-tools" not in cfg["packages"]

    def test_vmware_device_and_tools(self):
        cfg = self._cfg("vmware")
        assert cfg["disk_config"]["device_modifications"][0]["device"] == "/dev/nvme0n1"
        assert "open-vm-tools" in cfg["packages"]
        assert "qemu-guest-agent" not in cfg["packages"]

    @pytest.mark.parametrize("target", ["qemu", "vmware"])
    def test_networkmanager_owns_networking_from_first_boot(self, target):
        assert self._cfg(target)["network_config"] == {"type": "nm"}

    @pytest.mark.parametrize("target", ["qemu", "vmware"])
    def test_disposable_harness_targets_remain_unencrypted(self, target):
        assert "disk_encryption" not in self._cfg(target)["disk_config"]

    def test_vm_root_partition_sized_from_disk(self):
        parts = self._cfg("vmware")["disk_config"]["device_modifications"][0][
            "partitions"
        ]
        root = next(p for p in parts if p["mountpoint"] == "/")
        assert root["size"] == {
            "unit": "GiB",
            "value": 78,
            "sector_size": {"value": 512, "unit": "B"},
        }

    def test_daily_vm_encrypts_root_without_harness_sudo_policy(self):
        cfg = self._cfg("daily-vm")
        disk = cfg["disk_config"]
        root = next(
            partition
            for partition in disk["device_modifications"][0]["partitions"]
            if partition["mountpoint"] == "/"
        )
        assert disk["disk_encryption"] == {
            "encryption_type": "luks",
            "partitions": [root["obj_id"]],
            "lvm_volumes": [],
        }
        assert "open-vm-tools" in cfg["packages"]
        assert "vmtoolsd.service" in "\n".join(cfg["custom_commands"])
        assert "NOPASSWD" not in "\n".join(cfg["custom_commands"])

    def test_metal_uses_lvm_on_luks_with_dedicated_resume(self):
        cfg = self._cfg(
            "metal",
            disk_size_gib=256,
            ram_gib=32,
            disk_device="/dev/nvme0n1",
        )
        disk = cfg["disk_config"]
        parts = disk["device_modifications"][0]["partitions"]
        assert cfg["bootloader_config"]["bootloader"] == "Refind"
        assert cfg["swap"]["enabled"] is False
        assert disk["disk_encryption"] == {
            "encryption_type": "lvm_on_luks",
            "partitions": [parts[1]["obj_id"]],
            "lvm_volumes": [],
        }
        volumes = disk["lvm_config"]["vol_groups"][0]["volumes"]
        assert [
            (v["name"], v["fs_type"], v["length"]["value"], v["mountpoint"])
            for v in volumes
        ] == [
            ("root", "ext4", 222, "/"),
            ("resume", "linux-swap", 32, None),
        ]
        assert "swapon" not in "\n".join(cfg["custom_commands"])
        assert "open-vm-tools" not in cfg["packages"]
        assert "qemu-guest-agent" not in cfg["packages"]

    def test_metal_requires_device_and_ram(self):
        base = {
            "target": "metal",
            "disk_size_gib": 256,
            "hostname": "fresh-laptop",
            "user": "aaron",
            "pubkey": "",
        }
        with pytest.raises(ValueError, match="disk device"):
            seed.build_request(**base, ram_gib=32)
        with pytest.raises(ValueError, match="RAM"):
            seed.build_request(**base, disk_device="/dev/nvme0n1")

    def test_pubkey_lands_in_authorized_keys_command(self):
        cmds = "\n".join(self._cfg("vmware")["custom_commands"])
        assert "authorized_keys" in cmds and "ssh-ed25519 AAAA test" in cmds

    def test_no_pubkey_no_authorized_keys_command(self):
        cmds = "\n".join(self._cfg("vmware", pubkey="")["custom_commands"])
        assert "authorized_keys" not in cmds

    def test_metal_never_installs_harness_sudo_policy(self):
        cmds = "\n".join(
            self._cfg(
                "metal",
                disk_size_gib=256,
                ram_gib=32,
                disk_device="/dev/nvme0n1",
            )["custom_commands"]
        )
        assert "NOPASSWD" not in cmds
        assert "serial-getty" not in cmds

    def test_vmware_enables_vmtoolsd(self):
        cmds = "\n".join(self._cfg("vmware")["custom_commands"])
        assert "systemctl enable vmtoolsd.service" in cmds

    def test_qemu_enables_no_tools_service(self):
        cmds = "\n".join(self._cfg("qemu")["custom_commands"])
        assert "vmtoolsd" not in cmds


class TestUserData:
    def _ud(self, target="vmware", live_ssh_pubkey=None):
        request = make_request(target)
        cfg = seed.build_user_configuration(request)
        creds = (
            None
            if request.target.attended
            else seed.build_user_credentials(
                user="aaron",
                pass_hash="$6$s$h",
                luks_secret="disk secret" if request.target.encrypted else None,
            )
        )
        return seed.build_user_data(
            request=request,
            user_configuration=cfg,
            user_credentials=creds,
            live_ssh_pubkey=live_ssh_pubkey,
            run_install_sh=seed.build_run_install(request),
            provision_tool=(
                b"#!/usr/bin/env python3\n" if request.target.attended else None
            ),
        )

    def test_embedded_config_roundtrips(self):
        ud = self._ud()
        b64 = next(
            line.split(": ", 1)[1]
            for line in ud.splitlines()
            if line.strip().startswith("content: ")
        )
        cfg = json.loads(base64.b64decode(b64))
        assert cfg["hostname"] == "archvm"

    def test_vm_install_driver_is_transient_unit(self):
        assert "[systemd-run, --collect, --unit=harness-install" in self._ud()

    def test_live_ssh_adds_key_and_sshd_start(self):
        ud = self._ud(live_ssh_pubkey="ssh-ed25519 AAAA test")
        assert "ssh_authorized_keys:" in ud
        assert "[systemctl, start, sshd]" in ud

    def test_no_live_ssh_no_sshd_in_live_iso(self):
        ud = self._ud()
        assert "ssh_authorized_keys:" not in ud
        assert "systemctl, start, sshd" not in ud

    def test_metal_seed_contains_no_credentials_and_never_autostarts(self):
        ud = self._ud("metal")
        assert "/root/user_credentials.json" not in ud
        assert "harness-install" not in ud
        assert "/root/provision-seed" in ud
        assert "Run /root/run-install.sh from a target-laptop console" in ud


class TestSeedIso:
    def test_iso_roundtrip_and_volid(self, tmp_path):
        import pycdlib

        out = tmp_path / "seed.iso"
        seed.write_seed_iso(out, "#cloud-config\nkey: value\n", seed.META_DATA)
        iso = pycdlib.PyCdlib()
        iso.open(str(out))
        assert iso.pvd.volume_identifier.decode().rstrip() == "CIDATA"
        buf = io.BytesIO()
        iso.get_file_from_iso_fp(buf, joliet_path="/user-data")
        assert buf.getvalue() == b"#cloud-config\nkey: value\n"
        buf = io.BytesIO()
        iso.get_file_from_iso_fp(buf, joliet_path="/meta-data")
        assert buf.getvalue() == seed.META_DATA.encode()
        iso.close()


class TestMetalPreflight:
    def test_accepts_matching_blank_whole_disk(self):
        seed.validate_metal_facts(
            seed.MetalFacts("/dev/nvme0n1", 256, 32),
            actual_disk_bytes=256 * 1073741824 + 4096,
            actual_ram_gib=32,
            is_whole_disk=True,
            is_uefi=True,
            mountpoints=[],
        )

    def test_rejects_non_disk_mismatch_and_mounted_children(self):
        expected = seed.MetalFacts("/dev/nvme0n1", 256, 32)
        common = {
            "actual_disk_bytes": 256 * 1073741824,
            "actual_ram_gib": 32,
            "is_whole_disk": True,
            "is_uefi": True,
            "mountpoints": [],
        }
        with pytest.raises(ValueError, match="whole disk"):
            seed.validate_metal_facts(expected, **(common | {"is_whole_disk": False}))
        with pytest.raises(ValueError, match="size does not match"):
            seed.validate_metal_facts(
                expected,
                **(common | {"actual_disk_bytes": 255 * 1073741824}),
            )
        with pytest.raises(ValueError, match="RAM rounds"):
            seed.validate_metal_facts(expected, **(common | {"actual_ram_gib": 31}))
        with pytest.raises(ValueError, match="mounted"):
            seed.validate_metal_facts(expected, **(common | {"mountpoints": ["/mnt"]}))
        with pytest.raises(ValueError, match="UEFI"):
            seed.validate_metal_facts(expected, **(common | {"is_uefi": False}))

    def test_requires_exact_device_specific_confirmation(self):
        seed.require_wipe_confirmation("/dev/nvme0n1", "WIPE /dev/nvme0n1")
        with pytest.raises(ValueError, match="did not match"):
            seed.require_wipe_confirmation("/dev/nvme0n1", "WIPE /dev/nvme1n1")


class TestMetalCredentials:
    def test_prompts_at_runtime_and_never_prints_secrets(self, tmp_path, capsys):
        answers = iter(["user secret", "user secret", "disk secret", "disk secret"])
        path = tmp_path / "user_credentials.json"

        seed.write_metal_credentials(path, "aaron", lambda _prompt: next(answers))

        payload = json.loads(path.read_text())
        assert payload["encryption_password"] == "disk secret"
        assert payload["users"][0]["enc_password"].startswith("$6$")
        assert "user secret" not in path.read_text()
        assert path.stat().st_mode & 0o777 == 0o600
        assert "secret" not in capsys.readouterr().out

    def test_mismatched_confirmation_writes_nothing(self, tmp_path):
        answers = iter(["first", "different"])
        path = tmp_path / "user_credentials.json"
        with pytest.raises(ValueError, match="does not match"):
            seed.write_metal_credentials(path, "aaron", lambda _prompt: next(answers))
        assert not path.exists()


@pytest.fixture
def metal_target(tmp_path, monkeypatch):
    (tmp_path / "etc").mkdir()
    (tmp_path / "etc/fstab").write_text("/dev/dotfiles/root / ext4 defaults 0 1\n")
    (tmp_path / "etc/mkinitcpio.conf").write_text(
        "HOOKS=(base udev encrypt lvm2 block filesystems fsck)\n"
    )
    # Building an initramfs requires the installed target; exercised in the VM.
    run = subprocess.run

    def target_run(command, **kwargs):
        if command[0] == "arch-chroot":
            return subprocess.CompletedProcess(command, 0)
        return run(command, **kwargs)

    monkeypatch.setattr(seed.subprocess, "run", target_run)
    refind_dir = tmp_path / "boot/EFI/refind"
    refind_dir.mkdir(parents=True)
    (refind_dir / "refind.conf").write_text("timeout 20\n")
    (tmp_path / "boot/refind_linux.conf").write_text(
        '"Arch Linux" "root=/dev/dotfiles/root"\n'
    )
    return tmp_path


class TestMetalResumePersistence:
    def test_resume_runs_after_unlock_before_filesystem_checks(self, metal_target):
        seed.finalize_metal(metal_target)
        seed.finalize_metal(metal_target)
        result = subprocess.run(
            [
                "bash",
                "-c",
                'source "$1"; printf "%s\\n" "${HOOKS[@]}"',
                "bash",
                str(metal_target / "etc/mkinitcpio.conf"),
            ],
            text=True,
            capture_output=True,
            check=True,
        )
        hooks = result.stdout.splitlines()
        assert hooks.count("resume") == 1
        assert hooks.index("encrypt") < hooks.index("lvm2") < hooks.index("resume")
        assert hooks.index("resume") < hooks.index("filesystems") < hooks.index("fsck")

    def test_finalization_persists_one_low_priority_swap_across_retries(
        self, metal_target
    ):
        args = ["metal-finalize", "--root", str(metal_target)]
        seed.main(args)
        seed.main(args)
        result = subprocess.run(
            [
                "findmnt",
                "--fstab",
                "--tab-file",
                str(metal_target / "etc/fstab"),
                "--types",
                "swap",
                "--noheadings",
                "--output",
                "SOURCE,OPTIONS",
            ],
            capture_output=True,
            text=True,
            check=False,
        )
        assert result.returncode == 0
        assert [line.split() for line in result.stdout.splitlines()] == [
            ["/dev/dotfiles/resume", "sw,pri=-1"]
        ]
        assert (
            (metal_target / "etc/fstab")
            .read_text()
            .startswith("/dev/dotfiles/root / ext4 defaults 0 1\n")
        )

    def test_conflicting_swap_refuses_before_marking_boot_files(self, metal_target):
        fstab = metal_target / "etc/fstab"
        original = fstab.read_text() + "/dev/other none swap sw 0 0\n"
        fstab.write_text(original)
        with pytest.raises(SystemExit):
            seed.main(["metal-finalize", "--root", str(metal_target)])
        assert fstab.read_text() == original
        assert (
            metal_target / "boot/EFI/refind/refind.conf"
        ).read_text() == "timeout 20\n"


class TestMetalHandoff:
    def test_handoff_marker_matches_refind_reconciler(self):
        assert seed.REFIND_MANAGED == refind.MANAGED

    def test_marks_archinstall_refind_files_for_first_boot_reconcile(
        self, metal_target
    ):
        refind = metal_target / "boot/EFI/refind/refind.conf"
        linux = metal_target / "boot/refind_linux.conf"

        seed.finalize_metal(metal_target)
        seed.finalize_metal(metal_target)

        for path in (refind, linux):
            assert path.read_text().startswith(seed.REFIND_MANAGED + "\n")
            assert path.read_text().count(seed.REFIND_MANAGED) == 1

    def test_package_theme_copy_is_reconcilable_without_adoption(self, metal_target):
        seed.finalize_metal(metal_target)
        theme = metal_target / "boot/EFI/refind/themes/nord"
        theme.mkdir(parents=True, exist_ok=True)
        (theme / "theme.conf").write_text("package theme\n")
        state = {
            "root": metal_target,
            "files": [],
            "theme_dir": theme,
            "theme": {"theme.conf": b"tracked theme\n"},
        }
        refind.preflight(state, adopt=False)
        assert refind.drift_items(state) == ["Nord theme"]

    def test_existing_unmanaged_theme_is_not_authorized(self, metal_target):
        theme = metal_target / "boot/EFI/refind/themes/nord"
        theme.mkdir(parents=True)
        (theme / "theme.conf").write_text("someone else's theme\n")
        fstab = metal_target / "etc/fstab"
        original = fstab.read_bytes()
        with pytest.raises(ValueError, match="unmanaged Nord theme"):
            seed.finalize_metal(metal_target)
        assert fstab.read_bytes() == original
        assert not (theme / refind.THEME_MARKER).exists()

    def test_refuses_symlinked_refind_destination(self, metal_target):
        refind = metal_target / "boot/EFI/refind/refind.conf"
        refind.unlink()
        (metal_target / "outside").write_text("timeout 20\n")
        refind.symlink_to(metal_target / "outside")
        with pytest.raises(ValueError, match="symlink"):
            seed.finalize_metal(metal_target)


class TestCli:
    def test_generate_writes_seed_set(self, tmp_path, capsys):
        rc = seed.main(
            [
                "create",
                "--out",
                str(tmp_path),
                "--target",
                "vmware",
                "--disk-size",
                "80",
                "--pass-hash",
                "$6$s$h",
                "--pubkey",
                "ssh-ed25519 AAAA test",
                "--live-ssh",
            ]
        )
        assert rc == 0
        assert (tmp_path / "user-data").is_file()
        assert (tmp_path / "meta-data").is_file()
        assert (tmp_path / "seed.iso").is_file()
        assert capsys.readouterr().out.strip().endswith("seed.iso")

    def test_daily_vm_seed_contains_luks_credentials(self, tmp_path, monkeypatch):
        monkeypatch.setenv("PROVISION_USER_PASSWORD", "user secret")
        monkeypatch.setenv("PROVISION_LUKS_PASSWORD", "disk secret")
        rc = seed.main(
            [
                "create",
                "--out",
                str(tmp_path),
                "--target",
                "daily-vm",
                "--disk-size",
                "80",
                "--files-only",
            ]
        )

        assert rc == 0
        config = json.loads((tmp_path / "user_configuration.json").read_text())
        credentials = json.loads((tmp_path / "user_credentials.json").read_text())
        assert config["disk_config"]["disk_encryption"]["encryption_type"] == "luks"
        assert credentials["encryption_password"] == "disk secret"
        assert (tmp_path / "user-data").stat().st_mode & 0o777 == 0o600

    def test_daily_vm_requires_luks_password(self, tmp_path, monkeypatch):
        monkeypatch.setenv("PROVISION_USER_PASSWORD", "user secret")
        monkeypatch.delenv("PROVISION_LUKS_PASSWORD", raising=False)
        with pytest.raises(SystemExit):
            seed.main(
                [
                    "create",
                    "--out",
                    str(tmp_path),
                    "--target",
                    "daily-vm",
                    "--disk-size",
                    "80",
                    "--files-only",
                ]
            )

    def test_live_ssh_requires_pubkey(self, tmp_path):
        with pytest.raises(SystemExit):
            seed.main(
                [
                    "create",
                    "--out",
                    str(tmp_path),
                    "--target",
                    "vmware",
                    "--disk-size",
                    "80",
                    "--pass-hash",
                    "$6$s$h",
                    "--live-ssh",
                ]
            )

    def test_metal_seed_requires_explicit_target_inputs(self, tmp_path):
        with pytest.raises(SystemExit):
            seed.main(
                [
                    "create",
                    "--out",
                    str(tmp_path),
                    "--target",
                    "metal",
                    "--disk-size",
                    "256",
                    "--ram-gib",
                    "32",
                ]
            )

    def test_metal_files_contain_recipe_but_no_credentials(self, tmp_path, capsys):
        rc = seed.main(
            [
                "create",
                "--out",
                str(tmp_path),
                "--target",
                "metal",
                "--disk-size",
                "256",
                "--ram-gib",
                "32",
                "--files-only",
                "--disk-device",
                "/dev/nvme0n1",
                "--hostname",
                "fresh-laptop",
            ]
        )
        assert rc == 0
        assert not (tmp_path / "user_credentials.json").exists()
        assert not (tmp_path / "seed.iso").exists()
        assert (tmp_path / "provision-seed").stat().st_mode & 0o111
        assert "encryption_password" not in (tmp_path / "user-data").read_text()
        config = json.loads((tmp_path / "user_configuration.json").read_text())
        assert (
            config["disk_config"]["disk_encryption"]["encryption_type"] == "lvm_on_luks"
        )
        assert capsys.readouterr().out.strip().endswith("run-install.sh")
