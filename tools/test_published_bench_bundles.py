"""Check the shipped artifact set without a private reference or hardware."""
from collections import Counter
import json
from pathlib import Path
import re
import subprocess
import sys
import unittest

try:
    from .verify_bench_bundle import validate_bundle, _validate_bytes, LEGACY_SC01
except ImportError:
    from verify_bench_bundle import validate_bundle, _validate_bytes, LEGACY_SC01


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
                self.assertFalse(report["release_ready"])
                digest = report["binary_sha256"]
                self.assertNotIn(digest, identities, "publish shared controls once")
                identities[digest] = path.relative_to(BUNDLES).as_posix()
        covered = 0
        for entry in ledger["entries"]:
            if entry["decision"] == "PUBLISHED_BENCH_WIP":
                self.assertEqual(identities.get(entry["sha256"]), entry["bundle"])
                covered += 1
                if entry["sha256"] in LEGACY_SC01:
                    self.assertEqual(entry["current_disposition"]["status"], "HISTORICAL_DO_NOT_FLASH")
                    self.assertFalse(entry["current_disposition"]["release_ready"])
            else:
                self.assertIsNone(entry["bundle"])
        self.assertEqual(covered, ledger["covered_index_rows"])
        self.assertEqual(len(ledger["entries"]), ledger["indexed_rows"])
        self.assertEqual(ledger["indexed_rows"], 57)
        self.assertEqual(ledger["hardware_qualified_images"], 0)
        self.assertEqual(ledger["release_ready_images"], 0)
        self.assertEqual(ledger["current_bench_wip_images"], 27)
        self.assertEqual(ledger["historical_do_not_flash_images"], len(LEGACY_SC01))

    def test_sc01_integrity_pass_is_quarantined_and_not_release_eligible(self):
        expected = {
            "sc01-3000-2900-active": "6e63865810f452c310b83a368a0f2ee9ab942f6a53d3e38af8d2215c302a662a",
            "sc01-3000-2900-control": "7670fcc475f7273f8a2e924466a10eb369499209e2ac90c8b098ba2dd41241a3",
        }
        tool = ROOT / "tools" / "verify_bench_bundle.py"
        for name, digest in expected.items():
            path = BUNDLES / name / "manifest.json"
            before = {p.name: p.read_bytes() for p in path.parent.iterdir()}
            for flags, code in (([], 0), (["--require-release-ready"], 1)):
                with self.subTest(bundle=name, flags=flags):
                    result = subprocess.run([sys.executable, "-B", str(tool), *flags, str(path)],
                                            capture_output=True, text=True, check=False)
                    self.assertEqual(result.returncode, code, result.stdout + result.stderr)
                    self.assertEqual(result.stderr, "")
                    data = json.loads(result.stdout)
                    report = data["results"][0]["report"]
                    self.assertEqual(report["static_checks"], "PASS")
                    self.assertEqual(report["binary_sha256"], digest)
                    self.assertEqual(report["declared_status"], "WIP_BENCH_FLASH_ONLY")
                    self.assertEqual(report["status"], "HISTORICAL_DO_NOT_FLASH")
                    self.assertFalse(report["release_ready"])
                    self.assertEqual(data["ok"], not flags)
            self.assertEqual({p.name: p.read_bytes() for p in path.parent.iterdir()}, before)

    def test_release_gate_rejects_all_current_profiles_but_retains_integrity_reports(self):
        paths = sorted(BUNDLES.glob("*/manifest.json"))
        result = subprocess.run([sys.executable, "-B", str(ROOT / "tools" / "verify_bench_bundle.py"),
                                 "--require-release-ready", *map(str, paths)],
                                capture_output=True, text=True, check=False)
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertEqual(result.stderr, "")
        data = json.loads(result.stdout)
        self.assertFalse(data["ok"])
        self.assertFalse(data["release_ready"])
        self.assertEqual(data["ok_scope"], "release_eligibility")
        self.assertEqual(len(data["results"]), 29)
        for item in data["results"]:
            with self.subTest(manifest=item["manifest"]):
                self.assertFalse(item["ok"])
                self.assertEqual(item["report"]["static_checks"], "PASS")
                self.assertFalse(item["report"]["release_ready"])
                self.assertIn("not release-ready", item["error"])

    def test_sc01_quarantine_survives_renaming_and_old_or_false_family_metadata(self):
        for path in sorted(BUNDLES.glob("sc01-*/manifest.json")):
            manifest = json.loads(path.read_text())
            binary = (path.parent / manifest["binary"]["path"]).read_bytes()
            asm = (path.parent / manifest["asm"]["path"]).read_bytes()
            manifest.pop("current_disposition")  # Historical downloaded manifest.
            manifest["family"] = "INNOCENT_LOOKING_NAME"
            manifest["profile"] = "control"
            manifest["binary"]["path"] = "renamed_WIP_BENCH_FLASH_ONLY.bin"
            manifest["asm"]["path"] = "renamed_WIP_BENCH_FLASH_ONLY.asm"
            with self.subTest(bundle=path.parent.name):
                report = _validate_bytes(manifest, binary, asm)
                self.assertEqual(report["static_checks"], "PASS")
                self.assertEqual(report["status"], "HISTORICAL_DO_NOT_FLASH")
                self.assertFalse(report["release_ready"])
                self.assertIn(report["binary_sha256"], LEGACY_SC01)

    def test_current_sc01_warnings_override_preserved_historical_labels(self):
        front = (ROOT / "README.md").read_text(encoding="utf-8")
        self.assertIn("LEGACY SC01 ACTIVE AND DISABLED: DO NOT FLASH", front)
        index = (BUNDLES / "README.md").read_text(encoding="utf-8")
        unqualified, historical = index.split("## Historical SC01 quarantine", 1)
        self.assertNotIn("| SC01 |", unqualified)
        self.assertIn("bench-wip-2026.10.20", historical)
        self.assertIn("manual", historical)
        for path in BUNDLES.glob("sc01-*/manifest.json"):
            manifest = json.loads(path.read_text())
            self.assertEqual(manifest["status"], "WIP_BENCH_FLASH_ONLY")
            self.assertEqual(manifest["current_disposition"]["status"], "HISTORICAL_DO_NOT_FLASH")
            notes = (path.parent / "README.md").read_text(encoding="utf-8")
            self.assertIn("HISTORICAL_DO_NOT_FLASH", notes)
            self.assertIn("--require-release-ready", notes)

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
