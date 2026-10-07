#!/usr/bin/env python3
"""Unit and optional exact-source tests for the party-patch builder."""

from __future__ import annotations

import os
import tempfile
import unittest
from dataclasses import replace
from pathlib import Path
from unittest import mock

try:
    from . import party_patch_tool as patch_tool
    from .party_patch_tool import (
        PATCHES,
        REPO_ROOT,
        _ordered_patch_names,
        allowed_changed_offsets,
        build_candidate,
        changed_offsets,
        normalize_patch_names,
        validate_output_paths,
        verify_assembled_source,
        verify_candidate,
    )
except ImportError:
    import party_patch_tool as patch_tool
    from party_patch_tool import (  # type: ignore[no-redef]
        PATCHES,
        REPO_ROOT,
        _ordered_patch_names,
        allowed_changed_offsets,
        build_candidate,
        changed_offsets,
        normalize_patch_names,
        validate_output_paths,
        verify_assembled_source,
        verify_candidate,
    )


SOURCE_PATH = Path(
    os.environ.get("VY_V1_0A_BIN", REPO_ROOT / "VX-VY_V6_$060A_Enhanced_v1.0a.bin")
)
A09_ASSEMBLER = os.environ.get("A09_ASSEMBLER")


class PartyPatchToolTests(unittest.TestCase):
    def test_catalog_contains_only_reviewed_public_entries(self) -> None:
        self.assertEqual(set(PATCHES), {"ghost-cam", "est-shared-probe"})

    def test_catalog_has_source_and_bounded_code(self) -> None:
        for patch in PATCHES.values():
            self.assertTrue(patch.asm_path.endswith(".asm"))
            self.assertTrue((REPO_ROOT / patch.asm_path).is_file())
            self.assertTrue((REPO_ROOT / patch.manifest_path).is_file())
            self.assertTrue(patch.hooks)
            for hook in patch.hooks:
                self.assertEqual(len(hook.hook_stock), len(hook.hook_patch))
            self.assertLessEqual(
                patch.code_offset + len(patch.code) - 1,
                patch.code_free_end,
            )

    def test_withdrawn_cut_names_are_rejected(self) -> None:
        for name in ("spark-cut", "rolling-cut"):
            with self.subTest(name=name):
                with self.assertRaisesRegex(ValueError, "unknown patch"):
                    normalize_patch_names((name,))

    def test_duplicate_selection_is_deduplicated(self) -> None:
        self.assertEqual(
            normalize_patch_names(("ghost-cam", "ghost-cam")),
            ("ghost-cam",),
        )

    def test_probe_conflicts_with_behavior_patch(self) -> None:
        with self.assertRaisesRegex(ValueError, "conflicting patches"):
            normalize_patch_names(("ghost-cam", "est-shared-probe"))

        self.assertEqual(
            set(_ordered_patch_names(("ghost-cam", "est-shared-probe"))),
            {"ghost-cam", "est-shared-probe"},
        )

    def test_overlapping_write_regions_are_rejected(self) -> None:
        base = PATCHES["ghost-cam"]
        collision = replace(
            base,
            name="collision",
            hooks=(replace(base.hooks[0], hook_offset=base.code_offset),),
            conflicts=(),
        )
        with mock.patch.dict(patch_tool.PATCHES, {"collision": collision}):
            with self.assertRaisesRegex(ValueError, "overlapping write regions"):
                normalize_patch_names(("collision",))

    def test_output_paths_refuse_input_aliases_and_existing_files(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            source = root / "source.bin"
            source.write_bytes(b"source")
            with self.assertRaisesRegex(ValueError, "must not overwrite an input"):
                validate_output_paths([source], [source])

            existing = root / "existing.bin"
            existing.write_bytes(b"preserve")
            with self.assertRaisesRegex(FileExistsError, "refusing to overwrite"):
                validate_output_paths([source], [existing])
            self.assertEqual(existing.read_bytes(), b"preserve")

    @unittest.skipUnless(
        SOURCE_PATH.is_file(),
        "provide VY_V1_0A_BIN to run exact-source integration checks",
    )
    def test_exact_source_builds_and_verifies_supported_sets(self) -> None:
        source = SOURCE_PATH.read_bytes()
        selections = (("ghost-cam",), ("est-shared-probe",))
        for names in selections:
            with self.subTest(names=names):
                candidate, report = build_candidate(source, names)
                self.assertTrue(report["checksum"]["matches"])
                self.assertTrue(report["changed_bytes_are_bounded"])
                self.assertLessEqual(
                    set(changed_offsets(source, candidate)),
                    allowed_changed_offsets(names),
                )
                verified = verify_candidate(source, candidate, names)
                self.assertTrue(verified["matches_deterministic_build"])
                self.assertEqual(
                    len(report["patches"][0]["hooks"]), len(PATCHES[names[0]].hooks)
                )

        _candidate, probe_report = build_candidate(source, ("est-shared-probe",))
        self.assertEqual(probe_report["status"], "STATIC_WIP_PROBE_DO_NOT_FLASH")

    @unittest.skipUnless(
        A09_ASSEMBLER,
        "set A09_ASSEMBLER to run assembly parity checks",
    )
    def test_a09_output_matches_manifest_bytes(self) -> None:
        for name, patch in PATCHES.items():
            with self.subTest(name=name):
                report = verify_assembled_source(patch, A09_ASSEMBLER)
                self.assertTrue(report["matches_manifest"])


if __name__ == "__main__":
    unittest.main()
