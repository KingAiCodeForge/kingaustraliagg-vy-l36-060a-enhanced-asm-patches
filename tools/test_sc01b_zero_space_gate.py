"""Public-safe negative controls for SC01B zero-space admission."""
from __future__ import annotations

import importlib.util
from pathlib import Path
import tempfile
import unittest

SRC=Path(__file__).with_name("sc01b_zero_space_gate.py")
spec=importlib.util.spec_from_file_location("sc01b_zero_space_gate",SRC)
if spec is None or spec.loader is None:
    raise RuntimeError("Cannot load local checker")
a=importlib.util.module_from_spec(spec)
import sys
sys.modules[spec.name]=a
spec.loader.exec_module(a)


class ZeroRomAdmissionTests(unittest.TestCase):
    def fixture(self):
        b=bytearray(a.IMAGE_SIZE)
        b[a.FUEL_CUT_START:a.FUEL_CUT_START+6]=a.FUEL_CUT_BYTES
        b[a.NATIVE_PTR_FILE:a.NATIVE_PTR_FILE+3]=a.NATIVE_FUEL_POINTER
        return bytes(b)

    def synthetic(self, image):
        import hashlib
        return a.classify(image,expected_sha=hashlib.sha256(image).hexdigest())

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

    def test_output_path_does_not_exist_before_atomic_creation(self):
        with tempfile.TemporaryDirectory() as tmp:
            p=Path(tmp)/"report.json"
            self.assertFalse(p.exists())
            with p.open("x",encoding="utf-8") as f:
                f.write("KEEP")
            with self.assertRaises(FileExistsError):
                p.open("x",encoding="utf-8")
            self.assertEqual(p.read_text(encoding="utf-8"),"KEEP")


if __name__=="__main__":
    unittest.main(verbosity=2)
