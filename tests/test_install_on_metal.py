"""install-on-metal tests (Story 2.56).

No block-device mutation, pacstrap, chroot, or network access. The destructive
half is proven by `metal-rehearsal`, not here.
"""

import os
import pty
import subprocess
import sys
import time

import pytest
from conftest import load_tool

metal = load_tool("install_on_metal", "install-on-metal")
refind = load_tool("refind_config_for_metal", "refind-config")
# The rehearsal's terminal framing is the only consumer of the live prompts, so
# it drives them here rather than a stand-in expect loop.
rehearsal = load_tool("metal_rehearsal_for_metal", "metal-rehearsal")

DEFAULT_HOOKS = (
    "HOOKS=(base udev autodetect microcode modconf kms keyboard keymap "
    "consolefont block filesystems fsck)\n"
)

GIB = 1073741824


def target_state(**override):
    """A blank, matching 256 GiB whole disk on a 32 GiB UEFI machine."""
    return metal.TargetState(
        **{
            "disk_bytes": 256 * GIB,
            "ram_gib": 32,
            "is_whole_disk": True,
            "is_uefi": True,
            "mountpoints": (),
            "holders": (),
        }
        | override
    )


class TestLayoutSizing:
    def test_root_fills_disk_minus_esp_and_slack(self):
        assert metal.root_gib(256) == 254

    def test_disk_too_small_dies(self):
        with pytest.raises(metal.InstallError):
            metal.root_gib(21)

    def test_layout_reserves_resume_and_routine_headroom(self):
        root, resume, routine = metal.metal_layout_gib(256, 32)
        assert (root, resume, routine) == (222, 32, 48)
        assert root - routine == 174

    def test_layout_refuses_insufficient_post_swap_root(self):
        with pytest.raises(metal.InstallError, match="needs >= 123G"):
            metal.metal_layout_gib(122, 32)

    @pytest.mark.parametrize("ram_gib", [0, -1])
    def test_layout_refuses_invalid_ram(self, ram_gib):
        with pytest.raises(metal.InstallError, match="RAM"):
            metal.metal_layout_gib(256, ram_gib)


class TestVolumeGroupName:
    def test_name_follows_the_host(self):
        assert metal.volume_group_name("new-laptop") == "new-laptop"

    def test_two_hosts_never_share_a_name(self):
        assert metal.volume_group_name("alpha") != metal.volume_group_name("beta")

    @pytest.mark.parametrize(
        "hostname",
        ["", "-leading", "trailing-", "Upper", "has space", "dot.ted", "x" * 64],
    )
    def test_refuses_names_lvm_or_dns_would_not_accept(self, hostname):
        with pytest.raises(metal.InstallError, match="hostname"):
            metal.volume_group_name(hostname)


class TestPartitionPath:
    @pytest.mark.parametrize(
        ("device", "expected"),
        [("/dev/sda", "/dev/sda1"), ("/dev/nvme0n1", "/dev/nvme0n1p1")],
    )
    def test_index_suffix_follows_the_device_naming_rule(self, device, expected):
        assert metal.partition_path(device, 1) == expected

    @pytest.mark.parametrize(
        ("owner", "device", "owned"),
        [
            ("sda", "/dev/sda", True),
            ("sda1", "/dev/sda", True),
            ("nvme0n1p4", "/dev/nvme0n1", True),
            # A different disk, not a partition of this one.
            ("sdaa", "/dev/sda", False),
            ("sdaa1", "/dev/sda", False),
            # A sibling NVMe namespace, not a partition of namespace 1.
            ("nvme0n11", "/dev/nvme0n1", False),
            ("nvme0n2", "/dev/nvme0n1", False),
        ],
    )
    def test_only_the_target_disk_and_its_partitions_are_its_own(
        self, owner, device, owned
    ):
        link = metal.Path(f"/sys/class/block/{owner}/holders/dm-0")
        assert metal._belongs_to(link, device) is owned


