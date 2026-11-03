"""pytest suite for vm-harness-vmx (Story 2.36, #119). No VMware needed."""

import io
import json

import pytest

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

    def test_vmware_3d_acceleration(self):
        assert 'mks.enable3d = "TRUE"' in _build()

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

    def test_x86_64_keeps_workstation_hardware(self):
        # The Windows/Workstation VM is validated as-is; the arm table must
        # not leak into it.
        text = _build()
        assert 'guestOS = "other6xlinux-64"' in text
        assert 'virtualHW.version = "21"' in text
        assert 'usb.present = "FALSE"' in text
        assert "usb_xhci" not in text
        assert "svga." not in text

    def test_x86_64_sound_uses_workstation_default_card(self):
        text = _build()
        assert 'sound.present = "TRUE"' in text
        assert "sound.virtualDev" not in text


class TestBuildVmxAarch64:
    # Fusion on Apple silicon: ids read off Fusion 26H1's own `vmcli VM Create`.
    def test_arm_guest_id_and_hardware_version(self):
        text = _build(arch="aarch64")
        assert 'guestOS = "arm-other7xlinux-64"' in text
        assert 'virtualHW.version = "22"' in text

    def test_xhci_usb_input(self):
        # KB 315602: arm guests get keyboard/mouse via the XHCI controller.
        text = _build(arch="aarch64")
        assert 'usb.present = "TRUE"' in text
        assert 'usb_xhci.present = "TRUE"' in text
        assert 'usb.present = "FALSE"' not in text

    def test_shared_shape_kept(self):
        text = _build(arch="aarch64")
        for line in ('firmware = "efi"', 'mks.enable3d = "TRUE"',
                     'nvme0:0.present = "TRUE"', 'ethernet0.virtualDev = "vmxnet3"',
                     'serial0.fileType = "file"', 'floppy0.present = "FALSE"'):
            assert line in text
        assert text.count('deviceType = "cdrom-image"') == 2

    def test_multimonitor_display_left_to_autodetect(self):
        text = _build(arch="aarch64")
        assert 'svga.autodetect = "TRUE"' in text
        assert 'svga.graphicsMemoryKB = "2097152"' in text
        for capped in ("svga.maxWidth", "svga.maxHeight", "svga.numDisplays",
                       "svga.vramSize"):
            assert capped not in text

    def test_sound_card_is_hdaudio(self):
        # Fusion's es1371 default fails arm power-on; hdaudio is the one that runs.
        text = _build(arch="aarch64")
        assert 'sound.present = "TRUE"' in text
        assert 'sound.virtualDev = "hdaudio"' in text

    def test_virtual_camera_on_free_xhci_port(self):
        text = _build(arch="aarch64")
        assert 'usb_xhci:5.deviceType = "video"' in text
        assert 'usb_xhci:5.port = "5"' in text
        assert 'usb_xhci:5.parent = "-1"' in text
        # Fusion adds its own HID (port 4) and hubs (6, 7) at power-on.
        for taken in ("usb_xhci:4.", "usb_xhci:6.", "usb_xhci:7."):
            assert taken not in text

    def test_each_key_written_once(self):
        keys = [l.split(" = ")[0] for l in _build(arch="aarch64").splitlines()]
        assert len(keys) == len(set(keys))


SHARED_KEYS = [
    ".encoding", "config.version", "virtualHW.version", "displayName", "guestOS",
    "firmware", "mks.enable3d", "memsize", "numvcpus",
    "pciBridge0.present", "pciBridge4.present", "pciBridge4.virtualDev",
    "pciBridge4.functions", "pciBridge5.present", "pciBridge5.virtualDev",
    "pciBridge5.functions", "pciBridge6.present", "pciBridge6.virtualDev",
    "pciBridge6.functions", "pciBridge7.present", "pciBridge7.virtualDev",
    "pciBridge7.functions", "nvme0.present", "nvme0:0.present", "nvme0:0.fileName",
    "sata0.present", "sata0:0.present", "sata0:0.deviceType", "sata0:0.fileName",
    "sata0:1.present", "sata0:1.deviceType", "sata0:1.fileName",
    "ethernet0.present", "ethernet0.connectionType", "ethernet0.virtualDev",
    "ethernet0.addressType", "serial0.present", "serial0.fileType",
    "serial0.fileName", "serial0.tryNoRxLoss", "rtc.diffFromUTC",
    "tools.syncTime", "msg.autoAnswer", "sound.present", "usb.present",
    "floppy0.present", "vmci0.present",
]


