#!/usr/bin/env python3
"""Read-only static verification of kingai.vy.bench-bundle.v1 bundles.

Assembly declarations are checked against bundled bytes; the assembler is not
rerun. Passing these checks supplies no hardware, recovery or vehicle approval.
Use --require-release-ready when a caller needs a release eligibility gate;
current bench-WIP and historical quarantined bundles are not release-ready.
"""

from __future__ import annotations

import argparse
from datetime import date
from hashlib import sha256
import json
import os
from pathlib import Path
import re
import stat
from typing import Sequence


SCHEMA = "kingai.vy.bench-bundle.v1"
STATUS = "WIP_BENCH_FLASH_ONLY"
SOURCE_SIZE = 131072
SOURCE_SHA256 = "5cb8bd1c61da37a3846b6c28600cdc21db3ceef0c764232d0cd7ec8d6e836abd"
MAX_MANIFEST_BYTES = 2 * 1024 * 1024
MAX_ASM_BYTES = 2 * 1024 * 1024
KNOWN_HOLD = frozenset((
    "4df9165b39f4e2aaf4a28106a5d4f42be3ab312ba32653f0e8503af2280354e5",
    "e0d1234553debd0318c910e26346a0154b67a17523adddb974e670a3a9a37481",
))
# Exact payload identities survive renamed files and stripped legacy metadata.
LEGACY_SC01 = frozenset((
    "6e63865810f452c310b83a368a0f2ee9ab942f6a53d3e38af8d2215c302a662a",
    "7670fcc475f7273f8a2e924466a10eb369499209e2ac90c8b098ba2dd41241a3",
))
SC01_DISPOSITION = {
    "status": "HISTORICAL_DO_NOT_FLASH",
    "release_ready": False,
    "reason": "Native-data collisions at handler $5D05 and parameters $5EF0 affect active and disabled SC01; ignition and recovery remain unqualified.",
    "evidence": "docs/SC01B_ROM_ALLOCATION_AND_HOOK_REVIEW_20261024.md",
}


def current_disposition(binary_hash: str) -> dict:
    """Keep static integrity distinct from current distribution eligibility."""
    if binary_hash in LEGACY_SC01:
        return dict(SC01_DISPOSITION)
    return {
        "status": "UNQUALIFIED_BENCH_WIP",
        "release_ready": False,
        "reason": "Static bundle integrity is not hardware, ignition, recovery or vehicle qualification.",
    }


QUALIFICATION = {
    "independent_assembly": True,
    "hardware_execution": False,
    "bench_readback": False,
    "interrupted_recovery": False,
    "measured_ignition": False,
    "vehicle": False,
}


class BundleValidationError(ValueError):
    """A bundle failed an explicit static validation guard."""


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise BundleValidationError(message)


def _keys(value, expected: set[str], label: str, optional: set[str] | None = None) -> None:
    _require(type(value) is dict, f"{label} must be an object")
    _require(expected <= set(value) <= expected | (optional or set()),
             f"{label} has missing or unknown fields")


def _text(value, label: str) -> None:
    _require(type(value) is str and bool(value.strip()), f"{label} must be nonempty text")


def _digest(value, label: str) -> str:
    _require(type(value) is str and re.fullmatch(r"[0-9a-f]{64}", value) is not None,
             f"{label} must be a lowercase SHA-256 digest")
    return value


def _basename(value, suffix: str) -> str:
    _require(type(value) is str and bool(value), "bundle path must be a basename")
    _require(re.search(r'[<>:"/\\|?*\x00-\x1f]', value) is None,
             "bundle path must be a portable basename without separators or streams")
    _require(value not in (".", "..") and not value.endswith((" ", ".")),
             "bundle path has an unsafe basename")
    reserved = {"CON", "PRN", "AUX", "NUL", *[f"COM{i}" for i in range(1, 10)],
                *[f"LPT{i}" for i in range(1, 10)]}
    _require(value.split(".", 1)[0].upper() not in reserved, "reserved Windows basename")
    _require(value.endswith(suffix) and len(value) > len(suffix),
             f"bundle path must end with {suffix}")
    _require(value[:-len(suffix)].endswith("_WIP_BENCH_FLASH_ONLY"),
             "bundle filename must have the _WIP_BENCH_FLASH_ONLY suffix")
    return value


