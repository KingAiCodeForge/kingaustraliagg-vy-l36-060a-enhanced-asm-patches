"""Synthetic, fixture-free checks for bounded HC11 analysis and retired reports."""

from contextlib import redirect_stdout
from hashlib import sha256
from io import StringIO
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

try:
    from . import hc11_static_review as review
except ImportError:
    import hc11_static_review as review


TOOLS = Path(review.__file__).resolve().parent


class BankMappingTests(unittest.TestCase):
    def test_each_window_boundary_and_inverse(self):
        for bank, high in (("bank1", 0x8000), ("bank2", 0x10000), ("bank3", 0x18000)):
            for cpu, offset in ((0, 0), (0x7FFF, 0x7FFF),
                                (0x8000, high), (0xFFFF, high + 0x7FFF)):
                with self.subTest(bank=bank, cpu=cpu):
                    self.assertEqual(review.cpu_to_file(cpu, bank), offset)
                    self.assertEqual(review.file_to_cpu(offset, bank), cpu)

    def test_bank2_hook_and_c500_mapping(self):
        self.assertEqual(review.file_to_cpu(0x101E1, "bank2"), 0x81E1)
        result = review.review_code(bytes.fromhex("BD C5 00"),
                                    file_offset=0x101E1, bank="bank2")
        call = result["instructions"][0]
        self.assertEqual(call["cpu"], 0x81E1)
        self.assertEqual(call["target_file_offset"], 0x14500)
        self.assertEqual(result["findings"][0]["code"], "TARGET_OUTSIDE_REVIEWED_CODE")

    def test_common_code_keeps_caller_bank_for_high_calls(self):
        for bank, target in (("bank1", 0x0C500), ("bank2", 0x14500), ("bank3", 0x1C500)):
            with self.subTest(bank=bank):
                result = review.review_code(bytes.fromhex("BD C5 00 39"),
                                            file_offset=0x5D05, bank=bank)
                self.assertEqual(result["instructions"][0]["target_file_offset"], target)

    def test_unknown_bank_wrong_overlay_and_bad_addresses_refused(self):
        for function, args in (
            (review.cpu_to_file, (0xC500, "unknown")),
            (review.cpu_to_file, (-1, "bank2")),
            (review.cpu_to_file, (0x10000, "bank2")),
            (review.file_to_cpu, (0xC500, "bank2")),
            (review.file_to_cpu, (0x10000, "bank1")),
            (review.file_to_cpu, (0x20000, "bank3")),
            (review.file_to_cpu, (True, "bank1")),
        ):
            with self.subTest(function=function.__name__, args=args):
                with self.assertRaises(ValueError):
                    function(*args)

    def test_regions_cannot_cross_mapping_discontinuities(self):
        for offset, bank in ((0x7FFF, "bank2"), (0xFFFF, "bank1"),
                             (0x17FFF, "bank2"), (0x1FFFF, "bank3")):
            with self.subTest(offset=offset, bank=bank):
                with self.assertRaises(ValueError):
                    review.review_code(b"\x01\x01", file_offset=offset, bank=bank)
        self.assertFalse(review.review_code(b"\x01\x01", file_offset=0x7FFF,
                                            bank="bank1")["findings"])


