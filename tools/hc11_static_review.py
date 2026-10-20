#!/usr/bin/env python3
"""Read-only HC11 byte/bank checks for explicitly bounded code regions.

This limited decoder is not an emulator or complete disassembler. It checks
boundaries and encoded control transfers under a supplied, unchanged bank
context; it cannot prove bank switching, caller behaviour or physical effects.
"""

from __future__ import annotations

import argparse
from hashlib import sha256
import json
from pathlib import Path
from typing import Sequence


SOURCE_SIZE = 0x20000
BANKS = ("bank1", "bank2", "bank3")
_BANK_HIGH_START = {"bank1": 0x08000, "bank2": 0x10000, "bank3": 0x18000}

# These are the only supported unprefixed encodings. Unknown instructions and
# all prebytes fail closed; no byte is silently treated as one-byte data/code.
_FIXED = {
    0x01: ("NOP", 1), 0x14: ("BSET direct", 3), 0x15: ("BCLR direct", 3),
    0x32: ("PULA", 1), 0x33: ("PULB", 1), 0x36: ("PSHA", 1),
    0x37: ("PSHB", 1), 0x39: ("RTS", 1), 0x3B: ("RTI", 1),
    0x81: ("CMPA immediate", 2), 0x85: ("BITA immediate", 2),
    0x86: ("LDAA immediate", 2), 0x96: ("LDAA direct", 2),
    0x97: ("STAA direct", 2), 0xB6: ("LDAA extended", 3),
    0xB7: ("STAA extended", 3), 0xCC: ("LDD immediate", 3),
    0xDC: ("LDD direct", 2), 0xDD: ("STD direct", 2),
    0xFC: ("LDD extended", 3), 0xFD: ("STD extended", 3),
}
_RELATIVE = dict(zip(range(0x20, 0x30), (
    "BRA", "BRN", "BHI", "BLS", "BCC", "BCS", "BNE", "BEQ",
    "BVC", "BVS", "BPL", "BMI", "BGE", "BLT", "BGT", "BLE",
)))
_RELATIVE[0x8D] = "BSR"


def _integer(value: int, label: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int):
        raise ValueError(f"{label} must be an integer")
    return value


def cpu_to_file(cpu: int, bank: str) -> int:
    """Resolve under an assumed active overlay, including common-region code."""
    _integer(cpu, "CPU address")
    if bank not in BANKS:
        raise ValueError("bank must be bank1, bank2 or bank3")
    if not 0 <= cpu <= 0xFFFF:
        raise ValueError("CPU address must be in 0x0000..0xFFFF")
    return cpu if cpu < 0x8000 else _BANK_HIGH_START[bank] + cpu - 0x8000


def file_to_cpu(offset: int, bank: str) -> int:
    """Refuse a file region not visible in the supplied caller bank context."""
    _integer(offset, "file offset")
    if bank not in BANKS:
        raise ValueError("bank must be bank1, bank2 or bank3")
    if not 0 <= offset < SOURCE_SIZE:
        raise ValueError("file offset must be in 0x00000..0x1FFFF")
    if offset < 0x8000:
        return offset
    high_start = _BANK_HIGH_START[bank]
    if high_start <= offset < high_start + 0x8000:
        return 0x8000 + offset - high_start
    raise ValueError(f"file offset 0x{offset:X} is not visible in {bank}")


def relative_target(cpu: int, length: int, operand: int) -> int:
    """PC after instruction plus its actual signed 8-bit operand, modulo 65536."""
    _integer(cpu, "CPU address")
    _integer(length, "instruction length")
    _integer(operand, "relative operand")
    if not 0 <= cpu <= 0xFFFF or length <= 0 or not 0 <= operand <= 0xFF:
        raise ValueError("invalid relative instruction address, length or operand")
    displacement = operand if operand < 0x80 else operand - 0x100
    return (cpu + length + displacement) & 0xFFFF


