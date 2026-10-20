"""Synthetic tests only: no private source, firmware or assembler is required."""

from contextlib import redirect_stdout
from copy import deepcopy
from hashlib import sha256
from io import StringIO
import json
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest import mock

try:
    from . import verify_bench_bundle as verify
except ImportError:
    import verify_bench_bundle as verify


def differences(source, candidate):
    spans = []
    offset = 0
    while offset < len(source):
        if source[offset] == candidate[offset]:
            offset += 1
            continue
        start = offset
        while offset < len(source) and source[offset] != candidate[offset]:
            offset += 1
        spans.append({"offset": start, "before": source[start:offset].hex(),
                      "after": candidate[start:offset].hex()})
    return spans


def fixture():
    source = bytes(verify.SOURCE_SIZE)
    binary = bytearray(source)
    binary[0x10000:0x10004] = bytes((1, 2, 3, 4))
    checksum = (sum(binary[0x2000:0x4000]) + sum(binary[0x4008:])) & 0xFFFF
    binary[0x4006:0x4008] = checksum.to_bytes(2, "big")
    binary = bytes(binary)
    asm = b"; synthetic test bytes, not firmware\n"
    manifest = {
        "schema": verify.SCHEMA, "status": verify.STATUS,
        "source": {"size": verify.SOURCE_SIZE, "sha256": sha256(source).hexdigest()},
        "binary": {"path": "synthetic_WIP_BENCH_FLASH_ONLY.bin", "size": verify.SOURCE_SIZE,
                   "sha256": sha256(binary).hexdigest()},
        "asm": {"path": "synthetic_WIP_BENCH_FLASH_ONLY.asm", "sha256": sha256(asm).hexdigest()},
        "changes": differences(source, binary),
        "assembly": {"tool": "A09 V1.62", "tool_sha256": "a" * 64,
                     "regions": [{"file_offset": 0x10000, "size": 4,
                                  "sha256": sha256(binary[0x10000:0x10004]).hexdigest()}]},
        "qualification": dict(verify.QUALIFICATION),
        "known_limits": ["Synthetic static test; no physical execution."],
    }
    return manifest, source, binary, asm


