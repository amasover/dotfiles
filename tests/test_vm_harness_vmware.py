"""vm-harness-vmware.ps1 on macOS: attended (VM_HARNESS_TARGET=work-vm) and
disposable runs, end to end against stubs (Story 5.8, #281).

Needs macOS and PowerShell 7 (`pwsh` on PATH, ~/.local/bin/pwsh, or
VM_HARNESS_PWSH), so it skips elsewhere: CI's Arch container has no pwsh, and
the driver's macOS branch only runs under $IsMacOS (Story 4.10, #133, owns
the runner/gating decision). The closest host-independent coverage is the
guest glue's attended clitest (tests/vm-harness-guest.clitest.txt).

The driver runs from a sandbox copy of .local/bin with the real
provision-seed (behind an argv/env recorder), vm-harness-vmx, display tool
and guest glue. VMware (vmrun, vdiskmanager), ssh and scp are shell stubs;
HOME is a fake home. No VM, network or real secret is involved.
"""

import json
import os
import shutil
import stat
import subprocess
import sys
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parent.parent


def _find_pwsh():
    for cand in (os.environ.get("VM_HARNESS_PWSH"), shutil.which("pwsh"),
                 str(Path.home() / ".local/bin/pwsh")):
        if cand and Path(cand).is_file() and os.access(cand, os.X_OK):
            return cand
    return None


PWSH = _find_pwsh()
pytestmark = pytest.mark.skipif(
    sys.platform != "darwin" or PWSH is None,
    reason="needs macOS and PowerShell 7 (the driver's $IsMacOS branch)",
)

USER_PW = "fake-user-pw-7Q2x"  # gitleaks:allow -- 2026-11-03: fake test password
LUKS_PW = "fake-disk-pw-9K4z"  # gitleaks:allow -- 2026-11-03: fake test password
TOKEN = "fake-token-ghp-0000000000000000"
GUEST_IP = "192.0.2.10"  # TEST-NET-1

RECORDER = """#!/usr/bin/env python3
import json, os, runpy, sys
rec = os.path.join(os.environ["FAKE_RECORD"], "provision-seed.jsonl")
with open(rec, "a") as f:
    f.write(json.dumps({"argv": sys.argv[1:], "env": {
        k: os.environ.get(k)
        for k in ("PROVISION_USER_PASSWORD", "PROVISION_LUKS_PASSWORD")}}) + "\\n")
real = os.path.join(os.path.dirname(os.path.abspath(__file__)), "provision-seed.real")
sys.argv[0] = real
runpy.run_path(real, run_name="__main__")
"""

# list: the running set; start: install writes the serial exit marker and
# "powers off" at once, boot keeps running; every call is logged.
VMRUN = r"""#!/bin/sh
printf '%s\n' "$*" >> "$FAKE_RECORD/vmrun.log"
state=$FAKE_RECORD/running
touch "$state"
case "$3" in
    list) echo "Total running VMs: $(wc -l < "$state" | tr -d ' ')"; cat "$state" ;;
    start)
        if [ "${FAKE_START:-install}" = install ]; then
            serial=$(sed -n 's/^serial0\.fileName = "\(.*\)"$/\1/p' "$4")
            printf 'HARNESS-RUNCMD-START\nHARNESS-ARCHINSTALL-EXIT:%s\n' "${FAKE_INSTALL_RC:-0}" > "$serial"
        else
            echo "$4" >> "$state"
        fi ;;
    getGuestIPAddress) echo 192.0.2.10 ;;
    stop | deleteVM) grep -vxF "$4" "$state" > "$state.new"; mv "$state.new" "$state" ;;
esac
exit 0
"""

# FAKE_VDISK=int: the user presses Ctrl-C while the disk is being created.
VDISK = """#!/bin/sh
printf '%s\\n' "$*" >> "$FAKE_RECORD/vdisk.log"
if [ "${FAKE_VDISK:-}" = int ]; then kill -INT "$PPID"; sleep 5; exit 130; fi
for last; do :; done
: > "$last"
"""

SSH = """#!/bin/sh
printf 'ssh' >> "$FAKE_RECORD/ssh.log"
for a; do printf ' <%s>' "$a" >> "$FAKE_RECORD/ssh.log"; done
printf '\\n' >> "$FAKE_RECORD/ssh.log"
case "$*" in *vm-harness-guest*) echo "GUEST-GLUE-RAN" ;; esac
exit 0
"""