class TestPreflight:
    FACTS = ("/dev/nvme0n1", 256, 32)

    def _refuse(self, state):
        metal.refuse_unsafe_target("/dev/nvme0n1", state)
        metal.refuse_unexpected_facts(metal.MetalFacts(*self.FACTS), state)

    def test_accepts_matching_blank_whole_disk(self):
        self._refuse(target_state(disk_bytes=256 * GIB + 4096))

    @pytest.mark.parametrize(
        ("override", "message"),
        [
            ({"is_whole_disk": False}, "whole disk"),
            ({"disk_bytes": 255 * GIB}, "size does not match"),
            ({"ram_gib": 31}, "RAM rounds"),
            ({"mountpoints": ("/mnt",)}, "mounted"),
            ({"is_uefi": False}, "UEFI"),
            ({"holders": ("dm-0",)}, "held by"),
        ],
    )
    def test_fails_closed_on_every_unsafe_target(self, override, message):
        with pytest.raises(metal.InstallError, match=message):
            self._refuse(target_state(**override))

    def test_requires_exact_device_specific_confirmation(self):
        metal.require_wipe_confirmation("/dev/nvme0n1", "WIPE /dev/nvme0n1")
        for answer in ("WIPE /dev/nvme1n1", "wipe /dev/nvme0n1", "yes", ""):
            with pytest.raises(metal.InstallError, match="did not match"):
                metal.require_wipe_confirmation("/dev/nvme0n1", answer)

    def test_names_every_missing_installer_binary(self):
        absent = {"pacstrap", "cryptsetup"}
        missing = metal.missing_tools(
            lambda name: None if name in absent else "/usr/bin"
        )
        assert set(missing) == absent
        with pytest.raises(metal.InstallError, match="pacstrap"):
            metal.require_tools(lambda name: None if name in absent else "/usr/bin")

    def test_every_binary_the_destructive_phase_runs_is_checked_first(
        self, monkeypatch, tmp_path
    ):
        """A tool discovered missing after the wipe leaves an unbootable target."""
        invoked = []

        def record(command, **_kwargs):
            invoked.append(command[0])
            return subprocess.CompletedProcess(command, 0)

        def record_output(command):
            invoked.append(command[0])
            return "0123-UUID"

        monkeypatch.setattr(metal, "run", record)
        monkeypatch.setattr(metal, "command_output", record_output)
        monkeypatch.setattr(metal.subprocess, "run", record)
        facts = metal.MetalFacts("/dev/vda", 256, 32)
        metal.build_storage(facts, "metal-test", "disk secret")
        metal.mount_target(tmp_path / "target", "/dev/vda1", "metal-test")
        metal.release_target(tmp_path / "target", "metal-test")
        assert invoked
        assert set(invoked) <= set(metal.REQUIRED_TOOLS)


class TestHooks:
    def test_encrypt_and_lvm_precede_filesystems(self):
        hooks = metal.rewrite_hooks(DEFAULT_HOOKS, ["encrypt", "lvm2"])
        order = hooks[hooks.index("(") + 1 : hooks.index(")")].split()
        assert order.index("encrypt") < order.index("lvm2") < order.index("filesystems")

    def test_rerun_after_partial_failure_converges(self):
        once = metal.rewrite_hooks(DEFAULT_HOOKS, ["encrypt", "lvm2", "resume"])
        assert metal.rewrite_hooks(once, ["encrypt", "lvm2", "resume"]) == once

    def test_refuses_a_conf_without_one_literal_hooks_array(self):
        with pytest.raises(metal.InstallError, match="one literal"):
            metal.rewrite_hooks("MODULES=()\n", ["resume"])
        with pytest.raises(metal.InstallError, match="one literal"):
            metal.rewrite_hooks(DEFAULT_HOOKS * 2, ["resume"])

    def test_refuses_a_hooks_array_with_no_filesystems(self):
        with pytest.raises(metal.InstallError, match="filesystems"):
            metal.rewrite_hooks("HOOKS=(base udev block)\n", ["resume"])

    # What Arch actually ships today. `encrypt` is inert in a systemd initrd and
    # `cryptdevice=` is ignored, so a target built on it reaches an emergency
    # shell instead of a passphrase prompt.
    SYSTEMD_HOOKS = (
        "HOOKS=(base systemd autodetect microcode modconf kms keyboard "
        "sd-vconsole block filesystems fsck)\n"
    )

    @staticmethod
    def _order(text):
        return text[text.index("(") + 1 : text.index(")")].split()

    def test_the_recipe_owns_the_whole_array(self):
        order = self._order(metal.set_hooks(self.SYSTEMD_HOOKS))
        assert "systemd" not in order
        assert "sd-vconsole" not in order
        assert order.index("keyboard") < order.index("encrypt")
        assert order.index("encrypt") < order.index("lvm2")
        assert order.index("lvm2") < order.index("resume")
        assert order.index("resume") < order.index("filesystems")
        assert order.index("filesystems") < order.index("fsck")

    def test_setting_the_array_converges_on_a_rerun(self):
        once = metal.set_hooks(self.SYSTEMD_HOOKS)
        assert metal.set_hooks(once) == once

    def test_a_systemd_array_is_refused_rather_than_patched(self):
        with pytest.raises(metal.InstallError, match="systemd-based"):
            metal.rewrite_hooks(self.SYSTEMD_HOOKS, ["resume"])