def _span_hex(value, label: str) -> bytes:
    _require(type(value) is str, f"{label} must be hex text")
    try:
        data = bytes.fromhex(value)
    except ValueError as error:
        raise BundleValidationError(f"{label} is invalid hex") from error
    _require(bool(data), f"{label} must have nonzero length")
    return data


def _bounded_range(offset, size, label: str) -> int:
    _require(type(offset) is int and type(size) is int,
             f"{label} offset and size must be integers")
    _require(offset >= 0 and size > 0 and offset + size <= SOURCE_SIZE,
             f"{label} exceeds the 128 KiB image")
    return offset + size


def _validate_bytes(manifest: dict, binary: bytes, asm: bytes, *,
                    _expected_source_sha256: str = SOURCE_SHA256) -> dict:
    """Pure validator; only synthetic tests override the private source pin.

    Public entry points and the CLI never expose or override that pin.
    """
    _keys(manifest, {"schema", "status", "source", "binary", "asm", "changes",
                     "assembly", "qualification", "known_limits"}, "manifest",
          {"family", "profile", "purpose", "hooks", "checksum", "host_review",
           "current_disposition"})
    for field in ("family", "profile", "purpose"):
        if field in manifest:
            _text(manifest[field], field)
    _require(manifest["schema"] == SCHEMA, "unsupported manifest schema")
    _require(manifest["status"] == STATUS, "bundle status is not WIP_BENCH_FLASH_ONLY")
    _keys(manifest["source"], {"size", "sha256"}, "source", {"firmware"})
    if "firmware" in manifest["source"]:
        _text(manifest["source"]["firmware"], "source.firmware")
    _require(type(manifest["source"]["size"]) is int and
             manifest["source"]["size"] == SOURCE_SIZE, "source size is not pinned")
    _digest(manifest["source"]["sha256"], "source.sha256")
    _require(manifest["source"]["sha256"] == _expected_source_sha256,
             "source SHA-256 does not match the required exact source")

    _keys(manifest["binary"], {"path", "size", "sha256"}, "binary")
    binary_name = _basename(manifest["binary"]["path"], ".bin")
    _require(type(manifest["binary"]["size"]) is int and
             manifest["binary"]["size"] == SOURCE_SIZE, "binary size is not 128 KiB")
    _require(type(binary) is bytes and len(binary) == SOURCE_SIZE,
             "candidate must contain exactly 128 KiB")
    binary_hash = sha256(binary).hexdigest()
    _require(binary_hash not in KNOWN_HOLD, "known v60 HOLD payload is refused")
    _require(_digest(manifest["binary"]["sha256"], "binary.sha256") == binary_hash,
             "candidate SHA-256 mismatch")

    disposition = current_disposition(binary_hash)
    if "current_disposition" in manifest:
        declared = manifest["current_disposition"]
        _keys(declared, set(disposition), "current_disposition")
        for field, expected in disposition.items():
            _require(type(declared[field]) is type(expected) and declared[field] == expected,
                     f"current_disposition.{field} disagrees with the current payload classification")

    _keys(manifest["asm"], {"path", "sha256"}, "asm")
    asm_name = _basename(manifest["asm"]["path"], ".asm")
    _require(asm_name == binary_name[:-4] + ".asm", "ASM and BIN basenames must match")
    _require(type(asm) is bytes and 0 < len(asm) <= MAX_ASM_BYTES,
             "ASM must contain 1..2 MiB of bytes")
    _require(_digest(manifest["asm"]["sha256"], "asm.sha256") == sha256(asm).hexdigest(),
             "ASM SHA-256 mismatch")

    _keys(manifest["qualification"], set(QUALIFICATION), "qualification")
    for flag, expected in QUALIFICATION.items():
        _require(manifest["qualification"][flag] is expected,
                 f"qualification.{flag} must be {expected}")
    limits = manifest["known_limits"]
    _require(type(limits) is list and bool(limits) and
             all(type(item) is str and bool(item.strip()) for item in limits),
             "known_limits must be a nonempty list of nonempty strings")

    _require(type(manifest["changes"]) is list, "changes must be an array")
    spans = []
    previous_end = 0
    parent = bytearray(binary)
    for number, change in enumerate(manifest["changes"]):
        label = f"changes[{number}]"
        _keys(change, {"offset", "before", "after"}, label)
        before = _span_hex(change["before"], label + ".before")
        after = _span_hex(change["after"], label + ".after")
        _require(len(before) == len(after), f"{label} has unequal span lengths")
        offset = change["offset"]
        end = _bounded_range(offset, len(after), label)
        _require(offset >= previous_end, "changes must be sorted and nonoverlapping")
        _require(binary[offset:end] == after, f"{label} candidate after-bytes mismatch")
        parent[offset:end] = before
        previous_end = end
        spans.append((offset, end, before, after))
    parent_hash = sha256(parent).hexdigest()
    _require(parent_hash == _expected_source_sha256,
             "reconstructed parent SHA-256 does not match the required exact source")
    rebuilt = bytearray(parent)
    for offset, end, before, after in spans:
        _require(rebuilt[offset:end] == before, "rebuild before-bytes mismatch")
        rebuilt[offset:end] = after
    _require(bytes(rebuilt) == binary, "reapplied changes do not reproduce the candidate")

    covered = bytearray(SOURCE_SIZE)
    covered[0x4006:0x4008] = b"\x01\x01"
    hooks = manifest.get("hooks", [])
    _require(type(hooks) is list, "hooks must be an array")
    for number, hook in enumerate(hooks):
        label = f"hooks[{number}]"
        _keys(hook, {"file_offset", "cpu_address", "bank", "before", "after", "role"}, label)
        before = _span_hex(hook["before"], label + ".before")
        after = _span_hex(hook["after"], label + ".after")
        _require(len(before) == len(after), f"{label} has unequal span lengths")
        offset = hook["file_offset"]
        end = _bounded_range(offset, len(after), label)
        _require(type(hook["bank"]) is int and hook["bank"] in (0, 2, 3),
                 f"{label} bank must be 0, 2 or 3")
        bank = hook["bank"]
        start, stop, delta = {0: (0, 0x10000, 0),
                              2: (0x10000, 0x18000, 0x8000),
                              3: (0x18000, 0x20000, 0x10000)}[bank]
        _require(start <= offset and end <= stop and type(hook["cpu_address"]) is int
                 and hook["cpu_address"] == offset - delta,
                 f"{label} CPU address disagrees with its file offset and bank")
        _text(hook["role"], label + ".role")
        _require(parent[offset:end] == before, f"{label} reconstructed parent before-bytes mismatch")
        _require(binary[offset:end] == after, f"{label} candidate after-bytes mismatch")
        covered[offset:end] = b"\x01" * len(after)

    calculated = (sum(binary[0x2000:0x4000]) + sum(binary[0x4008:0x20000])) & 0xFFFF
    stored = int.from_bytes(binary[0x4006:0x4008], "big")
    _require(stored == calculated, "candidate file checksum mismatch")
    if "checksum" in manifest:
        metadata = manifest["checksum"]
        _keys(metadata, {"mode", "offset", "stored", "calculated"}, "checksum")
        _require(metadata["mode"] == "ADDITIVE_CORRECTED", "unsupported checksum mode")
        for field, actual in (("offset", 0x4006), ("stored", stored), ("calculated", calculated)):
            _require(type(metadata[field]) is int and metadata[field] == actual,
                     f"checksum.{field} disagrees with candidate bytes")

    _keys(manifest["assembly"], {"tool", "tool_sha256", "regions"}, "assembly",
          {"addressed_bytes_matched"})
    assembly = manifest["assembly"]
    _require(assembly["tool"] == "A09 V1.62", "assembly tool must be A09 V1.62")
    _digest(assembly["tool_sha256"], "assembly.tool_sha256")
    _require(type(assembly["regions"]) is list and bool(assembly["regions"]),
             "assembly.regions must be a nonempty array")
    previous_end = 0
    addressed_bytes = 0
    for number, region in enumerate(assembly["regions"]):
        label = f"assembly.regions[{number}]"
        _keys(region, {"file_offset", "size", "sha256"}, label)
        end = _bounded_range(region["file_offset"], region["size"], label)
        _require(region["file_offset"] >= previous_end,
                 "assembly regions must be sorted and nonoverlapping")
        actual = sha256(binary[region["file_offset"]:end]).hexdigest()
        _require(_digest(region["sha256"], label + ".sha256") == actual,
                 f"{label} candidate region SHA-256 mismatch")
        covered[region["file_offset"]:end] = b"\x01" * region["size"]
        previous_end = end
        addressed_bytes += region["size"]
    if "addressed_bytes_matched" in assembly:
        _require(type(assembly["addressed_bytes_matched"]) is int and
                 assembly["addressed_bytes_matched"] == addressed_bytes,
                 "assembly.addressed_bytes_matched must equal summed region sizes")
    _require(all(covered[index] for index, (before, after) in enumerate(zip(parent, binary))
                 if before != after),
             "changed bytes are not covered by assembly regions, hooks or checksum word")

    if "host_review" in manifest:
        host = manifest["host_review"]
        _keys(host, {"date", "tests", "source_rebuild_byte_exact",
                     "email_pack_member_manifest_checks", "firmware_modified_during_intake"},
              "host_review")
        _text(host["date"], "host_review.date")
        try:
            parsed_date = date.fromisoformat(host["date"])
        except ValueError as error:
            raise BundleValidationError("host_review.date must be YYYY-MM-DD") from error
        _require(parsed_date.isoformat() == host["date"], "host_review.date must be YYYY-MM-DD")
        _text(host["tests"], "host_review.tests")
        for field in ("source_rebuild_byte_exact", "firmware_modified_during_intake"):
            _require(type(host[field]) is bool, f"host_review.{field} must be boolean")
        _require(type(host["email_pack_member_manifest_checks"]) is int and
                 host["email_pack_member_manifest_checks"] >= 0,
                 "host_review.email_pack_member_manifest_checks must be a nonnegative integer")
    report = {
        "status": disposition["status"], "declared_status": manifest["status"],
        "release_ready": disposition["release_ready"],
        "current_disposition": disposition,
        "static_checks": "PASS", "binary": binary_name,
        "binary_sha256": binary_hash, "asm": asm_name,
        "reconstructed_source_sha256": parent_hash,
        "change_spans": len(spans), "assembly_regions": len(assembly["regions"]),
        "file_checksum": {"stored": stored, "calculated": calculated},
        "assembly_evidence": "Declared region hashes match candidate bytes; assembler not rerun.",
        "qualification": dict(QUALIFICATION),
    }
    if "host_review" in manifest:
        report["declared_host_review"] = dict(manifest["host_review"])
        report["host_review_evidence"] = (
            "Declared metadata only; host tests and assembly were not independently rerun by this verifier.")
    return report


