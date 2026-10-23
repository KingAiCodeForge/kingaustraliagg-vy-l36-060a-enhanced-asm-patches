"""Read-only, fail-closed VY $060A Enhanced v1.0a zero-ROM interval classifier.

Byte emptiness is NOT executable-free-space proof. Never emits linker EQU,
trampolines, candidate BINs or patch instructions.
"""
from __future__ import annotations

import argparse
from dataclasses import dataclass
import hashlib
import json
import os
from pathlib import Path
import sys
import tempfile

EXPECTED_SHA256 = "5cb8bd1c61da37a3846b6c28600cdc21db3ceef0c764232d0cd7ec8d6e836abd"
IMAGE_SIZE = 0x20000
FUEL_CUT_START = 0x77DE
FUEL_CUT_BYTES = bytes.fromhex("ecebecebeceb")
NATIVE_FUEL_POINTER = bytes.fromhex("ce77de")
NATIVE_PTR_FILE = 0x12582


@dataclass(frozen=True)
class Candidate:
    name: str
    start: int
    end: int   # file-offset-exclusive
    region: str
    disposition: str
    risk: str

    @property
    def size(self) -> int:
        return self.end - self.start


CANDIDATES = (
    Candidate("common_zero_tail", 0x3E87, 0x3FE2, "COMMON_ROM",
              "UNKNOWN_NOT_APPROVED",
              "May contain indirect/vector/loader/metadata dependencies; only 347 bytes"),
    Candidate("bank1_long_zero_span", 0x0C468, 0x0FFC0, "BANK1_PAGED_ROM",
              "UNKNOWN_NOT_APPROVED",
              "No proof of executable reachability from bank2/3 IRQ context; bank switching is unresolved"),
    Candidate("SC01_old_handler_overlap", 0x05D05, 0x05E52, "COMMON_CAL_OR_DATA",
              "REJECT_NATIVE_CONSUMER_OVERLAP",
              "The native F61AG/LPG data path intersects the handler allocation"),
    Candidate("SC01_old_parameters_overlap", 0x05EF0, 0x05EF5, "COMMON_CAL_OR_DATA",
              "REJECT_NATIVE_VSR_OVERLAP",
              "Both VSR curves have real conditional consumers; disabled image also changes them"),
    Candidate("common_cal_383", 0x6559, 0x66D8, "COMMON_CAL_OR_DATA",
              "REJECT_NATIVE_DIRECT_OPERANDS",
              "Native bank2 routines read $6559/$66CC and point to $655A/$6605/$66CD"),
    Candidate("common_cal_306", 0x5117, 0x5249, "COMMON_CAL_OR_DATA",
              "REJECT_XDF_CALIBRATION_OBJECTS",
              "14 TunerPro XDF transmission torque-reduction table starts lie inside"),
    Candidate("bank2_zero_tail", 0x17E87, 0x17FC0, "BANK2_PAGED_ROM",
              "UNKNOWN_NOT_APPROVED",
              "Native M42 tail and bank2 vectors nearby; IRQ/bank owner not closed"),
    Candidate("bank3_long_zero_tail", 0x1CE3F, 0x1FFB2, "BANK3_PAGED_ROM",
              "UNKNOWN_NOT_APPROVED",
              "Bank3 diagnostics/transmission and computed entries not closed"),
    Candidate("bank3_large_zero_gap", 0x19B0B, 0x1C000, "BANK3_PAGED_ROM",
              "UNKNOWN_NOT_APPROVED",
              "Bank3 calibration/pointer consumers and mode reachability not closed"),
    Candidate("bank3_tio_zero_span", 0x1CA57, 0x1CBB7, "BANK3_TIO_PROTECTED",
              "REJECT_TIO_IMAGE",
              "Within the original bank3 2048-byte TIO image; zeros not code cave"),
    Candidate("common_cal_226", 0x7151, 0x7233, "COMMON_CAL_OR_DATA",
              "UNKNOWN_NOT_APPROVED", "Calibration interval has no global native reader exclusion"),
    Candidate("common_cal_136", 0x5C31, 0x5CB9, "COMMON_CAL_OR_DATA",
              "UNKNOWN_NOT_APPROVED", "Adjacent known F61AG/LPG paths; no global exclusion"),
    Candidate("common_cal_99", 0x5F27, 0x5F8A, "COMMON_CAL_OR_DATA",
              "UNKNOWN_NOT_APPROVED", "Native calibration/mode/lookup consumers not exhausted"),
    Candidate("common_cal_86", 0x7E54, 0x7EAA, "COMMON_CAL_OR_DATA",
              "UNKNOWN_NOT_APPROVED", "Near native calibration and diagnostic bytes"),
    Candidate("common_80", 0x2030, 0x2080, "COMMON_ROM",
              "UNKNOWN_NOT_APPROVED", "Boot/shared code and pointer users not exhaustively traced"),
)

