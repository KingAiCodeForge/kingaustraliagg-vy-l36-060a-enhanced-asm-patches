#!/usr/bin/env python3
"""Bounded read-only BIN inventory. Byte integrity is not code/flash approval."""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
import os
from pathlib import Path
import sys

try:
    from .vy_flash_checksum import checksum_report
except ImportError:
    from vy_flash_checksum import checksum_report

SOURCE_SHA256 = "5cb8bd1c61da37a3846b6c28600cdc21db3ceef0c764232d0cd7ec8d6e836abd"
KNOWN_HOLD = {
    "4df9165b39f4e2aaf4a28106a5d4f42be3ab312ba32653f0e8503af2280354e5": "V60_RAW0208_D_REGISTER_HOLD",
    "e0d1234553debd0318c910e26346a0154b67a17523adddb974e670a3a9a37481": "V60_RAWZERO_D_REGISTER_HOLD",
}


def digest(data):
    return hashlib.sha256(data).hexdigest()


def analyze_candidate(source, candidate):
    if len(source) != 0x20000:
        raise ValueError("source must be exactly 131072 bytes")
    result = {"sha256": digest(candidate), "bytes": len(candidate),
              "upload_eligible": False, "code_correctness_proven": False,
              "bench_qualified": False, "vehicle_qualified": False}
    if len(candidate) != len(source):
        return {**result, "status": "WRONG_SIZE_HOLD_NO_PADDING_OR_CROPPING"}
    changed = sum(a != b for a, b in zip(source, candidate))
    result.update(changed_bytes=changed, file_checksum=checksum_report(candidate))
    if result["sha256"] in KNOWN_HOLD:
        status = KNOWN_HOLD[result["sha256"]]
    elif candidate == source:
        status = "REFERENCE_NOT_A_PATCH"
    elif not result["file_checksum"]["matches"]:
        status = "FILE_CHECKSUM_HOLD"
    else:
        status = "BYTE_INTEGRITY_OBSERVED_CODE_ASM_NATIVE_PROOF_HOLD"
    return {**result, "status": status}


def redirected(path):
    return path.is_symlink() or bool(getattr(path.lstat(), "st_file_attributes", 0) & 0x400)


def inventory(source, roots, max_files=512, max_entries=30000, max_depth=6):
    rows, diagnostics = [], Counter()
    entries_seen, partial = 0, False
    for root_index, root in enumerate(roots):
        if not root.is_dir() or redirected(root):
            raise ValueError("roots must be ordinary non-reparse directories")
        pending = [(root, 0)]
        while pending and entries_seen < max_entries and len(rows) < max_files:
            directory, depth = pending.pop()
            try:
                with os.scandir(directory) as entries:
                    for entry in entries:
                        if entries_seen >= max_entries or len(rows) >= max_files:
                            partial = True
                            break
                        entries_seen += 1
                        child = Path(entry.path)
                        try:
                            info = entry.stat(follow_symlinks=False)
                            if entry.is_symlink() or getattr(info, "st_file_attributes", 0) & 0x400:
                                diagnostics["reparse_skipped"] += 1
                                continue
                            if entry.is_dir(follow_symlinks=False):
                                if depth >= max_depth:
                                    diagnostics["depth_limit"] += 1
                                    partial = True
                                elif entry.name not in {".git", "__pycache__", ".pytest_cache"}:
                                    pending.append((child, depth + 1))
                                continue
                            if not entry.is_file(follow_symlinks=False) or child.suffix.lower() != ".bin":
                                continue
                            label = f"root{root_index}/" + child.relative_to(root).as_posix()
                            if info.st_size != 0x20000:
                                rows.append({"path": label, "bytes": info.st_size, "sha256": None,
                                             "status": "WRONG_SIZE_NOT_READ", "upload_eligible": False})
                                continue
                            data = child.read_bytes()
                            after = child.stat(follow_symlinks=False)
                            if (info.st_size, info.st_mtime_ns) != (after.st_size, after.st_mtime_ns):
                                rows.append({"path": label, "status": "CHANGED_DURING_READ_HOLD", "upload_eligible": False})
                                diagnostics["changed_input"] += 1
                                partial = True
                                continue
                            rows.append({"path": label, **analyze_candidate(source, data)})
                        except OSError:
                            diagnostics["entry_errors"] += 1
                            partial = True
            except OSError:
                diagnostics["directory_errors"] += 1
                partial = True
        if entries_seen >= max_entries or len(rows) >= max_files:
            partial = True
            break
    hashes = [row["sha256"] for row in rows if row.get("sha256")]
    return {"schema": "kingai.vy.patch_inventory.v1", "source_sha256": digest(source),
            "source_checksum": checksum_report(source), "observed_bin_paths": len(rows),
            "unique_payloads": len(set(hashes)), "hashed_paths": len(hashes),
            "duplicate_hashed_paths": len(hashes) - len(set(hashes)),
            "coverage": "partial" if partial else "complete_with_declared_exclusions",
            "limits": {"files": max_files, "entries": max_entries, "depth": max_depth},
            "diagnostics": dict(diagnostics), "status_counts": dict(Counter(row["status"] for row in rows)),
            "publication_approved_count": 0, "rows": rows,
            "boundary": "No image changed; checksum/diff/hash observations do not prove code, ASM parity, hardware behavior or absence of defects."}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--candidates", type=Path, action="append", required=True)
    parser.add_argument("--out-dir", type=Path, required=True)
    parser.add_argument("--max-files", type=int, default=512)
    parser.add_argument("--max-entries", type=int, default=30000)
    parser.add_argument("--max-depth", type=int, default=6)
    args = parser.parse_args(argv)
    if min(args.max_files, args.max_entries, args.max_depth) < 1:
        parser.error("limits must be positive")
    if args.source.stat().st_size != 0x20000:
        raise ValueError("source must be exactly 131072 bytes")
    source = args.source.read_bytes()
    if digest(source) != SOURCE_SHA256:
        raise ValueError("source SHA-256 is not the supported Enhanced v1.0a image")
    output = args.out_dir.resolve()
    if output.exists():
        raise FileExistsError("output directory must be new")
    if any(output.is_relative_to(root.resolve()) for root in args.candidates):
        raise ValueError("output must be outside candidate roots")
    report = inventory(source, args.candidates, args.max_files, args.max_entries, args.max_depth)
    output.mkdir(parents=True, exist_ok=False)
    with (output / "inventory.json").open("x", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2)
        handle.write("\n")
    with (output / "inventory.md").open("x", encoding="utf-8") as handle:
        handle.write("# VY patched-BIN inventory\n\nByte checks only. No automatic upload or flash approval. See inventory.json for limits.\n\n| Path | SHA-256 | Status |\n| --- | --- | --- |\n")
        for row in report["rows"]:
            path = row["path"].replace("|", "\\|").replace("\n", " ").replace("\r", " ").replace(chr(96), "'")
            handle.write(f"| {path} | {row.get('sha256') or 'not hashed'} | {row['status']} |\n")
    print(json.dumps({key: value for key, value in report.items() if key != "rows"}))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1) from None
