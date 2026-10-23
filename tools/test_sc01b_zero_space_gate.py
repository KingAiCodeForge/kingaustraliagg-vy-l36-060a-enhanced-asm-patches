"""Public-safe negative controls for SC01B zero-space admission."""
from __future__ import annotations

import importlib.util
import contextlib
import hashlib
import io
import json
import os
from pathlib import Path
import subprocess
import tempfile
from types import SimpleNamespace
import unittest
from unittest import mock

SRC=Path(__file__).with_name("sc01b_zero_space_gate.py")
spec=importlib.util.spec_from_file_location("sc01b_zero_space_gate",SRC)
if spec is None or spec.loader is None:
    raise RuntimeError("Cannot load local checker")
a=importlib.util.module_from_spec(spec)
import sys
sys.modules[spec.name]=a
spec.loader.exec_module(a)
CLI=[sys.executable,*( ["-O"] if sys.flags.optimize else []),"-B",str(SRC)]


class ZeroRomAdmissionTests(unittest.TestCase):
    def fixture(self):
        b=bytearray(a.IMAGE_SIZE)
        b[a.FUEL_CUT_START:a.FUEL_CUT_START+6]=a.FUEL_CUT_BYTES
        b[a.NATIVE_PTR_FILE:a.NATIVE_PTR_FILE+3]=a.NATIVE_FUEL_POINTER
        return bytes(b)

    def synthetic(self, image):
        return a.classify(image,expected_sha=hashlib.sha256(image).hexdigest())

    def test_synthetic_report_does_not_claim_skipped_native_checks(self):
        report=self.synthetic(self.fixture())
        self.assertIsNone(report["known_native_pointers_preserved"])
        self.assertEqual(report["native_cal_reader_signatures"], {
            "total": 7, "checked": 0, "skipped": 7,
            "result": "NOT_CHECKED_SYNTHETIC",
        })
        self.assertIn("SYNTHETIC", report["status"])

    def test_curated_rows_are_separate_from_whole_image_zero_runs(self):
        report=self.synthetic(self.fixture())
        self.assertEqual(report["curated_region_count"],15)
        inventory=report["zero_run_inventory"]
        self.assertEqual(inventory["minimum_size"],64)
        self.assertEqual(inventory["count"],len(inventory["runs"]))
        self.assertEqual(inventory["count"],3)
        self.assertNotEqual(inventory["count"],report["curated_region_count"])

    def test_each_native_reader_signature_is_checked_for_exact_mode(self):
        b=bytearray(self.fixture())
        for offset, signature in a.DIRECT_CAL_REF_SIGNATURES.items():
            b[offset:offset+len(signature)]=signature
        # Isolate signature validation from hash admission using an in-memory
        # test double. No altered firmware file or CLI override is produced.
        digest=mock.Mock()
        digest.hexdigest.return_value=a.EXPECTED_SHA256
        with mock.patch.object(a.hashlib,"sha256",return_value=digest):
            self.assertTrue(a.classify(bytes(b))["known_native_pointers_preserved"])
            for offset in a.DIRECT_CAL_REF_SIGNATURES:
                with self.subTest(offset=hex(offset)):
                    changed=bytearray(b)
                    changed[offset]^=1
                    with self.assertRaisesRegex(ValueError,"native CAL reader signature"):
                        a.classify(bytes(changed))

    def test_zeros_are_not_certified_executable(self):
        report=self.synthetic(self.fixture())
        self.assertEqual(report["approved_patch_spans"],[])
        for row in report["regions"]:
            self.assertTrue(row["all_zero"])
            self.assertFalse(row["executably_free"])

    def test_exact_region_extents(self):
        rows={r["name"]:r for r in self.synthetic(self.fixture())["regions"]}
        self.assertEqual(rows["common_zero_tail"]["size"],347)
        self.assertEqual(rows["bank1_long_zero_span"]["size"],15192)
        self.assertEqual(rows["SC01_old_handler_overlap"]["size"],333)
        self.assertEqual(rows["SC01_old_parameters_overlap"]["size"],5)

    def test_original_sc01_span_is_native_protected(self):
        rows={r["name"]:r for r in self.synthetic(self.fixture())["regions"]}
        self.assertTrue(rows["SC01_old_handler_overlap"]["native_protected_overlaps"])
        self.assertTrue(rows["SC01_old_parameters_overlap"]["native_protected_overlaps"])

    def test_zero_calibration_with_direct_native_read_is_rejected(self):
        rows={r["name"]:r for r in self.synthetic(self.fixture())["regions"]}
        self.assertEqual(rows["common_cal_383"]["size"],383)
        self.assertEqual(rows["common_cal_383"]["qualification"],"REJECT_NATIVE_DIRECT_OPERANDS")
        self.assertTrue(rows["common_cal_383"]["native_protected_overlaps"])
        self.assertFalse(rows["common_cal_383"]["executably_free"])
        self.assertEqual(a.DIRECT_CAL_REF_SIGNATURES[0x17B48].hex(),"f66559")

    def test_zero_transmission_and_tio_regions_are_rejected(self):
        rows={r["name"]:r for r in self.synthetic(self.fixture())["regions"]}
        self.assertEqual(rows["common_cal_306"]["qualification"],
                         "REJECT_XDF_CALIBRATION_OBJECTS")
        self.assertEqual(rows["bank3_tio_zero_span"]["qualification"],
                         "REJECT_TIO_IMAGE")
        self.assertEqual(rows["bank2_zero_tail"]["size"],313)
        self.assertFalse(any(r["executably_free"] for r in rows.values()))

    def test_bank1_file_alias_is_not_a_17bit_cpu_address(self):
        self.assertEqual(a.file_to_cpu(0x0C500),{"view":"BANK1","cpu_address":"0xC500"})
        self.assertEqual(a.file_to_cpu(0x14500),{"view":"BANK2","cpu_address":"0xC500"})
        self.assertEqual(a.file_to_cpu(0x1C500),{"view":"BANK3","cpu_address":"0xC500"})
        self.assertEqual([a.cpu_to_file(0xC500,b) for b in ("BANK1","BANK2","BANK3")],
                         [0x0C500,0x14500,0x1C500])

    def test_cpu_alias_requires_selected_bank(self):
        with self.assertRaises(ValueError):
            a.cpu_to_file(0xC500,"COMMON")
        with self.assertRaises(ValueError):
            a.cpu_to_file(0x1C500,"BANK1")
        with self.assertRaises(ValueError):
            a.file_to_cpu(-1)

    def test_all_zero_cave_mutation_does_not_infer_free(self):
        b=bytearray(self.fixture())
        b[0x3E88]=0x1
        rows={r["name"]:r for r in self.synthetic(bytes(b))["regions"]}
        self.assertFalse(rows["common_zero_tail"]["all_zero"])
        self.assertEqual(rows["common_zero_tail"]["nonzero_bytes"],1)
        self.assertFalse(rows["common_zero_tail"]["executably_free"])

    def test_partial_image_rejected(self):
        with self.assertRaisesRegex(ValueError,"complete"):
            a.classify(bytes(50),expected_sha="0"*64)

    def test_wrong_sha_rejected(self):
        with self.assertRaisesRegex(ValueError,"SHA-256"):
            a.classify(self.fixture())

    def test_native_limiter_guard_rejects_modified_input(self):
        b=bytearray(self.fixture())
        b[a.FUEL_CUT_START]=0x50
        with self.assertRaisesRegex(ValueError,"factory cutoff calibration"):
            self.synthetic(bytes(b))

    def test_no_trampoline_or_patch_builder_interface(self):
        self.assertFalse(hasattr(a,"patch"))
        self.assertFalse(hasattr(a,"emit_bin"))
        self.assertFalse(hasattr(a,"create_trampoline"))