# Exact current $060A parent bytes for selected native bank-2 data readers.
# These prove operand identities, not every caller's runtime reachability.
DIRECT_CAL_REF_SIGNATURES = {
    0x17323: bytes.fromhex("ce655a"),  # F323 LDX #$655A
    0x17326: bytes.fromhex("18ce6613"), # F326 LDY #$6613
    0x1734C: bytes.fromhex("ce6605"),  # F34C LDX #$6605
    0x1734F: bytes.fromhex("18ce66be"),# F34F LDY #$66BE
    0x17AFF: bytes.fromhex("ce66cd"),  # FAFF LDX #$66CD
    0x17B05: bytes.fromhex("f666cc"),  # FB05 LDAB $66CC
    0x17B48: bytes.fromhex("f66559"),  # FB48 LDAB $6559
}

NATIVE_PROTECTED = (
    (0x5D05, 0x5D9B, "F61AG shared native data / historical direct consumers"),
    (0x5EE7, 0x5EFE, "VSR curves including 2-byte interpolation footprint"),
    (0x6559, 0x66D8, "selected bank-2 native CAL pointer/direct-read operands"),
    (0x5117, 0x5249, "14 XDF-labelled native transmission torque reduction tables"),
    (0x1CA57, 0x1CBB7, "protected TIO firmware/image bytes"),
    (0x77DE, 0x781E, "factory native limiter data (preserve all 64 bytes)"),
    (0x17FC0, 0x18000, "bank2 vectors"),
    (0x1FFC0, 0x20000, "bank3 vectors"),
    (0xFFC0, 0x10000, "bank1 vectors"),
)


def file_to_cpu(offset: int) -> dict:
    """Current verified split format: shared common <0x8000; 3 physical bank slices."""
    if type(offset) is not int or not 0 <= offset < IMAGE_SIZE:
        raise ValueError("file offset outside logical 128 KiB")
    if offset < 0x8000:
        return {"view": "COMMON", "cpu_address": f"0x{offset:04X}"}
    if offset < 0x10000:
        return {"view": "BANK1", "cpu_address": f"0x{offset:04X}"}
    if offset < 0x18000:
        return {"view": "BANK2", "cpu_address": f"0x{offset - 0x8000:04X}"}
    return {"view": "BANK3", "cpu_address": f"0x{offset - 0x10000:04X}"}


def cpu_to_file(cpu_address: int, view: str) -> int:
    if type(cpu_address) is not int or not 0 <= cpu_address <= 0xFFFF:
        raise ValueError("CPU address is 16-bit (not 0x1C500)")
    if cpu_address < 0x8000:
        if view not in {"BANK1", "BANK2", "BANK3", "COMMON"}:
            raise ValueError("explicit bank/common memory context required")
        return cpu_address
    offsets = {"BANK1": 0, "BANK2": 0x8000, "BANK3": 0x10000}
    if view not in offsets:
        raise ValueError("ambiguous bank for CPU >= 0x8000")
    return cpu_address + offsets[view]


def overlaps(start: int, end: int, target_start: int, target_end: int) -> bool:
    return start < target_end and end > target_start


def zero_run_inventory(image: bytes, minimum_size: int = 64) -> dict:
    """Inventory maximal whole-file zero runs, independently of curated rows."""
    runs=[]
    start=None
    for offset in range(len(image)+1):
        if offset < len(image) and image[offset] == 0:
            if start is None:
                start=offset
        elif start is not None:
            if offset-start >= minimum_size:
                runs.append({"file_start":f"0x{start:05X}",
                             "file_end_exclusive":f"0x{offset:05X}",
                             "size":offset-start})
            start=None
    return {"minimum_size":minimum_size,"count":len(runs),"runs":runs}


