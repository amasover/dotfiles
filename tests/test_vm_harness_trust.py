"""pytest suite for vm-harness-trust (Story 2.36, #119). No gpg, no network."""

import io
import tarfile

import pytest

from conftest import load_tool

trust = load_tool("vm_harness_trust", "vm-harness-trust")


def _tar(entries, links=()):
    """A tar stream: entries is {name: bytes}; links is (name, target) symlinks."""
    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode="w") as tf:
        for name, data in entries.items():
            info = tarfile.TarInfo(name)
            info.size = len(data)
            tf.addfile(info, io.BytesIO(data))
        for name, target in links:
            info = tarfile.TarInfo(name)
            info.type = tarfile.SYMTYPE
            info.linkname = target
            tf.addfile(info)
    buf.seek(0)
    return buf


BASELINE = {
    ".local/state/aur-quarantine/maintainers.tsv": b"kube-capacity\t\nyay\tJguer\n",
    ".local/state/aur-quarantine/exempt.txt": b"yay\n",
}
# What the real archive also holds — must never land on disk.
SECRETS = {
    ".ssh/id_ed25519": b"PRIVATE KEY",
    ".ssh/config": b"Host internal",
    ".zshenv": b"export TOKEN=x",
}


class TestExtractMembers:
    def test_takes_the_trust_files(self, tmp_path):
        got = trust.extract_members(_tar(BASELINE), tmp_path)
        assert sorted(got) == sorted(BASELINE)
        assert (tmp_path / ".local/state/aur-quarantine/maintainers.tsv").read_bytes() \
            == BASELINE[".local/state/aur-quarantine/maintainers.tsv"]

    def test_leaves_every_other_member_on_the_floor(self, tmp_path):
        # The whole point: .ssh and .zshenv stay inside the archive.
        got = trust.extract_members(_tar({**SECRETS, **BASELINE}), tmp_path)
        assert sorted(got) == sorted(BASELINE)
        assert not (tmp_path / ".ssh").exists()
        assert not (tmp_path / ".zshenv").exists()

    def test_missing_member_is_not_an_error(self, tmp_path):
        only = {".local/state/aur-quarantine/maintainers.tsv":
                BASELINE[".local/state/aur-quarantine/maintainers.tsv"]}
        assert trust.extract_members(_tar(only), tmp_path) == list(only)

    def test_allowlist_blocks_a_traversal_name(self, tmp_path):
        # A hostile archive naming a path outside dest: the exact-match
        # allowlist never matches it, so nothing is written.
        hostile = {"../../../etc/passwd": b"root:x:0:0",
                   ".local/state/aur-quarantine/../../../evil": b"x"}
        assert trust.extract_members(_tar(hostile), tmp_path) == []
        assert list(tmp_path.iterdir()) == []

    def test_symlink_named_like_a_trust_file_is_skipped(self, tmp_path):
        # isfile() gates it — a symlink member could otherwise redirect a write.
        stream = _tar({}, links=[(".local/state/aur-quarantine/maintainers.tsv",
                                  "/etc/shadow")])
        assert trust.extract_members(stream, tmp_path) == []

    def test_writes_over_a_stale_baseline(self, tmp_path):
        p = tmp_path / ".local/state/aur-quarantine/maintainers.tsv"
        p.parent.mkdir(parents=True)
        p.write_bytes(b"old\tstate\n")
        trust.extract_members(_tar(BASELINE), tmp_path)
        assert p.read_bytes() == BASELINE[str(p.relative_to(tmp_path)).replace("\\", "/")]


