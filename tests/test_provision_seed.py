"""Provisioning-seed tests (Stories 2.29, 2.36, 2.56).

Disposable VM targets only; metal moved to install-on-metal in Story 2.56.
No VMware, libvirt, block-device mutation, or network access.
"""

import base64
import io
import json

import pytest
from conftest import load_tool

seed = load_tool("provision_seed", "provision-seed")


def make_request(target="vmware", **overrides):
    values = {
        "target": target,
        "disk_size_gib": 80,
        "hostname": "archvm",
        "user": "aaron",
        "pubkey": "ssh-ed25519 AAAA test",
    }
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

    def test_pubkey_lands_in_authorized_keys_command(self):
        cmds = "\n".join(self._cfg("vmware")["custom_commands"])
        assert "authorized_keys" in cmds and "ssh-ed25519 AAAA test" in cmds

    def test_no_pubkey_no_authorized_keys_command(self):
        cmds = "\n".join(self._cfg("vmware", pubkey="")["custom_commands"])
        assert "authorized_keys" not in cmds

    def test_vmware_enables_vmtoolsd(self):
        cmds = "\n".join(self._cfg("vmware")["custom_commands"])
        assert "systemctl enable vmtoolsd.service" in cmds

    def test_qemu_enables_no_tools_service(self):
        cmds = "\n".join(self._cfg("qemu")["custom_commands"])
        assert "vmtoolsd" not in cmds


class TestUserData:
    def _ud(self, target="vmware", live_ssh_pubkey=None):
        request = make_request(target)
        return seed.build_user_data(
            user_configuration=seed.build_user_configuration(request),
            user_credentials=seed.build_user_credentials(
                user="aaron",
                pass_hash="$6$s$h",
                luks_secret="disk secret" if request.target.encrypted else None,
            ),
            live_ssh_pubkey=live_ssh_pubkey,
            run_install_sh=seed.build_run_install(),
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
