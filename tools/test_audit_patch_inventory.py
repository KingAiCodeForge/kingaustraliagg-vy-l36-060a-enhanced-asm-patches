"""Negative controls: a matching checksum is not code/bench approval."""
from pathlib import Path
import json
import tempfile
import unittest
from unittest import mock

try:
    from . import audit_patch_inventory as audit
    from .vy_flash_checksum import write_vxy_checksum
except ImportError:
    import audit_patch_inventory as audit
    from vy_flash_checksum import write_vxy_checksum


class PatchInventoryTests(unittest.TestCase):
    def setUp(self):
        self.source = bytes(0x20000)

    def test_reference_is_not_a_patch(self):
        row = audit.analyze_candidate(self.source, self.source)
        self.assertEqual(row["status"], "REFERENCE_NOT_A_PATCH")
        self.assertFalse(row["upload_eligible"])

    def test_checksum_does_not_approve_code(self):
        candidate = bytearray(self.source)
        candidate[0x5000] = 1
        write_vxy_checksum(candidate)
        row = audit.analyze_candidate(self.source, candidate)
        self.assertTrue(row["file_checksum"]["matches"])
        self.assertFalse(row["code_correctness_proven"])
        self.assertFalse(row["upload_eligible"])

    def test_known_bad_hash_survives_renaming(self):
        with mock.patch.dict(audit.KNOWN_HOLD, {audit.digest(self.source): "KNOWN_BAD_HOLD"}):
            self.assertEqual(audit.analyze_candidate(self.source, self.source)["status"], "KNOWN_BAD_HOLD")

    def test_short_image_is_not_padded(self):
        self.assertEqual(audit.analyze_candidate(self.source, b"short")["status"], "WRONG_SIZE_HOLD_NO_PADDING_OR_CROPPING")

    def test_bad_checksum_holds(self):
        candidate = bytearray(self.source)
        candidate[0x5000] = 1
        self.assertEqual(audit.analyze_candidate(self.source, candidate)["status"], "FILE_CHECKSUM_HOLD")

    def test_duplicates_and_no_absolute_paths(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "a.bin").write_bytes(self.source)
            (root / "b.BIN").write_bytes(self.source)
            report = audit.inventory(self.source, [root], 10, 100, 3)
            self.assertEqual(report["unique_payloads"], 1)
            self.assertEqual(report["duplicate_hashed_paths"], 1)
            self.assertNotIn(str(root), json.dumps(report))

    def test_file_limit_reports_partial(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in ("a.bin", "b.bin"):
                (root / name).write_bytes(self.source)
            self.assertEqual(audit.inventory(self.source, [root], 1, 100, 3)["coverage"], "partial")

    def test_cli_rejects_wrong_hash_before_outputs(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "source.bin"
            source.write_bytes(self.source)
            output = root / "out"
            with self.assertRaisesRegex(ValueError, "SHA-256"):
                audit.main(["--source", str(source), "--candidates", str(root), "--out-dir", str(output)])
            self.assertFalse(output.exists())

    def test_input_is_unchanged(self):
        before = audit.digest(self.source)
        audit.analyze_candidate(self.source, self.source)
        self.assertEqual(audit.digest(self.source), before)


if __name__ == "__main__":
    unittest.main()