def classify(image: bytes, expected_sha: str = EXPECTED_SHA256) -> dict:
    """Admit only the pinned source by default; hash override is for fixtures.

    A fixture hash does not qualify native signatures or executable storage.
    The CLI intentionally does not expose this test-only hash override.
    """
    if type(image) is not bytes or len(image) != IMAGE_SIZE:
        raise ValueError("requires a complete 131072-byte image")
    actual_sha = hashlib.sha256(image).hexdigest()
    if actual_sha != expected_sha.lower():
        raise ValueError("exact source SHA-256 mismatch")
    if image[FUEL_CUT_START:FUEL_CUT_START+6] != FUEL_CUT_BYTES:
        raise ValueError("factory cutoff calibration unexpected")
    if image[NATIVE_PTR_FILE:NATIVE_PTR_FILE+3] != NATIVE_FUEL_POINTER:
        raise ValueError("factory cutoff pointer unexpected")
    exact_source=expected_sha.lower() == EXPECTED_SHA256
    if exact_source:
        for offset, signature in DIRECT_CAL_REF_SIGNATURES.items():
            if image[offset:offset+len(signature)] != signature:
                raise ValueError(f"native CAL reader signature mismatch: 0x{offset:05X}")
    rows=[]
    for candidate in CANDIDATES:
        span = image[candidate.start:candidate.end]
        if len(span) != candidate.size:
            raise ValueError("truncated candidate region")
        protected = [name for a,b,name in NATIVE_PROTECTED if overlaps(candidate.start,candidate.end,a,b)]
        rows.append({
            "name": candidate.name, "file_start": f"0x{candidate.start:05X}",
            "file_end_exclusive": f"0x{candidate.end:05X}",
            "size": candidate.size,
            "view": file_to_cpu(candidate.start)["view"],
            "cpu_start": file_to_cpu(candidate.start)["cpu_address"],
            "all_zero": all(byte == 0 for byte in span),
            "nonzero_bytes": sum(byte != 0 for byte in span),
            "native_protected_overlaps": protected,
            "qualification": candidate.disposition,
            "executably_free": False,
            "reason": candidate.risk,
        })
    alias = {bank: {
        "file": f"0x{cpu_to_file(0xC500,bank):05X}",
        "zero_first_16": image[cpu_to_file(0xC500,bank):cpu_to_file(0xC500,bank)+16] == bytes(16),
    } for bank in ("BANK1", "BANK2", "BANK3")}
    return {
        "schema": "kingai.vy060a.sc01b.space_negative_certificate.v2",
        "image_sha256": actual_sha,
        "status": ("ZERO_BYTES_VERIFIED_NO_EXECUTABLE_FREE_SITE_ADMITTED" if exact_source
                   else "SYNTHETIC_FIXTURE_NO_NATIVE_SIGNATURE_OR_EXECUTABLE_QUALIFICATION"),
        "known_native_pointers_preserved": True if exact_source else None,
        "native_cal_reader_signatures": {
            "total":len(DIRECT_CAL_REF_SIGNATURES),
            "checked":len(DIRECT_CAL_REF_SIGNATURES) if exact_source else 0,
            "skipped":0 if exact_source else len(DIRECT_CAL_REF_SIGNATURES),
            "result":"PASS" if exact_source else "NOT_CHECKED_SYNTHETIC",
        },
        "curated_region_count":len(rows),
        "zero_run_inventory":zero_run_inventory(image),
        "regions": rows, "cpu_0xC500_bank_aliases": alias,
        "approved_patch_spans": [],
        "holds": [
            "Whole reachable bank/IRQ graph and computed/indexed/pointer native data readers",
            "Power/BCM/TIO/DFI/EST and stack/interleaving under actual mode transitions",
            "RAM state ownership and reset/boot/upload bulk writes",
            "Displaced ISR instructions and real no-3X/18X recovery",
        ],
        "statement": "All-zero bytes are evidence of storage contents only; they are not permission to use that storage.",
    }


def publish_json_exclusive(path: Path, data: str) -> None:
    """Publish a complete report atomically, without replacing any destination.

    A sibling temporary file keeps publication on one filesystem. Windows
    rename refuses an existing destination; POSIX uses an exclusive hard link
    because its rename may replace one. Both expose only the completed file.
    Unsupported filesystems fail closed. This does not certify power-loss
    durability of the containing directory.
    https://docs.python.org/3.13/library/os.html#os.rename
    """
    temporary=None
    try:
        with tempfile.NamedTemporaryFile(mode="w",encoding="utf-8",newline="",
                                         dir=path.parent,prefix=f".{path.name}.",
                                         suffix=".tmp",delete=False) as dst:
            temporary=Path(dst.name)
            dst.write(data)
            dst.flush()
            os.fsync(dst.fileno())
        if os.name == "nt":
            os.rename(temporary,path)
            temporary=None
        else:
            os.link(temporary,path)
    finally:
        if temporary is not None:
            temporary.unlink()


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--image", type=Path, required=True)
    parser.add_argument("--json-out", type=Path,
                        help="Optional new output path; existing files are never overwritten")
    args=parser.parse_args(argv)
    try:
        if args.image.is_symlink() or not args.image.is_file():
            raise ValueError("regular existing source file required")
        if args.image.stat().st_size != IMAGE_SIZE:
            raise ValueError("full 131072-byte file required")
        report=classify(args.image.read_bytes())
        data=json.dumps(report,indent=2,sort_keys=True)+"\n"
        if args.json_out:
            publish_json_exclusive(args.json_out,data)
        print(data,end="")
    except (ValueError,OSError) as exc:
        print(f"REFUSED: {exc}",file=sys.stderr)
        return 2
    return 0


if __name__=="__main__":
    raise SystemExit(main())
