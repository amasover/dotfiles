"""pytest suite for vm-harness-leases (Story 2.36, #119). No VMware needed."""

import importlib.util
import importlib.machinery
from pathlib import Path

_TOOL = Path(__file__).parent.parent / ".local" / "bin" / "setup" / "vm-harness-leases"


def _load():
    loader = importlib.machinery.SourceFileLoader("vm_harness_leases", str(_TOOL))
    spec = importlib.util.spec_from_loader("vm_harness_leases", loader)
    mod = importlib.util.module_from_spec(spec)
    loader.exec_module(mod)
    return mod


leases = _load()

SAMPLE = """\
# All times in this file are in UTC (GMT), not your local timezone.   This is
# not a bug, so please don't ask about it.
# The format of this file is documented in the dhcpd.leases(5) manual page.

lease 192.168.152.128 {
    starts 3 2026/08/09 06:56:00;
    ends 3 2026/08/09 07:26:00;
    hardware ethernet 00:0c:29:aa:bb:cc;
    client-hostname "archiso";
}
lease 192.168.152.130 {
    starts 3 2026/08/09 07:00:00;
    ends 3 2026/08/09 07:30:00;
    hardware ethernet 00:0c:29:dd:ee:ff;
}
lease 192.168.152.129 {
    starts 3 2026/08/09 08:10:00;
    ends 3 2026/08/09 08:40:00;
    hardware ethernet 00:0c:29:aa:bb:cc;
    client-hostname "archvm";
}
"""


class TestParse:
    def test_all_blocks_in_file_order(self):
        parsed = leases.parse_leases(SAMPLE)
        assert [l["ip"] for l in parsed] == [
            "192.168.152.128", "192.168.152.130", "192.168.152.129"]

    def test_header_comments_ignored(self):
        assert leases.parse_leases("# lease 1.2.3.4 { fake }\n") == []


class TestFindIp:
    def test_last_lease_wins_for_reassigned_mac(self):
        # Same MAC leased twice (live ISO then installed system) — the file is
        # append-ordered, so the later block is the current address.
        assert leases.find_ip(SAMPLE, "00:0c:29:aa:bb:cc") == "192.168.152.129"

    def test_mac_matching_is_case_insensitive(self):
        assert leases.find_ip(SAMPLE, "00:0C:29:DD:EE:FF") == "192.168.152.130"

    def test_unknown_mac_is_none(self):
        assert leases.find_ip(SAMPLE, "00:0c:29:00:00:00") is None


class TestCli:
    def test_prints_ip(self, tmp_path, capsys):
        f = tmp_path / "l.leases"
        f.write_text(SAMPLE)
        rc = leases.main(["--mac", "00:0C:29:AA:BB:CC", "--leases", str(f)])
        assert rc == 0
        assert capsys.readouterr().out.strip() == "192.168.152.129"

    def test_no_lease_exits_nonzero(self, tmp_path):
        f = tmp_path / "l.leases"
        f.write_text(SAMPLE)
        assert leases.main(["--mac", "00:0c:29:00:00:00", "--leases", str(f)]) == 1
