#!/usr/bin/env python3
"""Read-only, fail-closed VY $060A TIO/data-aware disassembly audit.

ChatGPTz idea (AI-generated), inspired by the exact VX TIO FCB/FDB payload,
VY stock/Enhanced bank-3 bytes, and the full-image static IR draft #292.

Only classifies the known 2184-byte TIO region as encoded DATA. It does not
interpret proprietary TIO instructions, prove other ROM bytes are executable,
identify safe code caves, assemble firmware, or flash a PCM.
"""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import re

EXPECTED_IMAGES = {
    "750750d9a1250904b134af10e0d86d84daaa2a146f2946914f72ab8f0dcd2232": "92118883_STOCK",
    "5cb8bd1c61da37a3846b6c28600cdc21db3ceef0c764232d0cd7ec8d6e836abd": "ENHANCED_V1_0A",
    "d36a3e5e17d233b9f4b72f6b58c9f604f7ac6e1bfa57f7b408dcdf0998dc787d": "ENHANCED_V1_1A",
}
IMAGE_SIZE = 0x20000
BANK3_FILE_OFFSET = 0x10000
DATA_START = 0x1C3AF
DATA_END = 0x1CC37  # exclusive; CPU $CC37 is executable again
DATA_SHA256 = "a179b1b980023e0c07a03df2db3075c925653a003ddc5a68445ffd63f763457a"
SECTIONS = (
    ("tio_translation", 0x1C3AF, 0x1C3FF, "cc1ba5295e106c7a7791e8ebc05d68e5f0ba0ce41fe0c864a71aa70b6a6deb62"),
    ("tio_index", 0x1C3FF, 0x1C41F, "d97f95e82389b4e1bd2deec747f5e37a23ce683735c9c2cf69815b119f8030df"),
    ("tio_requests", 0x1C41F, 0x1C425, "921baec89dac2040734cda700f46485ca066b9b9c02510ddcf5c2c7fc103af36"),
    ("tio_register_initialisation", 0x1C425, 0x1C437, "2671d3718839f85300bcc88f4ebf68b99adc62b98a241283ee8070844de9d686"),
    ("tio_microcode", 0x1C437, 0x1CC37, "27a891e000f7f8aa782375b3f8df856e3c3aa6f0bf78a8bc75d0e83477d5cf13"),
)
STARTUP_ENTRY = (0x1CC37, bytes.fromhex("8d18bdcc782606bdccbcbdcd01bdcd75bdcd91bdcdb7bdce0b39"))
# Git object SHA is not a file SHA-256. Listing version is used for provenance,
# not as a substitute for the actual firmware image SHA-256.
EXPECTED_BANK3_LISTING_GIT_BLOB = "c32fd674db8f3ef289baab9f33e3c007ac7ae155"
CONTROL = frozenset({
    "bra", "brn", "bsr", "jmp", "jsr", "rts", "rti", "brset", "brclr",
    "bhi", "bls", "bcc", "bhs", "bcs", "blo", "bne", "beq", "bvc", "bvs",
    "bpl", "bmi", "bge", "blt", "bgt", "ble",
})
ENTRY_RE = re.compile(
    r"^L([0-9A-Fa-f]{4}):\s+((?:[0-9A-Fa-f]{2}\s+)+)([A-Za-z][A-Za-z0-9.]*)\s*(.*)$"
)
HEX_TARGET = re.compile(r"\$([0-9A-Fa-f]{4})\b")