SCP = """#!/bin/sh
printf 'scp' >> "$FAKE_RECORD/scp.log"
for a; do printf ' <%s>' "$a" >> "$FAKE_RECORD/scp.log"; done
printf '\\n' >> "$FAKE_RECORD/scp.log"
"""


def _exe(path: Path, text: str) -> None:
    path.write_text(text)
    path.chmod(path.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)


class Sandbox:
    def __init__(self, root: Path):
        self.root = root
        self.setup = root / "repo/.local/bin/setup"
        tools = root / "repo/.local/bin/tools"
        self.setup.mkdir(parents=True)
        tools.mkdir(parents=True)
        src = REPO / ".local/bin"
        for name in ("vm-harness-vmware.ps1", "vm-harness-vmx", "vm-harness-leases",
                     "vm-harness-guest"):
            shutil.copy2(src / "setup" / name, self.setup / name)
        shutil.copy2(src / "setup/provision-seed", self.setup / "provision-seed.real")
        _exe(self.setup / "provision-seed", RECORDER)
        shutil.copy2(src / "tools/vm-harness-display", tools / "vm-harness-display")

        self.record = root / "record"
        self.record.mkdir()
        self.vmware = root / "vmware"
        self.vmware.mkdir()
        _exe(self.vmware / "vmrun", VMRUN)
        _exe(self.vmware / "vmware-vdiskmanager", VDISK)
        self.bin = root / "bin"
        self.bin.mkdir()
        _exe(self.bin / "ssh", SSH)
        _exe(self.bin / "scp", SCP)

        self.work = root / "work"
        (self.work / "cache").mkdir(parents=True)
        (self.work / "cache/archlinux-aarch64.iso").write_bytes(b"iso")
        venv_bin = self.work / "venv/bin"
        venv_bin.mkdir(parents=True)
        _exe(venv_bin / "python3", f'#!/bin/sh\nexec "{sys.executable}" "$@"\n')

        self.home = root / "home"
        (self.home / ".ssh").mkdir(parents=True)
        (self.home / ".ssh/id_ed25519.pub").write_text("ssh-ed25519 AAAAhomekey me@mac\n")
        scratch = root / "scratch-key"
        scratch.mkdir()
        self.scratch_key = scratch / "id_ed25519"
        (scratch / "id_ed25519.pub").write_text("ssh-ed25519 AAAAscratchkey harness\n")
        self.token = self.home / ".config/dotfiles/github-token"
        self.trust = root / "trust"
        self.trust.mkdir()
        self.vms = root / "vms"

    def run(self, *args, attended=False, stdin="", **env):
        e = {
            "PATH": f"{self.bin}:/usr/bin:/bin:/usr/sbin:/sbin",
            "HOME": str(self.home),
            "TMPDIR": os.environ.get("TMPDIR", "/tmp"),
            "FAKE_RECORD": str(self.record),
            "VM_HARNESS_DIR": str(self.work),
            "VM_HARNESS_VMWARE_DIR": str(self.vmware),
            "VM_HARNESS_TRUST_DIR": str(self.trust),
            "VM_HARNESS_TIMEZONE": "UTC",
            "VM_HARNESS_SSH_KEY": str(self.scratch_key),
        }
        if attended:
            e["VM_HARNESS_TARGET"] = "work-vm"
            e["VM_HARNESS_VM_DIR"] = str(self.vms / "work-vm")
        e.update(env)
        return subprocess.run(
            [PWSH, "-NoProfile", "-File", str(self.setup / "vm-harness-vmware.ps1"), *args],
            input=stdin, capture_output=True, text=True, env=e, timeout=180,
        )

    def seed_calls(self):
        path = self.record / "provision-seed.jsonl"
        if not path.exists():
            return []
        return [json.loads(line) for line in path.read_text().splitlines()]

    def lines(self, name):
        path = self.record / name
        return path.read_text().splitlines() if path.exists() else []

    def logs_text(self, log_dir: Path):
        return "".join(p.read_text(errors="replace") for p in sorted(log_dir.glob("*.log")))

    def set_running(self, vmx: Path):
        (self.record / "running").write_text(f"{vmx}\n")


SECRETS = f"{USER_PW}\n{USER_PW}\n{LUKS_PW}\n{LUKS_PW}\n"


@pytest.fixture
def sb(tmp_path):
    return Sandbox(tmp_path)


def _attended_vm(sb):
    return sb.vms / "work-vm"