def _read_regular(path: Path, cap: int, *, exact: int | None = None) -> bytes:
    """Reject links/reparse points, including ancestors, before a bounded read."""
    path = path.absolute()  # Deliberately do not resolve away evidence of links.
    for component in (path, *path.parents):
        info = component.lstat()
        _require(not stat.S_ISLNK(info.st_mode) and
                 not (getattr(info, "st_file_attributes", 0) &
                      getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0x400)),
                 f"symlink or reparse point refused: {component}")
    original = path.lstat()
    _require(stat.S_ISREG(original.st_mode), "bundle input must be a regular file")
    _require(original.st_size <= cap and (exact is None or original.st_size == exact),
             "bundle input has an invalid or excessive size")
    flags = os.O_RDONLY | getattr(os, "O_BINARY", 0) | getattr(os, "O_NOFOLLOW", 0)
    descriptor = os.open(path, flags)
    with os.fdopen(descriptor, "rb") as stream:
        opened = os.fstat(stream.fileno())
        _require(stat.S_ISREG(opened.st_mode) and
                 (opened.st_dev, opened.st_ino) == (original.st_dev, original.st_ino),
                 "bundle input changed while opening")
        data = stream.read(cap + 1)
    _require(len(data) <= cap and (exact is None or len(data) == exact),
             "bundle input has an invalid or excessive size")
    return data


