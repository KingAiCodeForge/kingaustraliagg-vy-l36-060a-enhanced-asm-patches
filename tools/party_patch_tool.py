#!/usr/bin/env python3
"""Build or verify exact-target VY party-patch static candidates.

The tool is intentionally locked to one source hash. Passing byte and checksum
checks does not make an output safe to flash.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

try:
    from .vy_flash_checksum import (
        CHECKSUM_OFFSET,
        checksum_report,
        write_vxy_checksum,
    )
except ImportError:
    from vy_flash_checksum import (  # type: ignore[no-redef]
        CHECKSUM_OFFSET,
        checksum_report,
        write_vxy_checksum,
    )

try:
    from .safe_outputs import validate_output_paths, write_outputs_exclusive
except ImportError:
    from safe_outputs import (  # type: ignore[no-redef]
        validate_output_paths,
        write_outputs_exclusive,
    )


EXPECTED_SIZE = 0x20000
SOURCE_SHA256 = "5cb8bd1c61da37a3846b6c28600cdc21db3ceef0c764232d0cd7ec8d6e836abd"
MANIFEST_SCHEMA = "kingai.vy-060a-static-patch.v1"
REPO_ROOT = Path(__file__).resolve().parent.parent


def sha256_bytes(data: bytes | bytearray) -> str:
    return hashlib.sha256(data).hexdigest()


def _parse_offset(value: object, field: str) -> int:
    try:
        return int(value, 0) if isinstance(value, str) else int(value)
    except (TypeError, ValueError) as exc:
        raise ValueError(f"{field} is not a valid integer offset: {value!r}") from exc


def _parse_hex_bytes(value: object, field: str) -> bytes:
    if not isinstance(value, str):
        raise ValueError(f"{field} must be a hexadecimal string")
    try:
        result = bytes.fromhex(value)
    except ValueError as exc:
        raise ValueError(f"{field} contains invalid hexadecimal bytes") from exc
    if not result:
        raise ValueError(f"{field} must not be empty")
    return result


def _normalized_source_sha256(path: Path) -> str:
    text = path.read_text(encoding="utf-8")
    normalized = text.replace("\r\n", "\n").replace("\r", "\n")
    return sha256_bytes(normalized.encode("utf-8"))


def _relative_repo_path(path: Path, field: str) -> str:
    resolved = path.resolve()
    try:
        return resolved.relative_to(REPO_ROOT).as_posix()
    except ValueError as exc:
        raise ValueError(f"{field} must stay inside the repository") from exc


@dataclass(frozen=True)
class PartyPatch:
    name: str
    title: str
    manifest_path: str
    asm_path: str
    asm_sha256: str
    hook_offset: int
    hook_cpu: str
    hook_stock: bytes
    hook_patch: bytes
    code_offset: int
    code_cpu: str
    code_free_end: int
    code: bytes
    conflicts: tuple[str, ...]
    unproved: tuple[str, ...]


def load_patch_manifest(manifest_path: Path) -> PartyPatch:
    data = json.loads(manifest_path.read_text(encoding="utf-8"))
    if data.get("schema") != MANIFEST_SCHEMA:
        raise ValueError(f"unsupported patch manifest schema in {manifest_path}")
    if data.get("status") != "STATIC_CANDIDATE_DO_NOT_FLASH":
        raise ValueError(f"unsafe or missing status in {manifest_path}")

    target = data["target"]
    if _parse_offset(target["size"], "target.size") != EXPECTED_SIZE:
        raise ValueError(f"wrong target size in {manifest_path}")
    if str(target["sha256"]).lower() != SOURCE_SHA256:
        raise ValueError(f"wrong target SHA-256 in {manifest_path}")

    source = data["source"]
    source_path = (manifest_path.parent / source["path"]).resolve()
    asm_path = _relative_repo_path(source_path, "source.path")
    expected_asm_sha256 = str(source["normalized_sha256"]).lower()
    actual_asm_sha256 = _normalized_source_sha256(source_path)
    if actual_asm_sha256 != expected_asm_sha256:
        raise ValueError(
            f"assembly source hash mismatch for {asm_path}: {actual_asm_sha256}"
        )

    hook = data["hook"]
    routine = data["routine"]
    code = _parse_hex_bytes(routine["bytes"], "routine.bytes")
    expected_code_sha256 = str(routine["sha256"]).lower()
    if sha256_bytes(code) != expected_code_sha256:
        raise ValueError(f"assembled-byte hash mismatch in {manifest_path}")

    patch = PartyPatch(
        name=str(data["name"]),
        title=str(data["title"]),
        manifest_path=_relative_repo_path(manifest_path, "manifest"),
        asm_path=asm_path,
        asm_sha256=expected_asm_sha256,
        hook_offset=_parse_offset(hook["file_offset"], "hook.file_offset"),
        hook_cpu=str(hook["cpu"]),
        hook_stock=_parse_hex_bytes(hook["before"], "hook.before"),
        hook_patch=_parse_hex_bytes(hook["after"], "hook.after"),
        code_offset=_parse_offset(routine["file_offset"], "routine.file_offset"),
        code_cpu=str(routine["cpu"]),
        code_free_end=_parse_offset(
            routine["reviewed_zero_end"], "routine.reviewed_zero_end"
        ),
        code=code,
        conflicts=tuple(str(item) for item in data.get("conflicts", [])),
        unproved=tuple(str(item) for item in data.get("unproved", [])),
    )
    if not patch.name or patch.name != manifest_path.parent.name.replace("_", "-"):
        raise ValueError(f"patch name does not match its folder in {manifest_path}")
    if len(patch.hook_stock) != len(patch.hook_patch):
        raise ValueError(f"hook byte lengths differ in {manifest_path}")
    if patch.code_offset + len(patch.code) - 1 > patch.code_free_end:
        raise ValueError(f"routine exceeds reviewed zero run in {manifest_path}")
    return patch


def load_patch_catalog() -> dict[str, PartyPatch]:
    catalog: dict[str, PartyPatch] = {}
    for manifest_path in sorted((REPO_ROOT / "asm_wip").glob("*/manifest.json")):
        patch = load_patch_manifest(manifest_path)
        if patch.name in catalog:
            raise ValueError(f"duplicate patch name: {patch.name}")
        catalog[patch.name] = patch
    if not catalog:
        raise ValueError("no patch manifests found")
    return catalog


PATCHES = load_patch_catalog()


def hex_bytes(data: bytes | bytearray) -> str:
    return " ".join(f"{byte:02X}" for byte in data)


def changed_offsets(before: bytes, after: bytes) -> list[int]:
    if len(before) != len(after):
        raise ValueError("cannot diff images with different lengths")
    return [
        offset
        for offset, (old_byte, new_byte) in enumerate(zip(before, after))
        if old_byte != new_byte
    ]


def allowed_changed_offsets(names: Iterable[str]) -> set[int]:
    """Return the only bytes a deterministic build may change."""
    selected = normalize_patch_names(names)
    allowed = {CHECKSUM_OFFSET, CHECKSUM_OFFSET + 1}
    for name in selected:
        patch = PATCHES[name]
        allowed.update(
            range(patch.hook_offset, patch.hook_offset + len(patch.hook_patch))
        )
        allowed.update(range(patch.code_offset, patch.code_offset + len(patch.code)))
    return allowed


def _resolve_executable(value: str | Path) -> Path:
    supplied = Path(value).expanduser()
    if supplied.is_file():
        return supplied.resolve()
    discovered = shutil.which(str(value))
    if discovered:
        return Path(discovered).resolve()
    raise ValueError(f"assembler executable not found: {value}")


def verify_assembled_source(
    patch: PartyPatch, assembler: str | Path
) -> dict[str, object]:
    """Assemble one source with A09 and compare every emitted byte."""
    executable = _resolve_executable(assembler)
    source_path = REPO_ROOT / patch.asm_path
    with tempfile.TemporaryDirectory(prefix="kingai-a09-") as temp_dir:
        output_path = Path(temp_dir) / f"{patch.name}.bin"
        completed = subprocess.run(
            [str(executable), f"-b{output_path}", str(source_path)],
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        if completed.returncode != 0:
            detail = (completed.stderr or completed.stdout).strip()
            raise ValueError(f"assembler failed for {patch.name}: {detail}")
        if not output_path.is_file():
            raise ValueError(f"assembler created no output for {patch.name}")
        assembled = output_path.read_bytes()

    if assembled != patch.code:
        mismatch = changed_offsets(patch.code, assembled) if len(assembled) == len(patch.code) else []
        preview = ", ".join(f"0x{offset:X}" for offset in mismatch[:16])
        detail = f" at {preview}" if preview else ""
        raise ValueError(
            f"assembled bytes differ for {patch.name}: "
            f"expected {len(patch.code)}, got {len(assembled)} bytes{detail}"
        )
    return {
        "schema": "vy-party-patch-assembly-parity-v1",
        "status": "PASS_STATIC_ONLY_DO_NOT_FLASH",
        "patch": patch.name,
        "source": patch.asm_path,
        "source_sha256": patch.asm_sha256,
        "assembler": executable.name,
        "assembled_length": len(assembled),
        "assembled_sha256": sha256_bytes(assembled),
        "matches_manifest": True,
    }


def normalize_patch_names(names: Iterable[str]) -> tuple[str, ...]:
    selected = tuple(dict.fromkeys(names))
    if not selected:
        raise ValueError("select at least one patch")
    unknown = sorted(set(selected) - PATCHES.keys())
    if unknown:
        raise ValueError(f"unknown patch: {', '.join(unknown)}")

    selected_set = set(selected)
    conflicts = {
        tuple(sorted((name, conflict)))
        for name in selected
        for conflict in PATCHES[name].conflicts
        if conflict in selected_set
    }
    if conflicts:
        pairs = ", ".join(f"{left} + {right}" for left, right in sorted(conflicts))
        raise ValueError(f"conflicting patches: {pairs}")
    return tuple(name for name in PATCHES if name in selected_set)


def preflight_source(source: bytes, names: Iterable[str]) -> tuple[str, ...]:
    selected = normalize_patch_names(names)
    if len(source) != EXPECTED_SIZE:
        raise ValueError(f"input is {len(source)} bytes, expected {EXPECTED_SIZE}")
    digest = sha256_bytes(source)
    if digest != SOURCE_SHA256:
        raise ValueError(f"unsupported input SHA-256: {digest}")

    for name in selected:
        patch = PATCHES[name]
        actual_hook = source[
            patch.hook_offset : patch.hook_offset + len(patch.hook_stock)
        ]
        if actual_hook != patch.hook_stock:
            raise ValueError(
                f"{name} hook mismatch at 0x{patch.hook_offset:05X}: "
                f"{hex_bytes(actual_hook)}"
            )
        candidate_space = source[
            patch.code_offset : patch.code_offset + len(patch.code)
        ]
        if len(candidate_space) != len(patch.code) or any(candidate_space):
            raise ValueError(
                f"{name} code placement at 0x{patch.code_offset:05X} is not zero"
            )
        if patch.code_offset + len(patch.code) - 1 > patch.code_free_end:
            raise AssertionError(f"{name} code exceeds its reviewed zero run")
    return selected


def build_candidate(
    source: bytes, names: Iterable[str]
) -> tuple[bytes, dict[str, object]]:
    selected = preflight_source(source, names)
    candidate = bytearray(source)

    for name in selected:
        patch = PATCHES[name]
        candidate[patch.code_offset : patch.code_offset + len(patch.code)] = patch.code
        candidate[patch.hook_offset : patch.hook_offset + len(patch.hook_patch)] = (
            patch.hook_patch
        )

    write_vxy_checksum(candidate)
    output = bytes(candidate)
    changed = changed_offsets(source, output)
    unexpected = sorted(set(changed) - allowed_changed_offsets(selected))
    if unexpected:
        preview = ", ".join(f"0x{offset:05X}" for offset in unexpected[:16])
        raise AssertionError(f"build changed bytes outside reviewed regions: {preview}")
    report: dict[str, object] = {
        "schema": "vy-party-patch-static-candidate-v1",
        "status": "STATIC_CANDIDATE_DO_NOT_FLASH",
        "source_sha256": SOURCE_SHA256,
        "output_sha256": sha256_bytes(output),
        "patches": [
            {
                "name": PATCHES[name].name,
                "title": PATCHES[name].title,
                "manifest": PATCHES[name].manifest_path,
                "asm": PATCHES[name].asm_path,
                "asm_sha256": PATCHES[name].asm_sha256,
                "hook": {
                    "file_offset": f"0x{PATCHES[name].hook_offset:05X}",
                    "cpu": PATCHES[name].hook_cpu,
                    "before": hex_bytes(PATCHES[name].hook_stock),
                    "after": hex_bytes(PATCHES[name].hook_patch),
                },
                "routine": {
                    "file_offset": f"0x{PATCHES[name].code_offset:05X}",
                    "cpu": PATCHES[name].code_cpu,
                    "length": len(PATCHES[name].code),
                    "bytes": hex_bytes(PATCHES[name].code),
                    "sha256": sha256_bytes(PATCHES[name].code),
                },
                "unproved": list(PATCHES[name].unproved),
            }
            for name in selected
        ],
        "checksum": checksum_report(output),
        "changed_offsets": [f"0x{offset:05X}" for offset in changed],
        "changed_bytes_are_bounded": True,
    }
    return output, report


def verify_candidate(
    source: bytes, candidate: bytes, names: Iterable[str]
) -> dict[str, object]:
    expected, build_report = build_candidate(source, names)
    if candidate != expected:
        offsets = changed_offsets(expected, candidate)
        preview = ", ".join(f"0x{offset:05X}" for offset in offsets[:16])
        raise ValueError(f"candidate differs from deterministic build at {preview}")
    report = checksum_report(candidate)
    if not report["matches"]:
        raise ValueError("candidate checksum does not match")
    return {
        "schema": "vy-party-patch-verification-v1",
        "status": "PASS_STATIC_ONLY_DO_NOT_FLASH",
        "candidate_sha256": sha256_bytes(candidate),
        "matches_deterministic_build": True,
        "checksum": report,
        "build_manifest": build_report,
    }


def add_patch_arguments(parser: argparse.ArgumentParser) -> None:
    parser.add_argument(
        "--patch",
        action="append",
        required=True,
        choices=tuple(PATCHES),
        help="patch to include; repeat for a compatible combination",
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    subparsers.add_parser("list", help="list the curated patch catalog")

    verify_asm = subparsers.add_parser(
        "verify-asm", help="assemble source with A09 and compare manifest bytes"
    )
    verify_asm.add_argument("--assembler", required=True, help="A09 executable or command")
    add_patch_arguments(verify_asm)

    build = subparsers.add_parser("build", help="build an exact-target candidate")
    build.add_argument("input_bin", type=Path)
    build.add_argument("output_bin", type=Path)
    add_patch_arguments(build)
    build.add_argument("--manifest", type=Path)
    build.add_argument(
        "--acknowledge-static-candidate",
        action="store_true",
        help="required acknowledgement that the output is not flash-approved",
    )

    verify = subparsers.add_parser("verify", help="verify a deterministic candidate")
    verify.add_argument("source_bin", type=Path)
    verify.add_argument("candidate_bin", type=Path)
    add_patch_arguments(verify)
    verify.add_argument("--json", type=Path, dest="json_path")
    return parser.parse_args()


def catalog_report() -> dict[str, object]:
    return {
        name: {
            "title": patch.title,
            "manifest": patch.manifest_path,
            "asm": patch.asm_path,
            "asm_sha256": patch.asm_sha256,
            "routine_sha256": sha256_bytes(patch.code),
            "conflicts": list(patch.conflicts),
            "status": "STATIC_CANDIDATE_DO_NOT_FLASH",
        }
        for name, patch in PATCHES.items()
    }


def main() -> int:
    args = parse_args()
    if args.command == "list":
        print(json.dumps(catalog_report(), indent=2))
        return 0

    if args.command == "verify-asm":
        selected = normalize_patch_names(args.patch)
        reports = [
            verify_assembled_source(PATCHES[name], args.assembler)
            for name in selected
        ]
        print(json.dumps(reports, indent=2))
        return 0

    if args.command == "build":
        if not args.acknowledge_static_candidate:
            raise SystemExit("refusing output without --acknowledge-static-candidate")
        outputs = [args.output_bin]
        if args.manifest:
            outputs.append(args.manifest)
        validate_output_paths([args.input_bin], outputs)
        output, report = build_candidate(args.input_bin.read_bytes(), args.patch)
        payloads: list[tuple[Path, bytes | str]] = [(args.output_bin, output)]
        if args.manifest:
            payloads.append(
                (args.manifest, json.dumps(report, indent=2) + "\n")
            )
        write_outputs_exclusive(payloads)
    else:
        outputs = [args.json_path] if args.json_path else []
        validate_output_paths([args.source_bin, args.candidate_bin], outputs)
        report = verify_candidate(
            args.source_bin.read_bytes(),
            args.candidate_bin.read_bytes(),
            args.patch,
        )
        if args.json_path:
            write_outputs_exclusive(
                [(args.json_path, json.dumps(report, indent=2) + "\n")]
            )

    print(json.dumps(report, indent=2))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (FileExistsError, OSError, ValueError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1) from None