class TestDisposableUnchanged:
    def test_seed_command_line(self, sb):
        r = sb.run("seed")
        assert r.returncode == 0, r.stdout + r.stderr
        [call] = sb.seed_calls()
        assert call["argv"] == [
            "create", "--out", str(sb.work / "seed"), "--target", "vmware-aarch64",
            "--disk-size", "80", "--password", "vm", "--user", "aaron",
            "--pubkey", "ssh-ed25519 AAAAscratchkey harness", "--live-ssh",
        ]
        assert call["env"] == {"PROVISION_USER_PASSWORD": None, "PROVISION_LUKS_PASSWORD": None}

    def test_create_name_and_sizing(self, sb):
        r = sb.run("create")
        assert r.returncode == 0, r.stdout + r.stderr
        vmx = (sb.work / "vm/arch-harness.vmx").read_text()
        assert 'memsize = "12288"' in vmx and 'numvcpus = "8"' in vmx
        assert sb.lines("vdisk.log")[0].startswith("-c -s 80GB ")
        assert (sb.work / "seed/seed.iso").exists()

    def test_install_keeps_the_seed(self, sb):
        assert sb.run("create").returncode == 0
        r = sb.run("install")
        assert r.returncode == 0, r.stdout + r.stderr
        assert (sb.work / "seed/seed.iso").exists()
        assert "Seed deleted" not in r.stdout

    def test_bootstrap_unattended_without_token(self, sb):
        sb.token.parent.mkdir(parents=True)
        sb.token.write_text(TOKEN)
        assert sb.run("create").returncode == 0
        assert sb.run("install").returncode == 0
        sb.set_running(sb.work / "vm/arch-harness.vmx")
        r = sb.run("bootstrap")
        assert r.returncode == 0, r.stdout + r.stderr
        glue = [l for l in sb.lines("ssh.log") if "vm-harness-guest bootstrap" in l]
        assert glue == [
            "ssh <-t> <-o> <BatchMode=yes> <-o> <StrictHostKeyChecking=no> "
            "<-o> <UserKnownHostsFile=/dev/null> <-o> <LogLevel=ERROR> "
            f"<-i> <{sb.scratch_key}> <-o> <IdentitiesOnly=yes> <aaron@{GUEST_IP}> "
            "<bash vm-harness-guest bootstrap --class 'work-vm' "
            "--repo 'https://github.com/amasover/dotfiles.git'>"
        ]
        assert not any("github-token" in l for l in sb.lines("scp.log") + sb.lines("ssh.log"))

    def test_destroy_needs_no_confirmation(self, sb):
        assert sb.run("create").returncode == 0
        r = sb.run("destroy")
        assert r.returncode == 0, r.stdout + r.stderr
        assert not (sb.work / "vm").exists()


class TestAttendedSelection:
    def test_seed_target_name_and_sizing(self, sb):
        r = sb.run("create", attended=True, stdin=SECRETS)
        assert r.returncode == 0, r.stdout + r.stderr
        vm = _attended_vm(sb)
        vmx = (vm / "work-vm.vmx").read_text()
        assert 'displayName = "work-vm"' in vmx
        assert 'memsize = "12288"' in vmx and 'numvcpus = "10"' in vmx
        assert 'isolation.tools.dnd.disable = "TRUE"' in vmx
        assert sb.lines("vdisk.log")[0].startswith("-c -s 300GB ")
        [call] = sb.seed_calls()
        assert call["argv"][:6] == ["create", "--out", str(vm / "seed"), "--target",
                                    "work-vm", "--disk-size"]
        assert call["argv"][6] == "300"
        assert not (sb.work / "vm").exists()

    def test_name_override(self, sb):
        r = sb.run("create", attended=True, stdin=SECRETS, VM_HARNESS_NAME="work-vm-2",
                   VM_HARNESS_VM_DIR=str(sb.vms / "work-vm-2"))
        assert r.returncode == 0, r.stdout + r.stderr
        assert 'displayName = "work-vm-2"' in (sb.vms / "work-vm-2/work-vm-2.vmx").read_text()

    def test_name_ignored_when_disposable(self, sb):
        assert sb.run("create", VM_HARNESS_NAME="work-vm").returncode == 0
        assert (sb.work / "vm/arch-harness.vmx").exists()

    def test_shares_reach_the_vmx(self, sb):
        r = sb.run("create", attended=True, stdin=SECRETS,
                   VM_HARNESS_SHARES="vmshare=~/vmshare;Downloads=~/Downloads")
        assert r.returncode == 0, r.stdout + r.stderr
        vmx = (_attended_vm(sb) / "work-vm.vmx").read_text()
        assert f'sharedFolder0.hostPath = "{sb.home}/vmshare"' in vmx
        assert f'sharedFolder1.hostPath = "{sb.home}/Downloads"' in vmx
        assert 'sharedFolder.maxNum = "2"' in vmx

    @pytest.mark.parametrize("value", ["work-VM", "daily-vm", "yes"])
    def test_unknown_target_dies(self, sb, value):
        r = sb.run("status", VM_HARNESS_TARGET=value)
        assert r.returncode == 1
        assert "the only attended target is work-vm" in r.stdout
        assert not sb.seed_calls()