def _unique_object(pairs):
    result = {}
    for key, value in pairs:
        _require(key not in result, f"duplicate JSON field: {key}")
        result[key] = value
    return result


def _reject_constant(value):
    raise BundleValidationError(f"invalid JSON constant: {value}")


def validate_bundle(manifest_path: str | Path) -> dict:
    """Validate files with the real source pin; never write a bundle artifact."""
    path = Path(manifest_path)
    raw = _read_regular(path, MAX_MANIFEST_BYTES)
    try:
        manifest = json.loads(raw.decode("utf-8"), object_pairs_hook=_unique_object,
                              parse_constant=_reject_constant)
    except (UnicodeError, json.JSONDecodeError, RecursionError) as error:
        raise BundleValidationError("manifest must be valid bounded UTF-8 JSON") from error
    _require(type(manifest) is dict, "manifest must be an object")
    _keys(manifest.get("binary"), {"path", "size", "sha256"}, "binary")
    _keys(manifest.get("asm"), {"path", "sha256"}, "asm")
    binary_name = _basename(manifest["binary"]["path"], ".bin")
    asm_name = _basename(manifest["asm"]["path"], ".asm")
    binary = _read_regular(path.parent / binary_name, SOURCE_SIZE, exact=SOURCE_SIZE)
    asm = _read_regular(path.parent / asm_name, MAX_ASM_BYTES)
    return _validate_bytes(manifest, binary, asm)