class TestLocale:
    # Arch ships the entry indented behind the comment marker; a pattern anchored
    # on a bare "#" silently generates nothing.
    STOCK = "#en_US.UTF-8 UTF-8\n#  en_US.UTF-8 UTF-8  \n# de_DE.UTF-8 UTF-8\n"

    def test_uncomments_the_entry_however_it_is_indented(self):
        assert metal.enable_locale(self.STOCK).splitlines()[:2] == [
            "en_US.UTF-8 UTF-8",
            "en_US.UTF-8 UTF-8",
        ]

    def test_leaves_other_locales_commented(self):
        assert "# de_DE.UTF-8 UTF-8" in metal.enable_locale(self.STOCK)

    def test_an_already_enabled_entry_is_left_alone(self):
        enabled = "en_US.UTF-8 UTF-8\n"
        assert metal.enable_locale(enabled) == enabled

    def test_a_locale_gen_without_the_entry_is_refused(self):
        with pytest.raises(metal.InstallError, match="no entry"):
            metal.enable_locale("# de_DE.UTF-8 UTF-8\n")


class TestRefindLinuxConf:
    def test_kernel_options_unlock_the_named_group(self):
        options = metal.refind_linux_conf("new-laptop", "1234-UUID")
        assert "cryptdevice=UUID=1234-UUID:cryptlvm" in options
        assert "root=/dev/new-laptop/root" in options

    def test_resume_is_left_to_the_first_boot_handoff(self):
        """refind-config only derives resume=UUID= when the cmdline has none."""
        assert "resume=" not in metal.refind_linux_conf("new-laptop", "1234-UUID")


@pytest.fixture
def metal_target(tmp_path, monkeypatch):
    (tmp_path / "etc").mkdir()
    (tmp_path / "etc/fstab").write_text("/dev/new-laptop/root / ext4 defaults 0 1\n")
    (tmp_path / "etc/mkinitcpio.conf").write_text(
        "HOOKS=(base udev encrypt lvm2 block filesystems fsck)\n"
    )
    # Building an initramfs requires the installed target; exercised in the VM.
    run = subprocess.run

    def target_run(command, **kwargs):
        if command[0] == "arch-chroot":
            return subprocess.CompletedProcess(command, 0)
        return run(command, **kwargs)

    monkeypatch.setattr(metal.subprocess, "run", target_run)
    refind_dir = tmp_path / "boot/EFI/refind"
    refind_dir.mkdir(parents=True)
    (refind_dir / "refind.conf").write_text("timeout 20\n")
    (tmp_path / "boot/refind_linux.conf").write_text(
        '"Arch Linux" "root=/dev/new-laptop/root"\n'
    )
    return tmp_path


def fstab_swap(root):
    return subprocess.run(
        [
            "findmnt",
            "--fstab",
            "--tab-file",
            str(root / "etc/fstab"),
            "--types",
            "swap",
            "--noheadings",
            "--output",
            "SOURCE,OPTIONS",
        ],
        text=True,
        capture_output=True,
        check=False,
    ).stdout.split()