class TestAttendedSecrets:
    def test_passwords_reach_provision_seed_only_through_its_env(self, sb):
        r = sb.run("create", attended=True, stdin=SECRETS)
        assert r.returncode == 0, r.stdout + r.stderr
        [call] = sb.seed_calls()
        assert call["env"] == {"PROVISION_USER_PASSWORD": USER_PW,  # gitleaks:allow -- 2026-11-03: fake
                               "PROVISION_LUKS_PASSWORD": LUKS_PW}
        argv = " ".join(call["argv"])
        assert USER_PW not in argv and LUKS_PW not in argv
        assert "--password" not in call["argv"]
        # Install needs no ssh: the live ISO gets no root login.
        assert "--live-ssh" not in call["argv"]
        creds = json.loads((_attended_vm(sb) / "seed/user_credentials.json").read_text())
        assert creds["encryption_password"] == LUKS_PW

    def test_passwords_absent_from_output_and_logs(self, sb):
        r = sb.run("create", attended=True, stdin=SECRETS)
        assert r.returncode == 0
        text = r.stdout + r.stderr + sb.logs_text(_attended_vm(sb) / "logs")
        assert "=== create done rc=0" in text
        assert USER_PW not in text and LUKS_PW not in text

    def test_own_key_authorized_never_the_scratch_key(self, sb):
        r = sb.run("create", attended=True, stdin=SECRETS)
        assert r.returncode == 0
        [call] = sb.seed_calls()
        assert call["argv"][call["argv"].index("--pubkey") + 1] == "ssh-ed25519 AAAAhomekey me@mac"
        assert "VM_HARNESS_SSH_KEY ignored" in r.stdout

    def test_entries_must_match_twice(self, sb):
        stdin = f"a1\nb2\n{USER_PW}\n{USER_PW}\n\n\n{LUKS_PW}\n{LUKS_PW}\n"
        r = sb.run("create", attended=True, stdin=stdin)
        assert r.returncode == 0, r.stdout + r.stderr
        assert "the two entries differ — try again" in r.stdout
        assert "empty — try again" in r.stdout
        assert sb.seed_calls()[0]["env"]["PROVISION_USER_PASSWORD"] == USER_PW

    def test_closed_stdin_dies_before_any_seed(self, sb):
        r = sb.run("create", attended=True, stdin=f"{USER_PW}\n")
        assert r.returncode == 1
        assert not sb.seed_calls()
        assert not (_attended_vm(sb) / "work-vm.vmx").exists()


class TestAttendedSeedLifetime:
    def test_install_success_deletes_the_seed(self, sb):
        assert sb.run("create", attended=True, stdin=SECRETS).returncode == 0
        seed = _attended_vm(sb) / "seed"
        assert (seed / "seed.iso").exists()
        r = sb.run("install", attended=True)
        assert r.returncode == 0, r.stdout + r.stderr
        assert not seed.exists()
        assert "Seed deleted" in r.stdout
        assert 'sata0:0.present = "FALSE"' in (_attended_vm(sb) / "work-vm.vmx").read_text()

    def test_install_failure_deletes_the_seed_and_rerun_regenerates(self, sb):
        assert sb.run("create", attended=True, stdin=SECRETS).returncode == 0
        seed = _attended_vm(sb) / "seed"
        r = sb.run("install", attended=True, FAKE_INSTALL_RC="1")
        assert r.returncode == 1
        assert not seed.exists()
        assert "Seed deleted" in r.stdout
        # The re-run asks for both passwords again and rebuilds the seed.
        r = sb.run("install", attended=True, stdin=SECRETS)
        assert r.returncode == 0, r.stdout + r.stderr
        assert len(sb.seed_calls()) == 2
        assert not seed.exists()

    def test_up_resumes_a_dead_install_without_a_seed(self, sb):
        assert sb.run("create", attended=True, stdin=SECRETS).returncode == 0
        assert sb.run("install", attended=True, FAKE_INSTALL_RC="1").returncode == 1
        r = sb.run("up", attended=True)
        assert r.returncode == 1
        assert "died mid-install" in r.stdout


