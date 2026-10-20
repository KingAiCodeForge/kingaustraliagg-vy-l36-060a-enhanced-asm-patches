"""Regression tests for retired v38; importing tests must never patch a BIN."""
import contextlib
import io
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
try:
    from . import apply_spark_cut_v38 as retired
except ImportError:
    import apply_spark_cut_v38 as retired
class RetiredV38Tests(unittest.TestCase):
    def test_legacy_functions_refuse(self):
        for function in (retired.verify_binary, retired.verify_free_space,
                         retired.apply_patch, retired.undo_patch):
            with self.subTest(function=function.__name__):
                with self.assertRaises(retired.RetiredPatchError):
                    function(b"untrusted input", 3000)
    def test_main_reports_retirement(self):
        stream = io.StringIO()
        with contextlib.redirect_stderr(stream):
            self.assertEqual(retired.main(), 2)
        self.assertIn("REFUSED", stream.getvalue())
    def test_cli_never_creates_output(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for option in ([], ["--undo"], ["--rpm", "3000"]):
                output = root / "must-not-exist.bin"
                result = subprocess.run(
                    [sys.executable, str(Path(retired.__file__).resolve()),
                     str(root / "missing.bin"), str(output), *option],
                    cwd=root, capture_output=True, text=True, check=False)
                self.assertEqual(result.returncode, 2)
                self.assertIn("REFUSED", result.stderr)
                self.assertFalse(output.exists())
if __name__ == "__main__":
    unittest.main()