class RelativeAndBoundaryTests(unittest.TestCase):
    def test_signed_extremes_zero_and_cpu_wrap(self):
        for cpu, length, operand, expected in (
            (0x1000, 2, 0x00, 0x1002), (0x1000, 2, 0x7F, 0x1081),
            (0x1000, 2, 0x80, 0x0F82), (0x1000, 2, 0xFF, 0x1001),
            (0xFFFF, 2, 0x00, 0x0001), (0x0000, 2, 0xFD, 0xFFFF),
        ):
            with self.subTest(cpu=cpu, operand=operand):
                self.assertEqual(review.relative_target(cpu, length, operand), expected)

    def test_forward_backward_and_zero_targets_use_encoded_operands(self):
        for code, branch_index, target in (
            ("20 01 01 39", 0, 0x8003),
            ("01 26 FD 39", 1, 0x8000),
            ("20 00 39", 0, 0x8002),
        ):
            with self.subTest(code=code):
                result = review.review_code(bytes.fromhex(code), file_offset=0x10000, bank="bank2")
                self.assertEqual(result["instructions"][branch_index]["target_cpu"], target)
                self.assertFalse(result["findings"])

    def test_relative_branch_family_and_bsr_have_two_byte_lengths(self):
        for opcode in (*range(0x20, 0x30), 0x8D):
            with self.subTest(opcode=opcode):
                result = review.review_code(bytes((opcode, 0, 0x39)),
                                            file_offset=0x10000, bank="bank2")
                self.assertEqual(result["instructions"][0]["length"], 2)
                self.assertEqual(result["instructions"][0]["target_cpu"], 0x8002)

    def test_bit_branch_uses_four_bytes_and_last_operand(self):
        for code, index, expected in (("12 20 FD 01 01 39", 0, 0x8005),
                                      ("01 13 46 80 FB 39", 1, 0x8000)):
            with self.subTest(code=code):
                result = review.review_code(bytes.fromhex(code), file_offset=0x10000, bank="bank2")
                self.assertEqual(result["instructions"][index]["length"], 4)
                self.assertEqual(result["instructions"][index]["target_cpu"], expected)
                self.assertFalse(result["findings"])

    def test_operand_mutation_changes_result_and_cannot_keep_false_pass(self):
        good = review.review_code(bytes.fromhex("20 02 81 00 39"),
                                  file_offset=0x10000, bank="bank2")
        bad = review.review_code(bytes.fromhex("20 01 81 00 39"),
                                 file_offset=0x10000, bank="bank2")
        self.assertEqual(good["status"], "STATIC_CHECKS_PASSED")
        self.assertEqual(bad["instructions"][0]["target_cpu"], 0x8003)
        self.assertEqual(bad["findings"][0]["code"], "TARGET_INSIDE_INSTRUCTION")

    def test_opcode_valued_operands_are_never_scanned_as_instructions(self):
        result = review.review_code(bytes.fromhex("86 FD CC 20 00 39"),
                                    file_offset=0x10000, bank="bank2")
        self.assertEqual([row["mnemonic"] for row in result["instructions"]],
                         ["LDAA immediate", "LDD immediate", "RTS"])
        self.assertFalse(result["findings"])

    def test_declared_data_is_not_decoded_or_accepted_as_a_branch_boundary(self):
        result = review.review_code(bytes.fromhex("20 00 4A 4B 26 02"),
                                    code_length=2, file_offset=0x10000, bank="bank2")
        self.assertEqual(len(result["instructions"]), 1)
        self.assertEqual(result["trailing_data_length"], 4)
        self.assertEqual(result["findings"][0]["code"], "TARGET_IN_DECLARED_DATA")

    def test_external_branch_is_unreviewed_even_with_known_mapping(self):
        result = review.review_code(bytes.fromhex("20 7F"),
                                    file_offset=0x10000, bank="bank2")
        self.assertEqual(result["instructions"][0]["target_file_offset"], 0x10081)
        self.assertEqual(result["findings"][0]["code"], "TARGET_OUTSIDE_REVIEWED_CODE")

    def test_unsupported_prebytes_unknown_opcodes_and_truncation_fail_closed(self):
        for code in ("18", "1A", "CD", "02", "CC 00", "BD C5", "12 46 80", "20"):
            with self.subTest(code=code):
                with self.assertRaises(ValueError):
                    review.review_code(bytes.fromhex(code), file_offset=0x10000, bank="bank2")
        with self.assertRaisesRegex(ValueError, "truncated"):
            review.review_code(bytes.fromhex("20 00 39"), code_length=1,
                               file_offset=0x10000, bank="bank2")

    def test_empty_invalid_length_and_conflicting_origin_are_refused(self):
        for data, extra in ((b"", {}), (b"\x39", {"code_length": 0}),
                            (b"\x39", {"code_length": 2}),
                            (b"\x39", {"code_length": True}),
                            (b"\x39", {"cpu_start": 0xA1E1})):
            with self.subTest(extra=extra):
                with self.assertRaises(ValueError):
                    review.review_code(data, file_offset=0x101E1, bank="bank2", **extra)


