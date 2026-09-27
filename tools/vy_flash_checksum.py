#!/usr/bin/env python3
"""Check or repair the 128 KiB VX/VY flash-PCM file checksum.

OSE Enhanced Flash Tool v1.51's ALDLWriteBinCalVXYFlash implementation sums
bytes 0x02000 through 0x1FFFF modulo 65536, excludes 0x04000-0x04007, and
stores the result big-endian at 0x04006-0x04007.

This handles the file checksum only. It does not validate an OS, patch,
write procedure, recovery path, or PCM hardware.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

try:
    from .safe_outputs import validate_output_paths, write_outputs_exclusive
except ImportError:
    from safe_outputs import (  # type: ignore[no-redef]
        validate_output_paths,
        write_outputs_exclusive,
    )


EXPECTED_SIZE = 0x20000
CHECKSUM_START = 0x02000
CHECKSUM_SKIP_START = 0x04000
CHECKSUM_SKIP_END = 0x04008
CHECKSUM_OFFSET = 0x04006
CHECKSUM_END = 0x20000


def sha256_bytes(data: bytes | bytearray) -> str:
    return hashlib.sha256(data).hexdigest()


def require_vxy_size(data: bytes | bytearray) -> None:
    if len(data) != EXPECTED_SIZE:
        raise ValueError(
            f"expected a {EXPECTED_SIZE}-byte VX/VY image, got {len(data)} bytes"
        )


def calculate_vxy_checksum(data: bytes | bytearray) -> int:
    require_vxy_size(data)
    total = sum(data[CHECKSUM_START:CHECKSUM_SKIP_START])
    total += sum(data[CHECKSUM_SKIP_END:CHECKSUM_END])
    return total & 0xFFFF


def read_stored_vxy_checksum(data: bytes | bytearray) -> int:
    require_vxy_size(data)
    return (data[CHECKSUM_OFFSET] << 8) | data[CHECKSUM_OFFSET + 1]


def write_vxy_checksum(data: bytearray) -> int:
    checksum = calculate_vxy_checksum(data)
    data[CHECKSUM_OFFSET] = checksum >> 8
    data[CHECKSUM_OFFSET + 1] = checksum & 0xFF
    return checksum


def checksum_report(data: bytes | bytearray) -> dict[str, object]:
    calculated = calculate_vxy_checksum(data)
    stored = read_stored_vxy_checksum(data)
    return {
        "size": len(data),
        "sha256": sha256_bytes(data),
        "range": "0x02000-0x1FFFF excluding 0x04000-0x04007",
        "stored_offset": "0x04006-0x04007",
        "stored": f"0x{stored:04X}",
        "calculated": f"0x{calculated:04X}",
        "matches": stored == calculated,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input_bin", type=Path)
    parser.add_argument("--fix", type=Path, metavar="OUTPUT_BIN")
    parser.add_argument("--json", type=Path, dest="json_path")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    outputs = [path for path in (args.fix, args.json_path) if path is not None]
    validate_output_paths([args.input_bin], outputs)
    source = args.input_bin.read_bytes()
    report = checksum_report(source)
    payloads: list[tuple[Path, bytes | str]] = []

    if args.fix:
        fixed = bytearray(source)
        write_vxy_checksum(fixed)
        fixed_report = checksum_report(fixed)
        if not fixed_report["matches"]:
            raise AssertionError("checksum write did not validate")
        payloads.append((args.fix, bytes(fixed)))
        report["fixed_output"] = args.fix.name
        report["fixed"] = fixed_report

    if args.json_path:
        payloads.append((args.json_path, json.dumps(report, indent=2) + "\n"))

    write_outputs_exclusive(payloads)

    print(json.dumps(report, indent=2))
    return 0 if report["matches"] or args.fix else 1


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (FileExistsError, OSError, ValueError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1) from None