class TestIntoDir:
    """--into writes basenames straight into the harness's trust dir, so
    `trust-import` and `bootstrap` can't disagree about where the files live."""

    def test_writes_basenames_into_the_directory(self, tmp_path):
        got = trust.extract_members(_tar(BASELINE), tmp_path, flat=True)
        assert sorted(got) == sorted(BASELINE)
        assert sorted(p.name for p in tmp_path.iterdir()) == \
            ["exempt.txt", "maintainers.tsv"]
        assert (tmp_path / "maintainers.tsv").read_bytes() == \
            BASELINE[".local/state/aur-quarantine/maintainers.tsv"]

    def test_allowlist_still_gates_the_flat_form(self, tmp_path):
        got = trust.extract_members(_tar({**SECRETS, **BASELINE}), tmp_path,
                                    flat=True)
        assert sorted(got) == sorted(BASELINE)
        assert not (tmp_path / "id_ed25519").exists()
        assert not (tmp_path / ".zshenv").exists()

    def test_member_path_cannot_escape_dest(self, tmp_path):
        # The name always comes from the allowlist, but assert the mapping
        # itself stays inside dest in both shapes.
        for name in trust.TRUST_MEMBERS:
            for flat in (False, True):
                p = trust.member_path(tmp_path, name, flat).resolve()
                assert p.is_relative_to(tmp_path.resolve())


class TestStaleMemberWarning:
    def _run(self, tmp_path, monkeypatch, entries, capsys):
        """main() with gpg stubbed out to emit a fixture tarball."""
        archive = tmp_path / "archive"
        archive.write_bytes(b"not really gpg input")
        into = tmp_path / "trust"
        into.mkdir(exist_ok=True)
        stream = _tar(entries)

        class _Proc:
            stdout = stream
            def wait(self): return 0
            def kill(self): pass

        monkeypatch.setattr(trust, "resolve_gpg", lambda explicit=None: "gpg")
        monkeypatch.setattr(trust.subprocess, "Popen",
                            lambda *a, **k: _Proc())
        rc = trust.main(["--archive", str(archive), "--into", str(into)])
        return rc, into, capsys.readouterr()

    def test_leftover_from_a_dropped_member_is_called_stale(
            self, tmp_path, monkeypatch, capsys):
        (tmp_path / "trust").mkdir()
        (tmp_path / "trust" / "exempt.txt").write_bytes(b"old\n")
        only_one = {".local/state/aur-quarantine/maintainers.tsv": b"a\tb\n"}
        rc, into, out = self._run(tmp_path, monkeypatch, only_one, capsys)
        assert rc == 0
        assert "WARNING" in out.err and "stale" in out.err
        # Untouched, deliberately — the warning is the contract, not a delete.
        assert (into / "exempt.txt").read_bytes() == b"old\n"

    def test_absent_member_with_no_leftover_is_only_a_note(
            self, tmp_path, monkeypatch, capsys):
        only_one = {".local/state/aur-quarantine/maintainers.tsv": b"a\tb\n"}
        rc, _, out = self._run(tmp_path, monkeypatch, only_one, capsys)
        assert rc == 0
        assert "WARNING" not in out.err
        assert "is not in the archive" in out.err

    def test_empty_archive_exits_nonzero(self, tmp_path, monkeypatch, capsys):
        rc, _, out = self._run(tmp_path, monkeypatch, SECRETS, capsys)
        assert rc == 1
        assert "nothing extracted" in out.err


class TestResolveGpg:
    def test_explicit_wins(self):
        assert trust.resolve_gpg(r"C:\custom\gpg.exe") == r"C:\custom\gpg.exe"

    def test_falls_back_to_path(self, monkeypatch):
        monkeypatch.setattr(trust.shutil, "which", lambda _: "/usr/bin/gpg")
        assert trust.resolve_gpg() == "/usr/bin/gpg"

    def test_no_gpg_anywhere_raises(self, monkeypatch):
        monkeypatch.setattr(trust.shutil, "which", lambda _: None)
        monkeypatch.setattr(trust, "_GPG_FALLBACKS", ())
        with pytest.raises(FileNotFoundError):
            trust.resolve_gpg()


class TestCli:
    def test_missing_archive_exits_nonzero(self, tmp_path, capsys):
        rc = trust.main(["--archive", str(tmp_path / "nope"), "--dest", str(tmp_path)])
        assert rc == 1
        assert "no archive at" in capsys.readouterr().err