def sha(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def image_audit(raw: bytes, filename: str = "<provided>") -> dict:
    if len(raw) != IMAGE_SIZE:
        raise ValueError(f"{filename}: expected {IMAGE_SIZE} bytes; got {len(raw)}")
    full = sha(raw)
    sections = [
        {"id": name, "file_start": f"0x{a:05X}", "file_end_exclusive": f"0x{b:05X}",
         "length": b-a, "sha256": sha(raw[a:b]), "expected_sha256": expected,
         "byte_identity_match": sha(raw[a:b]) == expected}
        for name, a, b, expected in SECTIONS
    ]
    entry_at, expected_entry = STARTUP_ENTRY
    observed = raw[entry_at:entry_at + len(expected_entry)]
    data_match = sha(raw[DATA_START:DATA_END]) == DATA_SHA256
    return {
        "path_label": filename, "size": len(raw), "sha256": full,
        "recognized_full_image": EXPECTED_IMAGES.get(full),
        "tio_data_sha256": sha(raw[DATA_START:DATA_END]),
        "tio_data_identical_to_source": data_match,
        "tio_sections": sections,
        "startup_entry_file_offset": f"0x{entry_at:05X}",
        "startup_entry_matches_exact_parent": observed == expected_entry,
        "startup_entry_preimage_hex": observed.hex(),
        "classification": "MATCH_KNOWN_IMAGE_AND_TIO" if full in EXPECTED_IMAGES and data_match and observed == expected_entry
             else "TIO_MATCH_BUT_IMAGE_UNRECOGNIZED" if data_match and observed == expected_entry
             else "UNQUALIFIED_TIO_BYTES",
        "proves": "exact static TIO bytes at protected offsets, not TIO behavior or executable free space",
    }


def git_blob_sha1(raw: bytes) -> str:
    return hashlib.sha1(f"blob {len(raw)}\0".encode("ascii") + raw).hexdigest()


def listing_audit(raw: bytes) -> dict:
    """Tag speculative rows of the historical linear-sweep *bank3-only* ASM.

    No branch/reachability analysis is performed. A row starting in a
    source-defined data section is not a CPU instruction regardless of what
    opcode mnemonics Capstone emits for those bytes.
    """
    text = raw.decode("utf-8", "replace")
    audit = {"total_decoded_rows": 0, "tio_data_rows_mislabelled_as_hc11": 0,
             "tio_data_bytes_covered": 0, "false_control_flow_rows": 0,
             "false_control_flow_by_mnemonic": {}, "straddling_rows": [],
             "other_listing_rows": 0, "section_rows": {},
             "direct_branch_into_data_candidates_from_outside": []}
    opcode_counts: Counter[str] = Counter()
    ranges: dict[str, int] = {name: 0 for name, *_ in SECTIONS}
    rows = []
    for line_num, line in enumerate(text.splitlines(), 1):
        match = ENTRY_RE.match(line)
        if not match:
            continue
        address = int(match[1], 16)
        parts = match[2].strip().split()
        mnemonic = match[3].lower()
        operand = match[4].strip()
        if not 0x8000 <= address < 0x10000:
            raise ValueError(f"non-bank3 CPU address in listing at line {line_num}: ${address:04X}")
        file_addr = BANK3_FILE_OFFSET + address
        if file_addr + len(parts) > IMAGE_SIZE:
            raise ValueError(f"decoded row exceeds file bounds at line {line_num}")
        rows.append((address, file_addr, len(parts), mnemonic, operand, line_num))
    for address, file_addr, width, mnemonic, operand, line_num in rows:
        audit["total_decoded_rows"] += 1
        if (file_addr < DATA_START < file_addr + width or
                file_addr < DATA_END < file_addr + width):
            audit["straddling_rows"].append({"line": line_num, "cpu": f"0x{address:04X}",
                                             "width": width})
        if DATA_START <= file_addr < DATA_END:
            audit["tio_data_rows_mislabelled_as_hc11"] += 1
            audit["tio_data_bytes_covered"] += width
            sec = next(n for n, lo, hi, _ in SECTIONS if lo <= file_addr < hi)
            ranges[sec] += 1
            if mnemonic in CONTROL:
                opcode_counts[mnemonic] += 1
        else:
            audit["other_listing_rows"] += 1
            if mnemonic in CONTROL and mnemonic not in {"rts", "rti"}:
                refs = HEX_TARGET.findall(operand)
                if refs:
                    target = int(refs[-1], 16)
                    # Raw operand evidence only. Indexed/computed transfers and
                    # illegitimate pseudo-instructions elsewhere remain unknown.
                    if DATA_START - BANK3_FILE_OFFSET <= target < DATA_END - BANK3_FILE_OFFSET:
                        audit["direct_branch_into_data_candidates_from_outside"].append(
                            {"line": line_num, "cpu": f"0x{address:04X}",
                             "target_cpu": f"0x{target:04X}", "mnemonic": mnemonic})
    audit["false_control_flow_by_mnemonic"] = dict(sorted(opcode_counts.items()))
    audit["false_control_flow_rows"] = sum(opcode_counts.values())
    audit["section_rows"] = ranges
    audit["listing_sha256"] = sha(raw)
    audit["listing_git_blob_sha1"] = git_blob_sha1(raw)
    audit["matches_known_bank3_git_blob"] = audit["listing_git_blob_sha1"] == EXPECTED_BANK3_LISTING_GIT_BLOB
    audit["status"] = "TIO_DATA_RECOGNIZED__OTHER_ROM_UNCLASSIFIED"
    return audit


def analyze(images: list[Path], listing: Path | None = None) -> dict:
    results = [image_audit(path.read_bytes(), str(path)) for path in images]
    if not results and listing is None:
        raise ValueError("provide at least one --image or a --bank3-listing")
    return {
        "schema": "kingai.vy060a.tio_data_fence.v1",
        "generated_by": "ChatGPTz idea - AI-generated source/data fencing",
        "run_mode": "READ_ONLY_NO_PATCH_NO_FLASH",
        "tio_protected": {"physical_start_inclusive": f"0x{DATA_START:05X}",
            "physical_end_exclusive": f"0x{DATA_END:05X}",
            "cpu_bank3_start": "0xC3AF", "cpu_bank3_end_exclusive": "0xCC37",
            "byte_count": DATA_END-DATA_START, "proves_unowned_rom": False},
        "images": results,
        "all_present_known_images_match": bool(results) and all(
            x["classification"] == "MATCH_KNOWN_IMAGE_AND_TIO" for x in results),
        "byte_identity_across_provided_images": len(results) > 1 and len({
            x["tio_data_sha256"] for x in results}) == 1,
        "listing": listing_audit(listing.read_bytes()) if listing else None,
        "unresolved": ["proprietary micro-op field semantics", "hardware ROM/RAM timing-engine selection",
            "indirect and computed TIO calls", "TIO output physical waveforms", "non-TIO code/data ownership",
            "physical flash bank-select latch and IRQ context"],
        "firmware_qualified": False, "safe_code_caves": [],
    }


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--image", type=Path, action="append", default=[], help="One or more exact 128KiB firmware images")
    p.add_argument("--bank3-listing", type=Path, help="Optional bank-3 listing (not other banks)")
    p.add_argument("--json", type=Path, help="Distinct new output JSON; input files never changed")
    args = p.parse_args()
    report = analyze(args.image, args.bank3_listing)
    output = json.dumps(report, indent=2, sort_keys=True) + "\n"
    if args.json:
        # Restrict outputs to new paths, preserve all originals.
        resolved = args.json.resolve()
        if resolved in {x.resolve() for x in args.image + ([args.bank3_listing] if args.bank3_listing else [])}:
            raise ValueError("JSON output may not overwrite an input")
        with resolved.open("x", encoding="utf-8") as f:
            f.write(output)
    else:
        print(output, end="")
    return 0 if report["all_present_known_images_match"] or not args.image else 2


if __name__ == "__main__":
    raise SystemExit(main())