class CommandAndRetirementTests(unittest.TestCase):
    def invoke(self, *args):
        stream = StringIO()
        with redirect_stdout(stream):
            status = review.main(list(args))
        return status, json.loads(stream.getvalue())

    def test_cli_exit_codes_distinguish_pass_findings_and_refusal(self):
        for code, expected, status in (("20 00 39", 0, "STATIC_CHECKS_PASSED"),
                                       ("20 7F", 1, "STATIC_FINDINGS"),
                                       ("18", 2, "REFUSED")):
            with self.subTest(code=code):
                result, report = self.invoke("--hex", code, "--file-offset", "0x10000", "--bank", "bank2")
                self.assertEqual(result, expected)
                self.assertEqual(report["status"], status)

    def test_actual_cli_exit_status_and_required_bank(self):
        command = [sys.executable, "-B", str(TOOLS / "hc11_static_review.py"),
                   "--hex", "20 7F", "--file-offset", "0x10000"]
        result = subprocess.run([*command, "--bank", "bank2"],
                                capture_output=True, text=True, check=False)
        self.assertEqual(result.returncode, 1)
        self.assertEqual(json.loads(result.stdout)["status"], "STATIC_FINDINGS")
        missing_bank = subprocess.run(command, capture_output=True, text=True, check=False)
        self.assertEqual(missing_bank.returncode, 2)
        self.assertIn("--bank", missing_bank.stderr)

    def test_full_synthetic_input_is_unchanged_and_no_output_file_is_created(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "synthetic.bin"
            image = bytearray(review.SOURCE_SIZE)
            image[0x10000:0x10003] = bytes.fromhex("20 00 39")
            source = bytes(image)
            path.write_bytes(source)
            before = set(path.parent.iterdir())
            status, report = self.invoke("--input", str(path), "--length", "3",
                                         "--file-offset", "0x10000", "--bank", "bank2")
            self.assertEqual(status, 0)
            self.assertEqual(report["input_sha256"], sha256(source).hexdigest())
            self.assertEqual(path.read_bytes(), source)
            self.assertEqual(set(path.parent.iterdir()), before)

    def test_input_size_missing_length_and_bad_hex_are_refused(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "synthetic.bin"
            for size in (review.SOURCE_SIZE - 1, review.SOURCE_SIZE + 1):
                path.write_bytes(bytes(size))
                status, _report = self.invoke("--input", str(path), "--length", "1",
                                             "--file-offset", "0", "--bank", "bank1")
                self.assertEqual(status, 2)
            status, _report = self.invoke("--input", str(path), "--file-offset", "0", "--bank", "bank1")
            self.assertEqual(status, 2)
        status, _report = self.invoke("--hex", "not hex", "--file-offset", "0", "--bank", "bank1")
        self.assertEqual(status, 2)

    def test_imports_are_silent(self):
        for name in ("hc11_static_review", "analyze_v38_patch", "verify_v38_offsets"):
            with self.subTest(name=name):
                script = "import sys; sys.path.insert(0, sys.argv[1]); __import__(sys.argv[2])"
                result = subprocess.run([sys.executable, "-B", "-c", script, str(TOOLS), name],
                                        capture_output=True, text=True, check=False)
                self.assertEqual(result.returncode, 0)
                self.assertEqual(result.stdout, "")
                self.assertEqual(result.stderr, "")

    def test_retired_reports_always_refuse_without_reading_or_writing_firmware(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in ("analyze_v38_patch.py", "verify_v38_offsets.py"):
                with self.subTest(name=name):
                    output = root / "must-not-exist.bin"
                    result = subprocess.run([sys.executable, "-B", str(TOOLS / name),
                                             str(root / "missing.bin"), str(output)],
                                            cwd=root, capture_output=True, text=True, check=False)
                    self.assertEqual(result.returncode, 2)
                    self.assertEqual(result.stdout, "")
                    self.assertIn("REFUSED", result.stderr)
                    self.assertFalse(output.exists())
                    self.assertEqual(list(root.iterdir()), [])


if __name__ == "__main__":
    unittest.main()
