#!/usr/bin/env python3
"""Regression tests for the VY bank splitter's deterministic boundaries."""

import tempfile
import unittest
from contextlib import redirect_stdout
from io import StringIO
from pathlib import Path

try:
    from .split_and_disassemble import (
        SOURCE_SIZE,
        artifact_name,
        format_vector_entry,
        read_bin,
        split_bin,
    )
except ImportError:
    from split_and_disassemble import (  # type: ignore[no-redef]
        SOURCE_SIZE,
        artifact_name,
        format_vector_entry,
        read_bin,
        split_bin,
    )


class SplitAndDisassembleTests(unittest.TestCase):
    def test_artifact_name_is_stable_and_filesystem_safe(self):
        self.assertEqual(
            artifact_name(Path("VX VY_V6_$060A Enhanced v1.0a.bin")),
            "VX_VY_V6__060A_Enhanced_v1.0a",
        )

    def test_read_bin_requires_exact_128_kib(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "short.bin"
            path.write_bytes(bytes(SOURCE_SIZE - 1))
            with self.assertRaisesRegex(ValueError, "expected exactly 0x20000"):
                read_bin(path)

    def test_split_boundaries_reconstruct_the_source(self):
        source = bytes(index & 0xFF for index in range(SOURCE_SIZE))
        with tempfile.TemporaryDirectory() as temp_dir:
            with redirect_stdout(StringIO()):
                parts = split_bin(source, "fixture", Path(temp_dir))

            self.assertEqual([len(item[2]) for item in parts], [0x10000, 0x8000, 0x8000])
            self.assertEqual([item[3] for item in parts], [0x0000, 0x8000, 0x8000])
            self.assertEqual(b"".join(item[2] for item in parts), source)
            self.assertTrue(all(item[1].read_bytes() == item[2] for item in parts))

    def test_vector_word_is_not_decoded_as_an_opcode(self):
        bank = bytearray(0x10000)
        bank[0xFFEA:0xFFEC] = bytes.fromhex("20 0F")
        line = format_vector_entry(bank, 0, 0xFFEA)
        self.assertIn(".word    $200F", line)
        self.assertNotIn("bra", line.lower())


if __name__ == "__main__":
    unittest.main()