class TestFinalize:
    def test_resume_runs_after_unlock_before_filesystem_checks(self, metal_target):
        metal.finalize_metal(metal_target, "new-laptop")
        metal.finalize_metal(metal_target, "new-laptop")
        hooks = subprocess.run(
            [
                "bash",
                "-c",
                "source $1 && printf '%s\\n' \"${HOOKS[@]}\"",
                "bash",
                str(metal_target / "etc/mkinitcpio.conf"),
            ],
            text=True,
            capture_output=True,
            check=True,
        ).stdout.split()
        assert hooks.index("encrypt") < hooks.index("resume")
        assert hooks.index("resume") < hooks.index("filesystems") < hooks.index("fsck")

    def test_resume_swap_follows_the_derived_volume_group(self, metal_target):
        metal.finalize_metal(metal_target, "new-laptop")
        assert fstab_swap(metal_target) == ["/dev/new-laptop/resume", "sw,pri=-1"]

    def test_persists_one_low_priority_swap_across_retries(self, metal_target):
        metal.main(
            [
                "metal-finalize",
                "--root",
                str(metal_target),
                "--volume-group",
                "new-laptop",
            ]
        )
        metal.main(
            [
                "metal-finalize",
                "--root",
                str(metal_target),
                "--volume-group",
                "new-laptop",
            ]
        )
        assert fstab_swap(metal_target) == ["/dev/new-laptop/resume", "sw,pri=-1"]
        assert (
            (metal_target / "etc/fstab")
            .read_text()
            .startswith("/dev/new-laptop/root / ext4 defaults 0 1\n")
        )

    def test_conflicting_swap_refuses_before_marking_boot_files(self, metal_target):
        fstab = metal_target / "etc/fstab"
        original = fstab.read_text() + "/dev/other none swap sw 0 0\n"
        fstab.write_text(original)
        with pytest.raises(metal.InstallError, match="conflicting swap"):
            metal.finalize_metal(metal_target, "new-laptop")
        assert fstab.read_text() == original
        assert (
            metal_target / "boot/EFI/refind/refind.conf"
        ).read_text() == "timeout 20\n"

    def test_marks_refind_files_for_first_boot_reconcile(self, metal_target):
        marked = (
            metal_target / "boot/EFI/refind/refind.conf",
            metal_target / "boot/refind_linux.conf",
        )
        metal.finalize_metal(metal_target, "new-laptop")
        metal.finalize_metal(metal_target, "new-laptop")
        for path in marked:
            assert path.read_text().startswith(metal.REFIND_MANAGED + "\n")
            assert path.read_text().count(metal.REFIND_MANAGED) == 1

    def test_handoff_marker_matches_refind_reconciler(self):
        assert metal.REFIND_MANAGED == refind.MANAGED
        assert metal.THEME_MARKER == refind.THEME_MARKER

    def test_package_theme_copy_is_reconcilable_without_adoption(self, metal_target):
        metal.finalize_metal(metal_target, "new-laptop")
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
        with pytest.raises(metal.InstallError, match="unmanaged Nord theme"):
            metal.finalize_metal(metal_target, "new-laptop")
        assert fstab.read_bytes() == original
        assert not (theme / refind.THEME_MARKER).exists()

    def test_refuses_symlinked_refind_destination(self, metal_target):
        conf = metal_target / "boot/EFI/refind/refind.conf"
        conf.unlink()
        (metal_target / "outside").write_text("timeout 20\n")
        conf.symlink_to(metal_target / "outside")
        with pytest.raises(metal.InstallError, match="symlink"):
            metal.finalize_metal(metal_target, "new-laptop")

    def test_refuses_the_running_root(self):
        with pytest.raises(metal.InstallError, match="offline target root"):
            metal.finalize_metal(metal.Path("/"), "new-laptop")


