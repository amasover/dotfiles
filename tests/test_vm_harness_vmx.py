"""pytest suite for vm-harness-vmx (Story 2.36, #119). No VMware needed."""

import importlib.util
import importlib.machinery
from pathlib import Path

import pytest

_TOOL = Path(__file__).parent.parent / ".local" / "bin" / "setup" / "vm-harness-vmx"


def _load():
    loader = importlib.machinery.SourceFileLoader("vm_harness_vmx", str(_TOOL))
    spec = importlib.util.spec_from_loader("vm_harness_vmx", loader)
    mod = importlib.util.module_from_spec(spec)
    loader.exec_module(mod)
    return mod


vmx = _load()


def _build(**kw):
    args = dict(name="arch-harness", disk=r"C:\vm\disk.vmdk", iso=r"C:\c\arch.iso",
                seed_iso=r"C:\vm\seed.iso", serial_log=r"C:\vm\serial.log",
                ram_mib=12288, cpus=16)
    args.update(kw)
    return vmx.build_vmx(**args)


class TestBuildVmx:
    def test_uefi_firmware(self):
        # systemd-boot requires UEFI — legacy BIOS was the retired win10 VM's mistake.
        assert 'firmware = "efi"' in _build()

    def test_disk_on_nvme_matching_seed_device_path(self):
        text = _build()
        assert 'nvme0:0.fileName = "C:\\vm\\disk.vmdk"' in text
        assert 'nvme0:0.present = "TRUE"' in text

    def test_both_isos_attached_as_sata_cdroms(self):
        text = _build()
        assert 'sata0:0.fileName = "C:\\c\\arch.iso"' in text
        assert 'sata0:1.fileName = "C:\\vm\\seed.iso"' in text
        assert text.count('deviceType = "cdrom-image"') == 2

    def test_serial_port_logs_to_file(self):
        text = _build()
        assert 'serial0.fileType = "file"' in text
        assert 'serial0.fileName = "C:\\vm\\serial.log"' in text

    def test_rtc_pinned_to_utc(self):
        assert 'rtc.diffFromUTC = "0"' in _build()

    def test_headless_never_blocks_on_dialogs(self):
        assert 'msg.autoAnswer = "TRUE"' in _build()

    def test_sizing_parameters_land(self):
        text = _build(ram_mib=4096, cpus=4)
        assert 'memsize = "4096"' in text
        assert 'numvcpus = "4"' in text


class TestEjectMedia:
    def test_detaches_both_cd_drives_only(self):
        out = vmx.eject_media(_build())
        assert 'sata0:0.present = "FALSE"' in out
        assert 'sata0:1.present = "FALSE"' in out
        # the buses and disk stay
        assert 'sata0.present = "TRUE"' in out
        assert 'nvme0:0.present = "TRUE"' in out

    def test_idempotent(self):
        once = vmx.eject_media(_build())
        assert vmx.eject_media(once) == once


class TestGeneratedMac:
    def test_reads_vmware_written_mac(self):
        text = _build() + 'ethernet0.generatedAddress = "00:0C:29:AB:CD:EF"\n'
        assert vmx.generated_mac(text) == "00:0c:29:ab:cd:ef"

    def test_none_before_first_power_on(self):
        assert vmx.generated_mac(_build()) is None


class TestCli:
    def test_generate_then_eject_roundtrip(self, tmp_path, capsys):
        out = tmp_path / "t.vmx"
        rc = vmx.main(["generate", "--out", str(out), "--disk", "d.vmdk",
                       "--iso", "a.iso", "--seed-iso", "s.iso", "--serial-log", "s.log"])
        assert rc == 0 and out.is_file()
        rc = vmx.main(["eject", "--vmx", str(out)])
        assert rc == 0
        assert 'sata0:0.present = "FALSE"' in out.read_text()

    def test_mac_missing_is_an_error(self, tmp_path):
        out = tmp_path / "t.vmx"
        vmx.main(["generate", "--out", str(out), "--disk", "d", "--iso", "a",
                  "--seed-iso", "s", "--serial-log", "l"])
        assert vmx.main(["mac", "--vmx", str(out)]) == 1
