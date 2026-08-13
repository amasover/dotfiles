"""pytest suite for vm-harness-leases (Story 2.36, #119). No VMware needed."""

from conftest import load_tool

leases = load_tool("vm_harness_leases", "vm-harness-leases")

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


# The shape that broke live on 2026-08-13: vmnetdhcp had rewritten the file,
# so the CURRENT lease led and two expired ones followed. Taking the last
# block handed ssh a two-day-dead address.
REWRITTEN = """\
lease 192.168.92.130 {
    starts 4 2026/08/13 04:54:14;
    ends 4 2026/08/13 05:24:14;
    hardware ethernet 00:0c:29:40:71:13;
}
lease 192.168.92.128 {
    starts 2 2026/08/11 06:13:06;
    ends 2 2026/08/11 06:43:06;
    hardware ethernet 00:0c:29:40:71:13;
}
lease 192.168.92.129 {
    starts 2 2026/08/11 06:22:27;
    ends 2 2026/08/11 06:24:46;
    hardware ethernet 00:0c:29:40:71:13;
}
"""


class TestFindIp:
    def test_newest_lease_wins_for_reassigned_mac(self):
        # Same MAC leased twice (live ISO then installed system).
        assert leases.find_ip(SAMPLE, "00:0c:29:aa:bb:cc") == "192.168.152.129"

    def test_newest_wins_even_when_it_leads_the_file(self):
        assert leases.find_ip(REWRITTEN, "00:0c:29:40:71:13") == "192.168.92.130"

    def test_file_order_breaks_ties_when_timestamps_are_absent(self):
        text = ("lease 10.0.0.1 {\n hardware ethernet 00:11:22:33:44:55;\n}\n"
                "lease 10.0.0.2 {\n hardware ethernet 00:11:22:33:44:55;\n}\n")
        assert leases.find_ip(text, "00:11:22:33:44:55") == "10.0.0.2"

    def test_timestamped_lease_beats_an_undated_one(self):
        text = ("lease 10.0.0.9 {\n starts 4 2026/08/13 04:54:14;\n"
                " hardware ethernet 00:11:22:33:44:55;\n}\n"
                "lease 10.0.0.2 {\n hardware ethernet 00:11:22:33:44:55;\n}\n")
        assert leases.find_ip(text, "00:11:22:33:44:55") == "10.0.0.9"

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

    def test_missing_leases_file_is_a_clean_error(self, tmp_path, capsys):
        # First-ever VM: the vmnet DHCP server hasn't written the file yet.
        rc = leases.main(["--mac", "00:0c:29:aa:bb:cc",
                          "--leases", str(tmp_path / "nope.leases")])
        assert rc == 1
        assert "cannot read leases file" in capsys.readouterr().err
