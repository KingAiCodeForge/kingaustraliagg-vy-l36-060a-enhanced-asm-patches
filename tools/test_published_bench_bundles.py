"""Check the shipped artifact set without a private reference or hardware."""
from collections import Counter
import json
from pathlib import Path
import re
import unittest

try:
    from .verify_bench_bundle import validate_bundle
except ImportError:
    from verify_bench_bundle import validate_bundle


ROOT = Path(__file__).resolve().parents[1]
BUNDLES = ROOT / "bench_wip"


class PublishedBundleContractTests(unittest.TestCase):
    def test_every_indexed_public_bundle_validates(self):
        ledger = json.loads((BUNDLES / "intake_status.json").read_text())
        manifests = sorted(BUNDLES.glob("*/manifest.json"))
        self.assertEqual(len(manifests), ledger["public_unique_images"])
        identities = {}
        for path in manifests:
            with self.subTest(bundle=path.parent.name):
                report = validate_bundle(path)
                self.assertEqual(report["static_checks"], "PASS")
                digest = report["binary_sha256"]
                self.assertNotIn(digest, identities, "publish shared controls once")
                identities[digest] = path.relative_to(BUNDLES).as_posix()
        covered = 0
        for entry in ledger["entries"]:
            if entry["decision"] == "PUBLISHED_BENCH_WIP":
                self.assertEqual(identities.get(entry["sha256"]), entry["bundle"])
                covered += 1
            else:
                self.assertIsNone(entry["bundle"])
        self.assertEqual(covered, ledger["covered_index_rows"])
        self.assertEqual(len(ledger["entries"]), ledger["indexed_rows"])
        self.assertEqual(ledger["indexed_rows"], 57)
        self.assertEqual(ledger["hardware_qualified_images"], 0)

    def test_bundle_folders_contain_only_their_declared_files(self):
        for path in BUNDLES.glob("*/manifest.json"):
            with self.subTest(bundle=path.parent.name):
                manifest = json.loads(path.read_text())
                self.assertEqual({p.name for p in path.parent.iterdir()}, {
                    "README.md", "manifest.json",
                    manifest["binary"]["path"], manifest["asm"]["path"],
                })
                source = (path.parent / manifest["asm"]["path"]).read_bytes()
                self.assertNotIn(b"\r", source, "ASM identity must survive Windows checkout")
                self.assertNotRegex(source.decode("ascii"), r"[A-Za-z]:[\\/]")
                self.assertNotIn(b"@", source, "correspondence is not patch source")

    def test_known_retired_payloads_stay_outside_the_executable_set(self):
        ledger = json.loads((BUNDLES / "intake_status.json").read_text())
        counts = Counter()
        for entry in ledger["entries"]:
            if entry["family"] == "V60":
                self.assertEqual(entry["decision"], "HOLD_DO_NOT_FLASH")
                counts["V60"] += 1
            if entry["family"] in ("V56_REJECTED", "V57_REJECTED"):
                self.assertEqual(entry["decision"], "REJECTED_DO_NOT_FLASH")
                counts[entry["family"]] += 1
        self.assertEqual(counts, {"V60": 2, "V56_REJECTED": 1, "V57_REJECTED": 1})


if __name__ == "__main__":
    unittest.main()