class _JsonParser(argparse.ArgumentParser):
    def error(self, message):
        raise BundleValidationError(message)


def main(argv: Sequence[str] | None = None) -> int:
    parser = _JsonParser(description=__doc__, add_help=False)
    parser.add_argument("--help", action="store_true")
    parser.add_argument("--require-release-ready", action="store_true")
    parser.add_argument("manifests", nargs="*")
    try:
        args = parser.parse_args(argv)
        if args.help:
            print(json.dumps({"usage": "verify_bench_bundle.py [--require-release-ready] MANIFEST [MANIFEST ...]",
                              "scope": __doc__}))
            return 0
        _require(bool(args.manifests), "provide one or more manifest paths")
    except BundleValidationError as error:
        print(json.dumps({"ok": False, "error": str(error)}))
        return 2
    results = []
    for manifest_path in args.manifests:
        try:
            report = validate_bundle(manifest_path)
            eligible = not args.require_release_ready or report.get("release_ready") is True
            item = {"manifest": manifest_path, "ok": eligible, "report": report}
            if not eligible:
                item["error"] = "not release-ready: " + report["current_disposition"]["reason"]
            results.append(item)
        except (OSError, ValueError) as error:
            results.append({"manifest": manifest_path, "ok": False, "error": str(error)})
    print(json.dumps({"ok": all(item["ok"] for item in results),
                      "ok_scope": "release_eligibility" if args.require_release_ready else "static_integrity",
                      "release_ready": all(item.get("report", {}).get("release_ready") is True
                                           for item in results),
                      "results": results},
                     indent=2, sort_keys=True))
    return 0 if all(item["ok"] for item in results) else 1


if __name__ == "__main__":
    raise SystemExit(main())