class TestFullKeySets:
    # Every key each architecture writes, in order: one table (ARCH_HW) owns
    # the difference, and x86_64 gains nothing from it.
    def _keys(self, arch):
        return [l.split(" = ")[0] for l in _build(arch=arch).splitlines()]

    def test_x86_64(self):
        assert self._keys("x86_64") == SHARED_KEYS

    def test_aarch64(self):
        assert self._keys("aarch64") == SHARED_KEYS + [
            "usb_xhci.present", "svga.autodetect", "svga.graphicsMemoryKB",
            "sound.virtualDev", "usb_xhci:5.present", "usb_xhci:5.deviceType",
            "usb_xhci:5.port", "usb_xhci:5.parent"]


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

    def test_generate_arch_flag(self, tmp_path):
        out = tmp_path / "t.vmx"
        rc = vmx.main(["generate", "--out", str(out), "--disk", "d", "--iso", "a",
                       "--seed-iso", "s", "--serial-log", "l", "--arch", "aarch64"])
        assert rc == 0
        assert 'guestOS = "arm-other7xlinux-64"' in out.read_text()

    def test_mac_missing_is_an_error(self, tmp_path):
        out = tmp_path / "t.vmx"
        vmx.main(["generate", "--out", str(out), "--disk", "d", "--iso", "a",
                  "--seed-iso", "s", "--serial-log", "l"])
        assert vmx.main(["mac", "--vmx", str(out)]) == 1


ISO = "archlinux-2026.08.03-aarch64.iso"
SHA = "ab" * 32


def _release(body, *names):
    return {"tag_name": "v1", "name": "Aug release", "body": body,
            "assets": [{"name": n, "browser_download_url": f"https://dl.example/{n}"}
                       for n in names]}


class TestPortsIso:
    def test_hash_next_to_exact_asset_name(self):
        body = f"Checksums:\n{'cd' * 32}  archlinux-2026.08.02-aarch64.iso\n{SHA}  {ISO}\n"
        assert vmx.ports_iso(_release(body, ISO, "README.txt")) == (
            ISO, f"https://dl.example/{ISO}", SHA)

    def test_hash_for_another_name_does_not_pass(self):
        # The 2026-08-03 notes listed other build dates than their assets.
        body = f"{SHA}  archlinux-2026.08.02-aarch64.iso\n"
        with pytest.raises(ValueError, match=f"release v1 publishes no sha256 for {ISO}"):
            vmx.ports_iso(_release(body, ISO))

    def test_missing_hash(self):
        with pytest.raises(ValueError, match="publishes no sha256"):
            vmx.ports_iso(_release(f"short abcd  {ISO}\n", ISO))
        with pytest.raises(ValueError, match="publishes no sha256"):
            vmx.ports_iso({"tag_name": "v1", "body": None,
                           "assets": [{"name": ISO}]})

    def test_two_iso_assets_refused(self):
        body = f"{SHA}  {ISO}\n"
        with pytest.raises(ValueError, match="expected one archlinux-<date>-aarch64.iso asset, found 2"):
            vmx.ports_iso(_release(body, ISO, "archlinux-2026.08.04-aarch64.iso"))

    def test_no_iso_asset(self):
        with pytest.raises(ValueError, match="found 0"):
            vmx.ports_iso(_release(f"{SHA}  {ISO}\n", "archlinux-x86_64.iso.sig"))

    def test_cli_prints_one_field_per_line(self, monkeypatch, capsys):
        rel = _release(f"{SHA}  {ISO}\n", ISO)
        monkeypatch.setattr("sys.stdin", io.TextIOWrapper(io.BytesIO(json.dumps(rel).encode())))
        assert vmx.main(["ports-iso"]) == 0
        assert capsys.readouterr().out.splitlines() == [
            ISO, "Aug release", f"https://dl.example/{ISO}", SHA]

    def test_cli_error_on_stderr(self, monkeypatch, capsys):
        rel = _release("no hashes", ISO)
        monkeypatch.setattr("sys.stdin", io.TextIOWrapper(io.BytesIO(json.dumps(rel).encode())))
        assert vmx.main(["ports-iso"]) == 1
        assert capsys.readouterr().err.strip() == f"release v1 publishes no sha256 for {ISO}"