class PureValidationTests(unittest.TestCase):
    def setUp(self):
        self.manifest, self.source, self.binary, self.asm = fixture()

    def validate(self, manifest=None, binary=None, asm=None):
        return verify._validate_bytes(
            self.manifest if manifest is None else manifest,
            self.binary if binary is None else binary,
            self.asm if asm is None else asm,
            _expected_source_sha256=sha256(self.source).hexdigest())

    def test_valid_synthetic_bundle_reconstructs_exact_parent(self):
        report = self.validate()
        self.assertEqual(report["static_checks"], "PASS")
        self.assertEqual(report["reconstructed_source_sha256"], sha256(self.source).hexdigest())
        self.assertEqual(report["file_checksum"]["stored"], 10)
        self.assertIn("assembler not rerun", report["assembly_evidence"])
        self.assertEqual(report["qualification"], verify.QUALIFICATION)

    def with_optional_metadata(self):
        manifest = deepcopy(self.manifest)
        manifest.update({"family": "SYNTHETIC", "profile": "control",
                         "purpose": "Tests of static bundle evidence.", "hooks": [],
                         "checksum": {"mode": "ADDITIVE_CORRECTED", "offset": 0x4006,
                                      "stored": 10, "calculated": 10},
                         "host_review": {"date": "2026-10-20", "tests": "Synthetic tests",
                                         "source_rebuild_byte_exact": True,
                                         "email_pack_member_manifest_checks": 0,
                                         "firmware_modified_during_intake": False}})
        manifest["source"]["firmware"] = "Synthetic bytes"
        manifest["assembly"]["addressed_bytes_matched"] = 4
        return manifest

    def test_optional_metadata_is_validated_and_disclosed_as_declared(self):
        report = self.validate(self.with_optional_metadata())
        self.assertEqual(report["declared_host_review"]["date"], "2026-10-20")
        self.assertIn("Declared metadata only", report["host_review_evidence"])
        self.assertIn("not independently rerun", report["host_review_evidence"])

    def test_optional_text_host_types_and_unknown_nested_flags_are_rejected(self):
        for field in ("family", "profile", "purpose"):
            manifest = self.with_optional_metadata()
            manifest[field] = 1
            with self.subTest(field=field), self.assertRaises(verify.BundleValidationError):
                self.validate(manifest)
        manifest = self.with_optional_metadata()
        manifest["source"]["firmware"] = None
        with self.assertRaises(verify.BundleValidationError):
            self.validate(manifest)
        for field, value in (("date", "2026-02-30"), ("date", "20261020"), ("tests", []),
                             ("source_rebuild_byte_exact", 1),
                             ("firmware_modified_during_intake", "false"),
                             ("email_pack_member_manifest_checks", True),
                             ("email_pack_member_manifest_checks", -1),
                             ("vehicle_approved", False)):
            manifest = self.with_optional_metadata()
            manifest["host_review"][field] = value
            with self.subTest(field=field, value=value):
                with self.assertRaises(verify.BundleValidationError):
                    self.validate(manifest)

    def test_publication_suffix_is_mandatory(self):
        manifest = deepcopy(self.manifest)
        manifest["binary"]["path"] = "synthetic.bin"
        manifest["asm"]["path"] = "synthetic.asm"
        with self.assertRaisesRegex(verify.BundleValidationError, "WIP_BENCH_FLASH_ONLY suffix"):
            self.validate(manifest)

    def test_checksum_metadata_must_match_actual_word_and_calculation(self):
        for field, value in (("mode", "UNVERIFIED"), ("offset", 0x4007),
                             ("stored", 11), ("calculated", 11), ("stored", True)):
            manifest = self.with_optional_metadata()
            manifest["checksum"][field] = value
            with self.subTest(field=field):
                with self.assertRaises(verify.BundleValidationError):
                    self.validate(manifest)

    def test_hook_bank_mappings_and_preimage_are_checked(self):
        manifest = self.with_optional_metadata()
        hooks = []
        for offset, cpu, bank in ((0x5D05, 0x5D05, 0), (0x10000, 0x8000, 2),
                                  (0x18000, 0x8000, 3)):
            hooks.append({"file_offset": offset, "cpu_address": cpu, "bank": bank,
                          "before": self.source[offset:offset + 1].hex(),
                          "after": self.binary[offset:offset + 1].hex(), "role": "synthetic hook"})
        manifest["hooks"] = hooks
        self.assertEqual(self.validate(manifest)["static_checks"], "PASS")
        for field, value in (("cpu_address", 0x8001), ("bank", 0), ("bank", 1),
                             ("bank", True), ("before", "ff"), ("after", "ff"),
                             ("before", "0000"), ("role", ""),
                             ("file_offset", verify.SOURCE_SIZE)):
            broken = deepcopy(manifest)
            broken["hooks"][1][field] = value
            with self.subTest(field=field, value=value):
                with self.assertRaises(verify.BundleValidationError):
                    self.validate(broken)
        manifest["hooks"] = [{"file_offset": 0x17FFF, "cpu_address": 0xFFFF, "bank": 2,
                              "before": "0000", "after": "0000", "role": "crosses bank"}]
        with self.assertRaisesRegex(verify.BundleValidationError, "file offset and bank"):
            self.validate(manifest)

    def test_regions_are_sorted_nonoverlapping_and_addressed_count_is_exact(self):
        manifest = self.with_optional_metadata()
        regions = [{"file_offset": offset, "size": 2,
                    "sha256": sha256(self.binary[offset:offset + 2]).hexdigest()}
                   for offset in (0x10000, 0x10002)]
        manifest["assembly"]["regions"] = regions
        self.assertEqual(self.validate(manifest)["static_checks"], "PASS")
        for value in (3, True, "4"):
            broken = deepcopy(manifest)
            broken["assembly"]["addressed_bytes_matched"] = value
            with self.subTest(count=value), self.assertRaises(verify.BundleValidationError):
                self.validate(broken)
        for invalid in (list(reversed(regions)), [regions[0], regions[0]]):
            broken = deepcopy(manifest)
            broken["assembly"]["regions"] = invalid
            with self.assertRaisesRegex(verify.BundleValidationError, "sorted and nonoverlapping"):
                self.validate(broken)

    def test_all_changed_bytes_need_assembly_hook_or_checksum_coverage(self):
        manifest = deepcopy(self.manifest)
        manifest["assembly"]["regions"] = [{"file_offset": 0x10000, "size": 2,
                                              "sha256": sha256(self.binary[0x10000:0x10002]).hexdigest()}]
        with self.assertRaisesRegex(verify.BundleValidationError, "not covered"):
            self.validate(manifest)
        manifest["hooks"] = [{"file_offset": 0x10002, "cpu_address": 0x8002, "bank": 2,
                              "before": "0000", "after": "0304", "role": "synthetic coverage"}]
        self.assertEqual(self.validate(manifest)["static_checks"], "PASS")

    def test_real_pin_cannot_be_replaced_through_manifest(self):
        with self.assertRaisesRegex(verify.BundleValidationError, "required exact source"):
            verify._validate_bytes(self.manifest, self.binary, self.asm)

    def test_schema_status_source_and_unknown_metadata_are_strict(self):
        cases = []
        for field, value in (("schema", "unknown"), ("status", "READY"),
                             ("known_limits", []), ("known_limits", [" "])):
            manifest = deepcopy(self.manifest)
            manifest[field] = value
            cases.append(manifest)
        for field, value in (("size", True), ("size", 42), ("sha256", "0" * 64)):
            manifest = deepcopy(self.manifest)
            manifest["source"][field] = value
            cases.append(manifest)
        manifest = deepcopy(self.manifest)
        manifest["flash_approved"] = True
        cases.append(manifest)
        for manifest in cases:
            with self.subTest(manifest=manifest):
                with self.assertRaises(verify.BundleValidationError):
                    self.validate(manifest)

    def test_qualification_flags_cannot_be_added_or_promoted(self):
        for flag in verify.QUALIFICATION:
            manifest = deepcopy(self.manifest)
            manifest["qualification"][flag] = not manifest["qualification"][flag]
            with self.subTest(flag=flag):
                with self.assertRaisesRegex(verify.BundleValidationError, "qualification"):
                    self.validate(manifest)
        for value in (1, 0, "false", None):
            manifest = deepcopy(self.manifest)
            manifest["qualification"]["hardware_execution"] = value
            with self.subTest(value=value):
                with self.assertRaises(verify.BundleValidationError):
                    self.validate(manifest)
        self.manifest["qualification"]["road_approved"] = False
        with self.assertRaisesRegex(verify.BundleValidationError, "unknown fields"):
            self.validate()

    def test_paths_are_portable_basenames_and_asm_must_match(self):
        for name in ("../escape.bin", "/absolute.bin", "nested/file.bin", r"nested\file.bin",
                     r"C:\absolute.bin", "C:relative.bin", "file.bin:stream", "CON.bin",
                     "file.bin ", "file.bin.", "*.bin", ".bin", "", "bad\x00.bin"):
            manifest = deepcopy(self.manifest)
            manifest["binary"]["path"] = name
            with self.subTest(name=name):
                with self.assertRaises(verify.BundleValidationError):
                    self.validate(manifest)
        for name in ("different.asm", "../synthetic.asm", "synthetic.asm:stream"):
            manifest = deepcopy(self.manifest)
            manifest["asm"]["path"] = name
            with self.subTest(name=name):
                with self.assertRaises(verify.BundleValidationError):
                    self.validate(manifest)

    def test_wrong_hashes_and_candidate_sizes_fail(self):
        for field in ("binary", "asm"):
            manifest = deepcopy(self.manifest)
            manifest[field]["sha256"] = "0" * 64
            with self.subTest(field=field):
                with self.assertRaisesRegex(verify.BundleValidationError, "SHA-256 mismatch"):
                    self.validate(manifest)
        for binary in (self.binary[:-1], self.binary + b"\x00"):
            with self.assertRaisesRegex(verify.BundleValidationError, "exactly 128 KiB"):
                self.validate(binary=binary)

    def test_known_hold_hashes_are_exact_and_checked_before_manifest_hash(self):
        self.assertEqual(len(verify.KNOWN_HOLD), 2)
        for held in verify.KNOWN_HOLD:
            self.assertEqual(len(held), 64)
            with self.subTest(held=held):
                with mock.patch.object(verify, "sha256") as digest:
                    digest.return_value.hexdigest.return_value = held
                    with self.assertRaisesRegex(verify.BundleValidationError, "known v60 HOLD"):
                        self.validate()

    def test_malformed_unsorted_overlapping_and_out_of_bounds_spans_fail(self):
        original = self.manifest["changes"]
        cases = [list(reversed(original)), [original[0], original[0]],
                 [{"offset": -1, "before": "00", "after": "00"}],
                 [{"offset": True, "before": "00", "after": "00"}],
                 [{"offset": verify.SOURCE_SIZE, "before": "00", "after": "00"}]]
        for field, value in (("before", ""), ("after", ""), ("before", "GG"),
                             ("before", "0000"), ("after", "0"), ("offset", "0x4007")):
            spans = deepcopy(original)
            spans[0][field] = value
            cases.append(spans)
        for spans in cases:
            manifest = deepcopy(self.manifest)
            manifest["changes"] = spans
            with self.subTest(spans=spans):
                with self.assertRaises(verify.BundleValidationError):
                    self.validate(manifest)

    def test_candidate_after_bytes_and_full_parent_preimage_are_checked(self):
        for field in ("after", "before"):
            manifest = deepcopy(self.manifest)
            data = bytearray.fromhex(manifest["changes"][0][field])
            data[0] ^= 0xFF
            manifest["changes"][0][field] = data.hex()
            with self.subTest(field=field):
                with self.assertRaisesRegex(verify.BundleValidationError,
                                            "after-bytes mismatch|reconstructed parent"):
                    self.validate(manifest)
        self.manifest["changes"] = self.manifest["changes"][:-1]
        with self.assertRaisesRegex(verify.BundleValidationError, "reconstructed parent"):
            self.validate()

    def test_checksum_is_independent_of_hash_and_reconstruction(self):
        candidate = bytearray(self.binary)
        candidate[0x4007] ^= 1
        candidate = bytes(candidate)
        self.manifest["binary"]["sha256"] = sha256(candidate).hexdigest()
        self.manifest["changes"] = differences(self.source, candidate)
        with self.assertRaisesRegex(verify.BundleValidationError, "checksum mismatch"):
            self.validate(binary=candidate)

    def test_every_declared_assembly_region_is_checked(self):
        for field, value in (("sha256", "0" * 64), ("size", 0), ("size", True),
                             ("file_offset", -1), ("file_offset", verify.SOURCE_SIZE)):
            manifest = deepcopy(self.manifest)
            manifest["assembly"]["regions"][0][field] = value
            with self.subTest(field=field, value=value):
                with self.assertRaises(verify.BundleValidationError):
                    self.validate(manifest)
        for field, value in (("tool", "other assembler"), ("tool_sha256", "x" * 64),
                             ("regions", [])):
            manifest = deepcopy(self.manifest)
            manifest["assembly"][field] = value
            with self.subTest(field=field):
                with self.assertRaises(verify.BundleValidationError):
                    self.validate(manifest)


