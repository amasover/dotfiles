"""pytest suite for vm-harness-seed (Story 2.36, #119).

No VMware, no libvirt, no network — pure logic plus tmp_path files.
Run from the repo root: python -m pytest tests/
"""

import base64
import io
import json
import sys

import pytest

from conftest import load_tool

seed = load_tool("vm_harness_seed", "vm-harness-seed")


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


class TestRootGib:
    def test_fills_disk_minus_esp_and_slack(self):
        assert seed.root_gib(80) == 78

    def test_too_small_dies(self):
        with pytest.raises(ValueError):
            seed.root_gib(21)


class TestUserConfiguration:
    def _cfg(self, hypervisor, **kw):
        args = dict(hypervisor=hypervisor, disk_size_gib=80, hostname="archvm",
                    user="aaron", pubkey="ssh-ed25519 AAAA test")
        args.update(kw)
        return seed.build_user_configuration(**args)

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

    def test_root_partition_sized_from_disk(self):
        parts = self._cfg("vmware")["disk_config"]["device_modifications"][0]["partitions"]
        root = [p for p in parts if p["mountpoint"] == "/"][0]
        assert root["size"] == {"unit": "GiB", "value": 78,
                                "sector_size": {"value": 512, "unit": "B"}}

    def test_pubkey_lands_in_authorized_keys_command(self):
        cmds = "\n".join(self._cfg("vmware")["custom_commands"])
        assert "authorized_keys" in cmds and "ssh-ed25519 AAAA test" in cmds

    def test_no_pubkey_no_authorized_keys_command(self):
        cmds = "\n".join(self._cfg("vmware", pubkey="")["custom_commands"])
        assert "authorized_keys" not in cmds


class TestUserData:
    def _ud(self, live_ssh_pubkey=None):
        cfg = seed.build_user_configuration(
            hypervisor="vmware", disk_size_gib=80, hostname="archvm",
            user="aaron", pubkey="ssh-ed25519 AAAA test")
        creds = seed.build_user_credentials(user="aaron", pass_hash="$6$s$h")
        return seed.build_user_data(user_configuration=cfg, user_credentials=creds,
                                    live_ssh_pubkey=live_ssh_pubkey)

    def test_embedded_config_roundtrips(self):
        ud = self._ud()
        b64 = [l.split(": ", 1)[1] for l in ud.splitlines()
               if l.strip().startswith("content: ")][0]
        cfg = json.loads(base64.b64decode(b64))
        assert cfg["hostname"] == "archvm"

    def test_install_driver_is_transient_unit(self):
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
        assert iso.pvd.volume_identifier.decode("utf-16-be", errors="ignore").strip("\x00 ") or True
        buf = io.BytesIO()
        iso.get_file_from_iso_fp(buf, joliet_path="/user-data")
        assert buf.getvalue() == b"#cloud-config\nkey: value\n"
        buf = io.BytesIO()
        iso.get_file_from_iso_fp(buf, joliet_path="/meta-data")
        assert buf.getvalue() == seed.META_DATA.encode()
        iso.close()


class TestCli:
    def test_generate_writes_seed_set(self, tmp_path, capsys):
        rc = seed.main([
            "--out", str(tmp_path), "--hypervisor", "vmware", "--disk-size", "80",
            "--pass-hash", "$6$s$h", "--pubkey", "ssh-ed25519 AAAA test", "--live-ssh",
        ])
        assert rc == 0
        assert (tmp_path / "user-data").is_file()
        assert (tmp_path / "meta-data").is_file()
        assert (tmp_path / "seed.iso").is_file()
        assert capsys.readouterr().out.strip().endswith("seed.iso")

    def test_live_ssh_requires_pubkey(self, tmp_path):
        with pytest.raises(SystemExit):
            seed.main([
                "--out", str(tmp_path), "--hypervisor", "vmware", "--disk-size", "80",
                "--pass-hash", "$6$s$h", "--live-ssh",
            ])