class TestAttendedBoot:
    def test_window_forced_and_disk_password_named(self, sb):
        assert sb.run("create", attended=True, stdin=SECRETS).returncode == 0
        assert sb.run("install", attended=True).returncode == 0
        r = sb.run("boot", attended=True, FAKE_START="boot", VM_HARNESS_GUI="0")
        assert r.returncode == 0, r.stdout + r.stderr
        start = [l for l in sb.lines("vmrun.log") if " start " in l][-1]
        assert start.endswith(" gui")
        assert "Type the disk (LUKS) password in the VMware window" in r.stdout
        assert "waiting up to 30 min" in r.stdout


class TestAttendedBootstrap:
    def _installed_running(self, sb):
        assert sb.run("create", attended=True, stdin=SECRETS).returncode == 0
        assert sb.run("install", attended=True).returncode == 0
        sb.set_running(_attended_vm(sb) / "work-vm.vmx")

    def test_token_copied_at_0600_never_printed(self, sb):
        sb.token.parent.mkdir(parents=True)
        sb.token.write_text(TOKEN)
        self._installed_running(sb)
        r = sb.run("bootstrap", attended=True)
        assert r.returncode == 0, r.stdout + r.stderr
        scp = [l for l in sb.lines("scp.log") if "github-token" in l]
        assert scp == [f"scp <-o> <BatchMode=yes> <-o> <StrictHostKeyChecking=no> "
                       f"<-o> <UserKnownHostsFile=/dev/null> <-o> <LogLevel=ERROR> <-q> "
                       f"<{sb.token}> <aaron@{GUEST_IP}:.config/dotfiles/github-token>"]
        ssh = sb.lines("ssh.log")
        assert any("umask 077" in l and ": > ~/.config/dotfiles/github-token" in l for l in ssh)
        assert any("chmod 600 ~/.config/dotfiles/github-token" in l for l in ssh)
        text = r.stdout + r.stderr + sb.logs_text(_attended_vm(sb) / "logs")
        assert TOKEN not in text
        assert "GitHub token: copied into the VM" in text

    def test_missing_token_is_skipped(self, sb):
        self._installed_running(sb)
        r = sb.run("bootstrap", attended=True)
        assert r.returncode == 0, r.stdout + r.stderr
        assert "GitHub token: none on the host" in r.stdout
        assert not any("github-token" in l for l in sb.lines("scp.log"))

    def test_glue_runs_attended_in_a_recorded_terminal_session(self, sb):
        self._installed_running(sb)
        r = sb.run("bootstrap", attended=True)
        assert r.returncode == 0, r.stdout + r.stderr
        glue = [l for l in sb.lines("ssh.log") if "vm-harness-guest bootstrap" in l]
        assert glue == [
            "ssh <-t> <-o> <BatchMode=yes> <-o> <StrictHostKeyChecking=no> "
            "<-o> <UserKnownHostsFile=/dev/null> <-o> <LogLevel=ERROR> "
            f"<aaron@{GUEST_IP}> <bash vm-harness-guest bootstrap --class 'work-vm' "
            "--repo 'https://github.com/amasover/dotfiles.git' --attended>"
        ]
        log = sb.logs_text(_attended_vm(sb) / "logs")
        # script(1) echoes ^D into the recording when stdin is no terminal (tests only).
        session = log.split("--- interactive guest session (recorded by script(1)):\n", 1)[1]
        assert "GUEST-GLUE-RAN" in session
        assert log.rstrip().endswith("=== bootstrap done rc=0")
        assert not list((_attended_vm(sb) / "logs").glob("*.session"))


class TestAttendedDestroyGuard:
    def test_refuses_without_confirmation(self, sb):
        assert sb.run("create", attended=True, stdin=SECRETS).returncode == 0
        r = sb.run("destroy", attended=True)
        assert r.returncode == 1
        assert "set VM_HARNESS_DESTROY_REAL=work-vm — nothing deleted" in r.stdout
        assert (_attended_vm(sb) / "work-vm.vmx").exists()

    def test_refuses_a_different_name(self, sb):
        assert sb.run("create", attended=True, stdin=SECRETS).returncode == 0
        r = sb.run("destroy", attended=True, VM_HARNESS_DESTROY_REAL="arch-harness")
        assert r.returncode == 1
        assert (_attended_vm(sb) / "work-vm.vmx").exists()

    def test_deletes_when_named(self, sb):
        assert sb.run("create", attended=True, stdin=SECRETS).returncode == 0
        r = sb.run("destroy", attended=True, VM_HARNESS_DESTROY_REAL="work-vm")
        assert r.returncode == 0, r.stdout + r.stderr
        assert not _attended_vm(sb).exists()