def review_code(data: bytes, *, file_offset: int, bank: str,
                code_length: int | None = None, cpu_start: int | None = None) -> dict:
    """Decode a bounded executable prefix; trailing bytes are explicit data.

    A mapped target outside decoded code remains unreviewed. No reachable-path
    or instruction semantics are inferred, including branch conditions.
    """
    if not isinstance(data, bytes):
        raise ValueError("data must be bytes")
    if not data or len(data) > SOURCE_SIZE:
        raise ValueError("region must contain 1..0x20000 bytes")
    origin = file_to_cpu(file_offset, bank)
    if cpu_start is not None:
        _integer(cpu_start, "CPU start")
        if cpu_start != origin:
            raise ValueError("CPU start disagrees with file offset and bank")
    if code_length is None:
        code_length = len(data)
    _integer(code_length, "code length")
    if not 1 <= code_length <= len(data):
        raise ValueError("code length must be in 1..region length")
    if file_offset + len(data) > SOURCE_SIZE:
        raise ValueError("region exceeds the 128 KiB file geometry")
    # Contiguous file bytes must not cross a discontinuity in the CPU mapping,
    # e.g. common $7FFF to bank2 $8000, or CPU $FFFF to common $0000.
    for index in range(len(data)):
        if cpu_to_file((origin + index) & 0xFFFF, bank) != file_offset + index:
            raise ValueError("region crosses a bank mapping discontinuity")

    instructions = []
    index = 0
    while index < code_length:
        opcode = data[index]
        kind = None
        if opcode in _RELATIVE:
            mnemonic, length, operand_index = _RELATIVE[opcode], 2, 1
            kind = "relative"
        elif opcode in (0x12, 0x13):
            mnemonic = "BRSET direct" if opcode == 0x12 else "BRCLR direct"
            length, operand_index, kind = 4, 3, "relative"
        elif opcode in (0x7E, 0xBD):
            mnemonic = "JMP extended" if opcode == 0x7E else "JSR extended"
            length, kind = 3, "absolute"
        elif opcode in _FIXED:
            mnemonic, length = _FIXED[opcode]
        else:
            raise ValueError(f"unsupported opcode 0x{opcode:02X} at file 0x{file_offset + index:X}")
        if index + length > code_length:
            raise ValueError(f"truncated {mnemonic} at file 0x{file_offset + index:X}")
        cpu = origin + index
        row = {
            "file_offset": file_offset + index, "cpu": cpu,
            "mnemonic": mnemonic, "length": length,
            "bytes": data[index:index + length].hex(" ").upper(),
        }
        if kind == "relative":
            operand = data[index + operand_index]
            row["displacement"] = operand if operand < 0x80 else operand - 0x100
            row["target_cpu"] = relative_target(cpu, length, operand)
        elif kind == "absolute":
            row["target_cpu"] = int.from_bytes(data[index + 1:index + 3], "big")
        if kind:
            row["target_file_offset"] = cpu_to_file(row["target_cpu"], bank)
        instructions.append(row)
        index += length

    boundaries = {row["file_offset"] for row in instructions}
    findings = []
    for row in instructions:
        if "target_file_offset" not in row:
            continue
        target = row["target_file_offset"]
        row["target_is_instruction_boundary"] = target in boundaries
        if target not in boundaries:
            if file_offset <= target < file_offset + code_length:
                code = "TARGET_INSIDE_INSTRUCTION"
            elif file_offset + code_length <= target < file_offset + len(data):
                code = "TARGET_IN_DECLARED_DATA"
            else:
                code = "TARGET_OUTSIDE_REVIEWED_CODE"
            findings.append({"code": code, "file_offset": row["file_offset"],
                             "target_file_offset": target})
    return {
        "schema": "kingai.hc11-static-review.v1",
        "status": "STATIC_FINDINGS" if findings else "STATIC_CHECKS_PASSED",
        "scope": "limited byte decoding and assumed bank mapping only",
        "bank_context": bank, "file_offset": file_offset, "cpu_start": origin,
        "code_length": code_length, "trailing_data_length": len(data) - code_length,
        "region_sha256": sha256(data).hexdigest(),
        "instructions": instructions, "findings": findings,
        "limitations": [
            "Supplied code/data boundaries and unchanged bank context are assumptions.",
            "No control-flow reachability, register, stack, timing or runtime approval.",
        ],
    }


def _number(value: str) -> int:
    try:
        return int(value, 0)
    except ValueError as error:
        raise argparse.ArgumentTypeError("use decimal or a 0x-prefixed integer") from error


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--hex", help="explicit region bytes, separated by spaces")
    source.add_argument("--input", type=Path, help="read-only full 128 KiB image")
    parser.add_argument("--file-offset", type=_number, required=True)
    parser.add_argument("--bank", choices=BANKS, required=True,
                        help="assumed unchanged caller bank, including for common code")
    parser.add_argument("--length", type=_number, help="bounded region length for --input")
    parser.add_argument("--code-length", type=_number,
                        help="executable prefix length; remaining region bytes are data")
    parser.add_argument("--cpu-start", type=_number, help="optional address consistency check")
    args = parser.parse_args(argv)
    try:
        source_digest = None
        if args.input is not None:
            if args.length is None or not 1 <= args.length <= SOURCE_SIZE:
                raise ValueError("--input requires --length in 1..0x20000")
            if not 0 <= args.file_offset < SOURCE_SIZE or args.file_offset + args.length > SOURCE_SIZE:
                raise ValueError("requested region exceeds the 128 KiB file geometry")
            with args.input.open("rb") as stream:
                image = stream.read(SOURCE_SIZE + 1)
            if len(image) != SOURCE_SIZE:
                raise ValueError("--input requires exactly 0x20000 bytes")
            source_digest = sha256(image).hexdigest()
            data = image[args.file_offset:args.file_offset + args.length]
        else:
            if args.length is not None:
                raise ValueError("--length is only used with --input")
            if len(args.hex) > SOURCE_SIZE * 3:
                raise ValueError("hex region is too large")
            data = bytes.fromhex(args.hex)
        report = review_code(data, file_offset=args.file_offset, bank=args.bank,
                             code_length=args.code_length, cpu_start=args.cpu_start)
        if source_digest is not None:
            report["input_sha256"] = source_digest
        print(json.dumps(report, indent=2, sort_keys=True))
        return 1 if report["findings"] else 0
    except (OSError, ValueError) as error:
        print(json.dumps({"status": "REFUSED", "error": str(error)}, sort_keys=True))
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
