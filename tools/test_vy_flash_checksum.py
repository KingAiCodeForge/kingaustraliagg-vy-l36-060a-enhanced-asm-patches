#!/usr/bin/env python3
"""Unit tests for the recovered VXY file checksum."""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

try:
    from . import vy_flash_checksum as checksum_cli
    from .vy_flash_checksum import (
        CHECKSUM_OFFSET,
        calculate_vxy_checksum,
        checksum_report,
        write_vxy_checksum,
    )
except ImportError:
    import vy_flash_checksum as checksum_cli  # type: ignore[no-redef]
    from vy_flash_checksum import (  # type: ignore[no-redef]
        CHECKSUM_OFFSET,
        calculate_vxy_checksum,
        checksum_report,
        write_vxy_checksum,
    )


class VyFlashChecksumTests(unittest.TestCase):
    def test_zero_image_round_trip(self) -> None:
        image = bytearray(0x20000)
        self.assertEqual(calculate_vxy_checksum(image), 0)
        self.assertEqual(write_vxy_checksum(image), 0)
        self.assertTrue(checksum_report(image)["matches"])

    def test_included_byte_changes_checksum(self) -> None:
        image = bytearray(0x20000)
        image[0x02000] = 0xA5
        self.assertEqual(calculate_vxy_checksum(image), 0xA5)

    def test_excluded_bytes_do_not_change_checksum(self) -> None:
        image = bytearray(0x20000)
        image[0x04000:0x04008] = b"\xFF" * 8
        self.assertEqual(calculate_vxy_checksum(image), 0)
        write_vxy_checksum(image)
        self.assertEqual(image[CHECKSUM_OFFSET : CHECKSUM_OFFSET + 2], b"\x00\x00")

    def test_wrong_size_is_rejected(self) -> None:
        with self.assertRaisesRegex(ValueError, "expected a 131072-byte"):
            calculate_vxy_checksum(b"\x00")

    def test_cli_writes_distinct_outputs_without_absolute_path_in_report(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            source = root / "source.bin"
            fixed = root / "fixed.bin"
            report_path = root / "report.json"
            source.write_bytes(bytes(0x20000))
            argv = [
                "vy_flash_checksum.py",
                str(source),
                "--fix",
                str(fixed),
                "--json",
                str(report_path),
            ]
            with mock.patch.object(sys, "argv", argv):
                self.assertEqual(checksum_cli.main(), 0)
            report = json.loads(report_path.read_text(encoding="utf-8"))
            self.assertEqual(report["fixed_output"], "fixed.bin")
            self.assertNotIn(str(root), report_path.read_text(encoding="utf-8"))
            self.assertTrue(checksum_report(fixed.read_bytes())["matches"])

    def test_cli_refuses_to_replace_its_input(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            source = Path(temp_dir) / "source.bin"
            original = bytes(0x20000)
            source.write_bytes(original)
            argv = ["vy_flash_checksum.py", str(source), "--fix", str(source)]
            with mock.patch.object(sys, "argv", argv):
                with self.assertRaisesRegex(ValueError, "must not overwrite an input"):
                    checksum_cli.main()
            self.assertEqual(source.read_bytes(), original)


if __name__ == "__main__":
    unittest.main()