class JsonPublicationTests(unittest.TestCase):
    """Exercise the actual argument parser/main and publication failure paths.

    Synthetic admission is injected at the classifier boundary; the public CLI
    itself still has no way to admit synthetic or altered firmware inputs.
    """

    fixture=ZeroRomAdmissionTests.fixture

    def invoke(self, image_path, output_path):
        classify=a.classify
        fixture_sha=hashlib.sha256(image_path.read_bytes()).hexdigest()
        with mock.patch.object(a,"classify",side_effect=lambda image: classify(image,expected_sha=fixture_sha)):
            out,err=io.StringIO(),io.StringIO()
            with contextlib.redirect_stdout(out),contextlib.redirect_stderr(err):
                code=a.main(["--image",str(image_path),"--json-out",str(output_path)])
        return code,out.getvalue(),err.getvalue()

    def test_cli_publishes_complete_matching_json_exclusively(self):
        with tempfile.TemporaryDirectory() as tmp:
            source=Path(tmp)/"synthetic-input.dat"
            source.write_bytes(self.fixture())
            output=Path(tmp)/"report.json"
            before=source.read_bytes()
            code,stdout,stderr=self.invoke(source,output)
            self.assertEqual((code,stderr),(0,""))
            self.assertEqual(output.read_text(encoding="utf-8"),stdout)
            self.assertEqual(json.loads(stdout)["approved_patch_spans"],[])
            self.assertIsNone(json.loads(stdout)["known_native_pointers_preserved"])
            self.assertEqual(source.read_bytes(),before)
            self.assertEqual({p.name for p in Path(tmp).iterdir()},{source.name,output.name})
            output.write_text("KEEP",encoding="utf-8")
            code,stdout,stderr=self.invoke(source,output)
            self.assertEqual(code,2)
            self.assertEqual(stdout,"")
            self.assertIn("REFUSED",stderr)
            self.assertEqual(output.read_text(encoding="utf-8"),"KEEP")

    def test_cli_never_publishes_partly_written_json(self):
        with tempfile.TemporaryDirectory() as tmp:
            source=Path(tmp)/"synthetic-input.dat"
            source.write_bytes(self.fixture())
            output=Path(tmp)/"report.json"
            publication="rename" if os.name == "nt" else "link"
            real_publish=getattr(os,publication)
            def inspect_complete(source_path,destination_path):
                self.assertFalse(output.exists())
                report=json.loads(Path(source_path).read_text(encoding="utf-8"))
                self.assertEqual(report["curated_region_count"],15)
                return real_publish(source_path,destination_path)
            with mock.patch.object(a.os,publication,side_effect=inspect_complete) as publish:
                code,stdout,stderr=self.invoke(source,output)
            self.assertEqual((code,stderr),(0,""))
            publish.assert_called_once()
            self.assertEqual(json.loads(output.read_text()),json.loads(stdout))

    def test_cli_failed_sync_leaves_no_final_or_temporary_report(self):
        with tempfile.TemporaryDirectory() as tmp:
            source=Path(tmp)/"synthetic-input.dat"
            source.write_bytes(self.fixture())
            output=Path(tmp)/"report.json"
            with mock.patch.object(a.os,"fsync",side_effect=OSError("injected sync failure")):
                code,stdout,stderr=self.invoke(source,output)
            self.assertEqual(code,2)
            self.assertEqual(stdout,"")
            self.assertIn("injected sync failure",stderr)
            self.assertEqual(list(Path(tmp).iterdir()),[source])

    def test_cli_concurrent_destination_creation_is_preserved(self):
        with tempfile.TemporaryDirectory() as tmp:
            source=Path(tmp)/"synthetic-input.dat"
            source.write_bytes(self.fixture())
            output=Path(tmp)/"report.json"
            publication="rename" if os.name == "nt" else "link"
            real_publish=getattr(os,publication)
            def race(source_path,destination_path):
                output.write_text("CONCURRENT",encoding="utf-8")
                return real_publish(source_path,destination_path)
            with mock.patch.object(a.os,publication,side_effect=race):
                code,stdout,stderr=self.invoke(source,output)
            self.assertEqual(code,2)
            self.assertEqual(stdout,"")
            self.assertIn("REFUSED",stderr)
            self.assertEqual(output.read_text(),"CONCURRENT")
            self.assertEqual({p.name for p in Path(tmp).iterdir()},{source.name,output.name})

    def test_cli_refuses_output_that_aliases_input(self):
        with tempfile.TemporaryDirectory() as tmp:
            source=Path(tmp)/"synthetic-input.dat"
            source.write_bytes(self.fixture())
            before=source.read_bytes()
            code,stdout,stderr=self.invoke(source,source)
            self.assertEqual(code,2)
            self.assertEqual(stdout,"")
            self.assertIn("REFUSED",stderr)
            self.assertEqual(source.read_bytes(),before)
            self.assertEqual(list(Path(tmp).iterdir()),[source])

    def test_cli_reports_published_when_posix_temporary_cleanup_fails(self):
        with tempfile.TemporaryDirectory() as tmp:
            source=Path(tmp)/"synthetic-input.dat"
            source.write_bytes(self.fixture())
            before=source.read_bytes()
            output=Path(tmp)/"report.json"
            def completed_link(source_path,destination_path):
                # Model successful exclusive link publication on Windows too;
                # actual filesystem hard-link atomicity is not tested here.
                with Path(destination_path).open("xb") as dst:
                    dst.write(Path(source_path).read_bytes())
            posix=SimpleNamespace(name="posix",fsync=os.fsync,
                                  link=mock.Mock(side_effect=completed_link))
            with mock.patch.object(a,"os",posix),mock.patch.object(
                    Path,"unlink",side_effect=PermissionError("injected cleanup failure")):
                code,stdout,stderr=self.invoke(source,output)
            self.assertEqual(code,0,stderr)
            self.assertEqual(json.loads(stdout),json.loads(output.read_text()))
            self.assertIn("WARNING: report published",stderr)
            self.assertIn("injected cleanup failure",stderr)
            self.assertNotIn("REFUSED",stderr)
            posix.link.assert_called_once()
            leftovers=list(Path(tmp).glob(".report.json.*.tmp"))
            self.assertEqual(len(leftovers),1)
            self.assertIn(str(leftovers[0]),stderr)
            self.assertEqual(leftovers[0].read_bytes(),output.read_bytes())
            self.assertEqual(source.read_bytes(),before)

    def test_cli_refuses_posix_publication_failure_without_overwriting(self):
        with tempfile.TemporaryDirectory() as tmp:
            source=Path(tmp)/"synthetic-input.dat"
            source.write_bytes(self.fixture())
            before=source.read_bytes()
            output=Path(tmp)/"report.json"
            posix=SimpleNamespace(name="posix",fsync=os.fsync,
                                  link=mock.Mock(side_effect=OSError("injected link failure")))
            with mock.patch.object(a,"os",posix):
                code,stdout,stderr=self.invoke(source,output)
            self.assertEqual(code,2)
            self.assertEqual(stdout,"")
            self.assertIn("REFUSED: injected link failure",stderr)
            self.assertNotIn("report published",stderr)
            self.assertFalse(output.exists())
            self.assertEqual(list(Path(tmp).iterdir()),[source])
            output.write_text("KEEP",encoding="utf-8")
            def exclusive_link(source_path,destination_path):
                with Path(destination_path).open("xb") as dst:
                    dst.write(Path(source_path).read_bytes())
            posix.link.side_effect=exclusive_link
            with mock.patch.object(a,"os",posix):
                code,stdout,stderr=self.invoke(source,output)
            self.assertEqual(code,2)
            self.assertEqual(stdout,"")
            self.assertIn("REFUSED",stderr)
            self.assertEqual(output.read_text(),"KEEP")
            self.assertEqual(source.read_bytes(),before)
            self.assertEqual({p.name for p in Path(tmp).iterdir()},{source.name,output.name})

    def test_actual_cli_refuses_synthetic_source_without_output(self):
        with tempfile.TemporaryDirectory() as tmp:
            source=Path(tmp)/"synthetic-input.dat"
            source.write_bytes(self.fixture())
            output=Path(tmp)/"report.json"
            run=subprocess.run([*CLI,"--image",str(source),
                                "--json-out",str(output)],capture_output=True,text=True)
            self.assertEqual(run.returncode,2)
            self.assertEqual(run.stdout,"")
            self.assertIn("SHA-256 mismatch",run.stderr)
            self.assertFalse(output.exists())


