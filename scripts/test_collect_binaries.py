"""Regression tests use dummy binary bytes, never wallet output."""
import hashlib
import json
import tempfile
import unittest
from pathlib import Path

from collect_binaries import TARGETS, collect

COMMIT = "a" * 40
GO_VERSION = "go1.27.1"


class CollectTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name)
        self.artifacts, self.output = root / "artifacts", root / "bin"
        self.artifacts.mkdir()
        for target in TARGETS:
            directory = self.artifacts / ("native-" + target)
            directory.mkdir()
            name = "coldwalletgenerator" + (".exe" if target.startswith("windows-") else "")
            data = ("dummy test binary: " + target).encode()
            (directory / name).write_bytes(data)
            (directory / "build-info.json").write_text(json.dumps({
                "source_commit": COMMIT, "target": target, "go_version": GO_VERSION,
                "sha256": hashlib.sha256(data).hexdigest(),
            }))
        self.first = self.artifacts / "native-linux-amd64"

    def run_collect(self):
        collect(self.artifacts, self.output, COMMIT, GO_VERSION)

    def assert_rejected(self):
        with self.assertRaises(ValueError):
            self.run_collect()
        self.assertFalse(self.output.exists())

    def test_all_six_are_copied_byte_for_byte(self):
        self.run_collect()
        self.assertEqual(len((self.output / "SHA256SUMS").read_text().splitlines()), 6)
        for target in TARGETS:
            for source in (self.artifacts / ("native-" + target)).iterdir():
                self.assertEqual(source.read_bytes(), (self.output / target / source.name).read_bytes())

    def test_modified_binary_is_rejected_before_output(self):
        (self.first / "coldwalletgenerator").write_bytes(b"modified")
        self.assert_rejected()

    def test_missing_binary_is_rejected(self):
        (self.first / "coldwalletgenerator").unlink()
        self.assert_rejected()

    def test_extra_file_is_rejected(self):
        (self.first / "unexpected.txt").write_text("dummy")
        self.assert_rejected()

    def test_wrong_source_target_and_toolchain_are_rejected(self):
        path = self.first / "build-info.json"
        original = json.loads(path.read_text())
        for field in ("source_commit", "target", "go_version"):
            with self.subTest(field=field):
                path.write_text(json.dumps(dict(original, **{field: "wrong"})))
                self.assert_rejected()
        path.write_text(json.dumps(original))

    def test_missing_target_is_rejected(self):
        import shutil
        shutil.rmtree(self.first)
        self.assert_rejected()

    def test_symlink_binary_is_rejected(self):
        binary = self.first / "coldwalletgenerator"
        saved = self.artifacts.parent / "saved-binary"
        binary.rename(saved)
        binary.symlink_to(saved)
        self.assert_rejected()

    def test_existing_output_is_not_modified_on_validation_failure(self):
        self.output.mkdir()
        sentinel = self.output / "keep.txt"
        sentinel.write_text("keep")
        (self.first / "coldwalletgenerator").write_bytes(b"modified")
        with self.assertRaises(ValueError):
            self.run_collect()
        self.assertEqual([p.name for p in self.output.iterdir()], ["keep.txt"])
        self.assertEqual(sentinel.read_text(), "keep")


if __name__ == "__main__":
    unittest.main()