class TestCredentials:
    def test_returns_both_secrets_without_writing_or_printing_them(self, capsys):
        answers = iter(["user secret", "user secret", "disk secret", "disk secret"])
        user_password, luks = metal.prompt_metal_credentials(
            "aaron", lambda _prompt: next(answers)
        )
        assert (user_password, luks) == ("user secret", "disk secret")
        assert "secret" not in capsys.readouterr().out

    def test_mismatched_confirmation_is_refused(self):
        answers = iter(["first", "different"])
        with pytest.raises(metal.InstallError, match="does not match"):
            metal.prompt_metal_credentials("aaron", lambda _prompt: next(answers))

    def test_empty_password_is_refused(self):
        with pytest.raises(metal.InstallError, match="cannot be empty"):
            metal.prompt_metal_credentials("aaron", lambda _prompt: "")

    def test_unusable_account_name_is_refused_before_prompting(self):
        def never(_prompt):
            raise AssertionError("prompted for a rejected account name")

        with pytest.raises(metal.InstallError, match="account name"):
            metal.prompt_metal_credentials("Bad Name", never)

    def test_real_prompts_accept_terminal_answers_without_echo(self, tmp_path):
        """The rehearsal answers these over a serial pty; echo would log secrets."""
        master, slave = pty.openpty()
        captured = tmp_path / "captured"
        child = (
            "import fcntl, importlib.machinery, importlib.util, sys, termios; "
            "fcntl.ioctl(0, termios.TIOCSCTTY, 0); "
            "loader = importlib.machinery.SourceFileLoader('iom', sys.argv[1]); "
            "spec = importlib.util.spec_from_loader('iom', loader); "
            "mod = importlib.util.module_from_spec(spec); loader.exec_module(mod); "
            "open(sys.argv[2], 'w').write("
            "'\\n'.join(mod.prompt_metal_credentials('aaron')))"
        )
        process = subprocess.Popen(
            [sys.executable, "-c", child, metal.__file__, str(captured)],
            stdin=slave,
            stdout=slave,
            stderr=slave,
            start_new_session=True,
        )
        os.close(slave)
        try:
            with (tmp_path / "terminal.log").open("wb") as log:
                terminal = rehearsal.Expect(master, lambda: time.monotonic() + 5, log)
                for prompt, answer in (
                    (rb"User password: ", "test-user-secret"),
                    (rb"Confirm user password: ", "test-user-secret"),
                    (rb"Disk encryption password: ", "test-disk-secret"),
                    (rb"Confirm disk encryption password: ", "test-disk-secret"),
                ):
                    terminal.expect(prompt)
                    terminal.send(answer + "\n")
                assert process.wait(timeout=5) == 0
            assert captured.read_text() == "test-user-secret\ntest-disk-secret"
            transcript = (tmp_path / "terminal.log").read_bytes()
            assert b"test-user-secret" not in transcript
            assert b"test-disk-secret" not in transcript
        finally:
            if process.poll() is None:
                process.kill()
                process.wait()
            os.close(master)


class TestHardwareFacts:
    @pytest.mark.parametrize(
        ("disk_bytes", "ram_kib", "expected"),
        [
            (63 * GIB, 8 * 1048576, (63, 8)),
            (63 * GIB - 1, 8 * 1048576 + 1, (62, 9)),
        ],
    )
    def test_disk_floors_and_ram_ceils(
        self, monkeypatch, disk_bytes, ram_kib, expected
    ):
        monkeypatch.setattr(metal, "command_output", lambda _cmd: str(disk_bytes))
        monkeypatch.setattr(
            metal.Path, "read_text", lambda _self: f"MemTotal: {ram_kib} kB\n"
        )
        state = target_state(
            disk_bytes=metal.read_disk_bytes("/dev/vda"), ram_gib=metal.read_ram_gib()
        )
        facts = state.facts("/dev/vda")
        assert (facts.disk_size_gib, facts.ram_gib) == expected

    def test_missing_ram_aborts_before_the_disk_is_touched(self, monkeypatch):
        monkeypatch.setattr(
            metal.Path, "read_text", lambda _self: "MemAvailable: 42 kB\n"
        )
        with pytest.raises(metal.InstallError, match="cannot derive"):
            metal.read_ram_gib()

    @pytest.mark.parametrize("reading", ["not a number", "0"])
    def test_malformed_disk_size_is_refused(self, monkeypatch, reading):
        monkeypatch.setattr(metal, "command_output", lambda _cmd: reading)
        with pytest.raises(metal.InstallError, match="malformed"):
            metal.read_disk_bytes("/dev/vda")