class ExactSourceCliTests(unittest.TestCase):
    @unittest.skipUnless(os.environ.get("VY_V1_0A_BIN"),"optional exact-source checker input not supplied")
    def test_actual_cli_exact_source_report_and_exclusive_output(self):
        source=Path(os.environ["VY_V1_0A_BIN"])
        before=hashlib.sha256(source.read_bytes()).hexdigest()
        self.assertEqual(before,a.EXPECTED_SHA256)
        with tempfile.TemporaryDirectory() as tmp:
            output=Path(tmp)/"report.json"
            command=[*CLI,"--image",str(source),"--json-out",str(output)]
            run=subprocess.run(command,capture_output=True,text=True)
            self.assertEqual(run.returncode,0,run.stderr)
            self.assertEqual(run.stderr,"")
            self.assertEqual(output.read_text(encoding="utf-8"),run.stdout)
            report=json.loads(run.stdout)
            self.assertTrue(report["known_native_pointers_preserved"])
            self.assertEqual(report["native_cal_reader_signatures"], {
                "total":7,"checked":7,"skipped":0,"result":"PASS",
            })
            self.assertEqual(report["curated_region_count"],15)
            self.assertEqual(report["zero_run_inventory"]["count"],14)
            self.assertEqual(report["approved_patch_spans"],[])
            self.assertFalse(any(row["executably_free"] for row in report["regions"]))
            saved=output.read_bytes()
            repeat=subprocess.run(command,capture_output=True,text=True)
            self.assertEqual(repeat.returncode,2)
            self.assertEqual(repeat.stdout,"")
            self.assertIn("REFUSED",repeat.stderr)
            self.assertEqual(output.read_bytes(),saved)
            self.assertEqual(list(Path(tmp).iterdir()),[output])
        self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(),before)


if __name__=="__main__":
    unittest.main(verbosity=2)