class FileAndCommandTests(unittest.TestCase):
    def setUp(self):
        self.manifest, self.source, self.binary, self.asm = fixture()

    def write_bundle(self, root):
        path = root / "synthetic.json"
        path.write_text(json.dumps(self.manifest), encoding="utf-8")
        (root / self.manifest["binary"]["path"]).write_bytes(self.binary)
        (root / self.manifest["asm"]["path"]).write_bytes(self.asm)
        return path

    def test_public_validation_keeps_real_pin_and_does_not_modify_inputs(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = self.write_bundle(root)
            before = {item.name: item.read_bytes() for item in root.iterdir()}
            with self.assertRaisesRegex(verify.BundleValidationError, "required exact source"):
                verify.validate_bundle(path)
            self.assertEqual({item.name: item.read_bytes() for item in root.iterdir()}, before)

    def test_duplicate_json_fields_and_nonfinite_constants_fail(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "bad.json"
            for text in ('{"status":1,"status":2}', '{"value":NaN}'):
                path.write_text(text, encoding="utf-8")
                with self.assertRaises(verify.BundleValidationError):
                    verify.validate_bundle(path)

    def test_invalid_utf8_and_excessive_json_nesting_are_refused(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "bad.json"
            for raw in (b"\xff", b"[" * 2000 + b"0" + b"]" * 2000):
                path.write_bytes(raw)
                with self.assertRaises(verify.BundleValidationError):
                    verify.validate_bundle(path)

    def test_reads_are_capped_and_binary_size_is_exact(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / "oversized.json"
            path.write_bytes(b" " * (verify.MAX_MANIFEST_BYTES + 1))
            with self.assertRaisesRegex(verify.BundleValidationError, "size"):
                verify.validate_bundle(path)
            path = self.write_bundle(root)
            for size in (verify.SOURCE_SIZE - 1, verify.SOURCE_SIZE + 1):
                (root / self.manifest["binary"]["path"]).write_bytes(bytes(size))
                with self.assertRaisesRegex(verify.BundleValidationError, "size"):
                    verify.validate_bundle(path)

    def test_actual_symlink_is_refused_when_supported(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = self.write_bundle(root)
            link = root / "linked.json"
            try:
                link.symlink_to(path)
            except (OSError, NotImplementedError) as error:
                self.skipTest(f"symlink creation unavailable: {error}")
            with self.assertRaisesRegex(verify.BundleValidationError, "symlink or reparse"):
                verify.validate_bundle(link)

    def test_reparse_attribute_is_refused_before_open(self):
        info = SimpleNamespace(st_mode=stat.S_IFREG | 0o600, st_file_attributes=0x400)
        with mock.patch.object(Path, "lstat", return_value=info), mock.patch.object(verify.os, "open") as opened:
            with self.assertRaisesRegex(verify.BundleValidationError, "symlink or reparse"):
                verify._read_regular(Path("synthetic.json"), 1024)
            opened.assert_not_called()

    def invoke(self, args):
        stream = StringIO()
        with redirect_stdout(stream):
            status = verify.main(args)
        return status, json.loads(stream.getvalue())

    def test_cli_exit_codes_json_and_multiple_results(self):
        with mock.patch.object(verify, "validate_bundle", return_value={"static_checks": "PASS"}):
            status, report = self.invoke(["one.json", "two.json"])
            self.assertEqual(status, 0)
            self.assertTrue(report["ok"])
            self.assertEqual(len(report["results"]), 2)
        with mock.patch.object(verify, "validate_bundle", side_effect=verify.BundleValidationError("refused")):
            status, report = self.invoke(["one.json"])
            self.assertEqual(status, 1)
            self.assertFalse(report["ok"])
        for args in ([], ["--expected-source-sha256", "0" * 64], ["--unknown"]):
            status, report = self.invoke(args)
            self.assertEqual(status, 2)
            self.assertFalse(report["ok"])

    def test_import_is_quiet_and_actual_cli_only_prints_json(self):
        tool = Path(verify.__file__).resolve()
        script = "import sys; sys.path.insert(0, sys.argv[1]); import verify_bench_bundle"
        result = subprocess.run([sys.executable, "-B", "-c", script, str(tool.parent)],
                                capture_output=True, text=True, check=False)
        self.assertEqual((result.returncode, result.stdout, result.stderr), (0, "", ""))
        for args, code in (([], 2), (["missing.json"], 1), (["--help"], 0)):
            result = subprocess.run([sys.executable, "-B", str(tool), *args],
                                    capture_output=True, text=True, check=False)
            self.assertEqual(result.returncode, code)
            self.assertEqual(result.stderr, "")
            self.assertIsInstance(json.loads(result.stdout), dict)


if __name__ == "__main__":
    unittest.main()