class TestCli:
    def test_the_documented_install_form_reaches_the_installer(self, monkeypatch):
        """A bare device is the front door; subparsers would reject it outright."""
        seen = {}
        monkeypatch.setattr(metal, "install", lambda **kw: seen.update(kw))
        assert metal.main(["/dev/vda", "--hostname", "metal-test"]) == 0
        assert seen == {
            "device": "/dev/vda",
            "hostname": "metal-test",
            "user": "aaron",
        }

    def test_a_subcommand_is_not_mistaken_for_a_device(self, monkeypatch):
        seen = {}
        monkeypatch.setattr(
            metal, "metal_preflight", lambda facts: seen.update(f=facts)
        )
        argv = ["metal-preflight", "--device", "/dev/vda"]
        argv += ["--disk-size", "63", "--ram-gib", "8"]
        assert metal.main(argv) == 0
        assert seen["f"] == metal.MetalFacts("/dev/vda", 63, 8)

    def test_an_install_without_a_hostname_is_refused(self):
        with pytest.raises(SystemExit):
            metal.main(["/dev/vda"])

    def test_a_refusal_exits_nonzero_on_the_harness_failure_sentinel(
        self, monkeypatch, capsys
    ):
        """`metal-rehearsal` greps this exact line to fail a run."""

        def refuse(**_kw):
            raise metal.InstallError("target disk or one of its children is mounted")

        monkeypatch.setattr(metal, "install", refuse)
        assert metal.main(["/dev/vda", "--hostname", "metal-test"]) == 1
        assert "metal-provision: install failed: target disk" in capsys.readouterr().err

    def test_install_refuses_to_run_unprivileged(self, monkeypatch):
        monkeypatch.setattr(metal.os, "geteuid", lambda: 1000)
        with pytest.raises(metal.InstallError, match="must run as root"):
            metal.install(device="/dev/vda", hostname="metal-test", user="aaron")


class TestInstallFailurePaths:
    @pytest.fixture
    def attended(self, monkeypatch):
        """An install past every refusal, with the destructive half stubbed."""
        monkeypatch.setattr(metal.os, "geteuid", lambda: 0)
        monkeypatch.setattr(metal, "survey_target", lambda device: target_state())
        monkeypatch.setattr(metal, "confirm_wipe", lambda device: None)
        monkeypatch.setattr(
            metal,
            "prompt_metal_credentials",
            lambda user: ("user secret", "disk secret"),
        )
        monkeypatch.setattr(metal, "build_storage", self._refuse_to_build)
        return monkeypatch

    @staticmethod
    def _refuse_to_build(*_args):
        raise metal.InstallError("cryptsetup open failed (rc=1)")

    def test_storage_failure_still_detaches_the_target(self, attended, tmp_path):
        """`cryptsetup open` has attached the mapper before this can fail."""
        released = []
        attended.setattr(
            metal, "release_target", lambda root, vg: released.append((root, vg))
        )
        with pytest.raises(metal.InstallError, match="cryptsetup open"):
            metal.install(
                device="/dev/vda", hostname="metal-test", user="aaron", target=tmp_path
            )
        assert released == [(tmp_path, "metal-test")]

    def test_the_private_target_directory_does_not_outlive_the_run(
        self, attended, tmp_path
    ):
        owned = tmp_path / "metal-target-test"
        owned.mkdir()
        attended.setattr(metal.tempfile, "mkdtemp", lambda **_kwargs: str(owned))
        attended.setattr(metal, "release_target", lambda root, vg: None)
        with pytest.raises(metal.InstallError, match="cryptsetup open"):
            metal.install(device="/dev/vda", hostname="metal-test", user="aaron")
        assert not owned.exists()

    def test_a_disk_the_layout_cannot_fit_is_refused_before_the_prompt(self, attended):
        attended.setattr(
            metal, "survey_target", lambda device: target_state(disk_bytes=40 * GIB)
        )
        attended.setattr(
            metal,
            "confirm_wipe",
            lambda device: pytest.fail("confirmed an impossible layout"),
        )
        with pytest.raises(metal.InstallError, match="hibernation layout"):
            metal.install(device="/dev/vda", hostname="metal-test", user="aaron")
