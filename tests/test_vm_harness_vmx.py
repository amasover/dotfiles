"""pytest suite for vm-harness-vmx (Story 2.36, #119). No VMware needed."""

from conftest import load_tool

vmx = load_tool("vm_harness_vmx", "vm-harness-vmx")


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

    def test_no_floppy(self):
        # VMware defaults a floppy controller in; the guest kernel then logs
        # "I/O error, dev fd0" on every boot probing the empty drive.
        assert 'floppy0.present = "FALSE"' in _build()

    def test_sizing_parameters_land(self):
        text = _build(ram_mib=4096, cpus=4)
        assert 'memsize = "4096"' in text
        assert 'numvcpus = "4"' in text

    def test_pcie_root_ports_for_nvme_and_vmxnet3(self):
        # Without these, power-on fails: "No PCIe slot available for Ethernet0".
        text = _build()
        assert 'pciBridge4.virtualDev = "pcieRootPort"' in text
        assert text.count('virtualDev = "pcieRootPort"') == 4


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


class TestMediaState:
    def test_fresh_vmx_is_attached(self):
        assert vmx.media_state(_build()) == "attached"

    def test_ejected_after_eject(self):
        assert vmx.media_state(vmx.eject_media(_build())) == "ejected"

    def test_absent_line_counts_as_ejected(self):
        # VMware owns the vmx after power-on and may drop FALSE devices.
        text = "\n".join(l for l in _build().splitlines()
                         if not l.startswith("sata0:0.present")) + "\n"
        assert vmx.media_state(text) == "ejected"


class TestResumePoint:
    # The decision table `up` rides on. (facts, expected phase-or-refusal.)
    CASES = [
        # no vmx at all
        (dict(media="absent", disk_exists=True, seed_exists=True,
              serial_log_exists=False, running=False), "create"),
        # disk gone by hand. "create" is the honest answer, but note the vmx
        # still exists, so create would refuse — the driver turns this into
        # "destroy, then up" up front (Cmd-Up), not a half-run that fetches an
        # ISO and then stops.
        (dict(media="attached", disk_exists=False, seed_exists=True,
              serial_log_exists=False, running=False), "create"),
        # never installed and the seed is gone: same shape — nothing here can
        # be resumed, and the vmx makes it a destroy-first, not a re-create
        (dict(media="attached", disk_exists=True, seed_exists=False,
              serial_log_exists=False, running=False), "create"),
        # created, never powered on
        (dict(media="attached", disk_exists=True, seed_exists=True,
              serial_log_exists=False, running=False), "install"),
        # install going on right now — refuse, whatever the serial log says
        (dict(media="attached", disk_exists=True, seed_exists=True,
              serial_log_exists=True, running=True), "install-running"),
        (dict(media="attached", disk_exists=True, seed_exists=True,
              serial_log_exists=False, running=True), "install-running"),
        # powered on before, now off, media still attached: died mid-install
        (dict(media="attached", disk_exists=True, seed_exists=True,
              serial_log_exists=True, running=False), "dead-install"),
        # installed + off → boot; the seed stopped mattering at eject
        (dict(media="ejected", disk_exists=True, seed_exists=False,
              serial_log_exists=False, running=False), "boot"),
        # installed + running → bootstrap (check follows; both always re-run)
        (dict(media="ejected", disk_exists=True, seed_exists=True,
              serial_log_exists=True, running=True), "bootstrap"),
    ]

    def test_decision_table(self):
        for facts, want in self.CASES:
            assert vmx.resume_point(**facts) == want, facts

    def test_cli_resume(self, capsys):
        rc = vmx.main(["resume", "--media", "ejected", "--disk", "yes",
                       "--seed", "no", "--serial-log", "no", "--running", "no"])
        assert rc == 0
        assert capsys.readouterr().out.strip() == "boot"


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
        rc = vmx.main(["media", "--vmx", str(out)])
        assert rc == 0
        assert capsys.readouterr().out.splitlines()[-1] == "attached"
        rc = vmx.main(["eject", "--vmx", str(out)])
        assert rc == 0
        assert 'sata0:0.present = "FALSE"' in out.read_text()
        rc = vmx.main(["media", "--vmx", str(out)])
        assert rc == 0
        assert capsys.readouterr().out.splitlines()[-1] == "ejected"

    def test_mac_missing_is_an_error(self, tmp_path):
        out = tmp_path / "t.vmx"
        vmx.main(["generate", "--out", str(out), "--disk", "d", "--iso", "a",
                  "--seed-iso", "s", "--serial-log", "l"])
        assert vmx.main(["mac", "--vmx", str(out)]) == 1