class TestAttendedNeverLosesTheDisk:
    """create never deletes what may be the real VM; destroy stays the only way."""

    def _lose_the_vmx(self, sb):
        assert sb.run("create", attended=True, stdin=SECRETS).returncode == 0
        vm = _attended_vm(sb)
        (vm / "work-vm.vmx").unlink()
        disk = vm / "disk.vmdk"
        disk.write_bytes(b"the real disk")
        return disk

    def test_create_refuses_a_dir_holding_a_disk(self, sb):
        disk = self._lose_the_vmx(sb)
        r = sb.run("create", attended=True, stdin=SECRETS)
        assert r.returncode == 1
        assert "already holds a VM (disk.vmdk) — create never overwrites it" in r.stdout
        assert disk.read_bytes() == b"the real disk"
        assert len(sb.seed_calls()) == 1  # no passwords asked, no new seed

    def test_up_resuming_at_create_keeps_the_disk(self, sb):
        disk = self._lose_the_vmx(sb)
        r = sb.run("up", attended=True, stdin=SECRETS)
        assert r.returncode == 1
        assert "already holds a VM (disk.vmdk)" in r.stdout
        assert disk.read_bytes() == b"the real disk"

    def test_failed_create_deletes_the_seed_keeps_the_disk(self, sb):
        # vm-harness-vmx rejects the empty share name after the disk exists:
        # the seed goes, the disk stays, and a re-run refuses to replace it.
        r = sb.run("create", attended=True, stdin=SECRETS, VM_HARNESS_SHARES="=~/x")
        assert r.returncode == 1
        vm = _attended_vm(sb)
        assert not (vm / "seed").exists()
        assert (vm / "disk.vmdk").exists()
        r = sb.run("create", attended=True, stdin=SECRETS)
        assert r.returncode == 1
        assert "already holds a VM (disk.vmdk)" in r.stdout


class TestAttendedSeedNeverLingers:
    def test_interrupted_create_deletes_the_seed(self, sb):
        r = sb.run("create", attended=True, stdin=SECRETS, FAKE_VDISK="int")
        # pwsh -File exits 0 after SIGINT; the missing rc trailer shows the stop.
        assert "=== create done" not in r.stdout
        assert "Seed deleted" in r.stdout
        assert sb.seed_calls()  # the seed was written before the interrupt
        assert not (_attended_vm(sb) / "seed").exists()

    def test_no_standalone_seed(self, sb):
        r = sb.run("seed", attended=True, stdin=SECRETS)
        assert r.returncode == 1
        assert "attended mode has no standalone seed" in r.stdout
        assert not sb.seed_calls()


class TestAttendedVmDir:
    def test_must_end_in_the_vm_name(self, sb):
        sb.vms.mkdir()
        sibling = sb.vms / "other-vm.txt"
        sibling.write_text("keep")
        r = sb.run("destroy", attended=True, VM_HARNESS_VM_DIR=str(sb.vms),
                   VM_HARNESS_DESTROY_REAL="work-vm")
        assert r.returncode == 1
        assert "must be the VM's own directory, ending in 'work-vm'" in r.stdout
        assert sibling.read_text() == "keep"

    def test_trailing_slash_is_fine(self, sb):
        r = sb.run("create", attended=True, stdin=SECRETS,
                   VM_HARNESS_VM_DIR=str(_attended_vm(sb)) + "/")
        assert r.returncode == 0, r.stdout + r.stderr
        assert (_attended_vm(sb) / "work-vm.vmx").exists()


def test_attended_prefers_id_ed25519(sb):
    (sb.home / ".ssh/id_ecdsa.pub").write_text("ecdsa-sha2-nistp256 AAAAecdsa me@mac\n")
    assert sb.run("create", attended=True, stdin=SECRETS).returncode == 0
    argv = sb.seed_calls()[0]["argv"]
    assert argv[argv.index("--pubkey") + 1] == "ssh-ed25519 AAAAhomekey me@mac"
