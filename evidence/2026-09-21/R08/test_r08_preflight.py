"""Host-only R08 intake regressions; no firmware output or hardware operation."""
import hashlib
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

import build_launch_patch as builder
import verify_launch as verifier


class R08PreflightTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        source = os.environ.get('VY_V1_0A_BIN')
        cls.reference_image = Path(source).read_bytes() if source else None
        if cls.reference_image is not None:
            if hashlib.sha256(cls.reference_image).hexdigest() != builder.SOURCE_SHA256:
                raise ValueError('VY_V1_0A_BIN is not the exact documented reference')

    def get_reference(self):
        if self.__class__.reference_image is None:
            self.skipTest('set VY_V1_0A_BIN for the exact local reference')
        return self.__class__.reference_image

    def test_counterfeit_with_matching_local_preimages_is_rejected(self):
        fake = bytearray(0x20000)
        fake[builder.START:builder.START + len(builder.SIGNATURE)] = builder.SIGNATURE
        fake[0x4008] = 0xAA
        self.assertNotEqual(hashlib.sha256(fake).hexdigest(), builder.SOURCE_SHA256)
        with self.assertRaisesRegex(ValueError, 'SHA-256'):
            builder.validate_base(bytes(fake))

    def test_empty_parent_is_rejected(self):
        with self.assertRaisesRegex(ValueError, '131072'):
            builder.validate_base(b'')

    def test_runtime_requirement_is_not_assert(self):
        with self.assertRaisesRegex(ValueError, 'negative control'):
            verifier.require(False, 'negative control')

    def verify_empty_inputs(self, optimized):
        module_root = Path(__file__).resolve().parent
        runner = (
            'import pathlib,runpy,sys; '
            'root=pathlib.Path(sys.argv[1]); sys.path.insert(0,str(root)); '
            'sys.argv=[str(root/"verify_launch.py"),sys.argv[2],sys.argv[3]]; '
            'runpy.run_path(str(root/"verify_launch.py"),run_name="__main__")'
        )
        with tempfile.TemporaryDirectory() as directory:
            a, b = Path(directory) / 'empty-a.bin', Path(directory) / 'empty-b.bin'
            a.write_bytes(b'')
            b.write_bytes(b'')
            command = [sys.executable, '-I', '-B']
            if optimized:
                command.append('-O')
            result = subprocess.run(
                [*command, '-c', runner, str(module_root), str(a), str(b)],
                cwd=directory, capture_output=True, text=True, timeout=15)
            self.assertNotEqual(result.returncode, 0)
            self.assertNotIn('PASS:', result.stdout)
            self.assertIn('131072', result.stderr)
            self.assertEqual(a.stat().st_size, 0)
            self.assertEqual(b.stat().st_size, 0)

    def test_empty_verifier_rejected_in_normal_python(self):
        self.verify_empty_inputs(False)

    def test_empty_verifier_rejected_in_optimized_python(self):
        self.verify_empty_inputs(True)

    def test_exact_parent_build_retains_recorded_output_identity(self):
        source = self.get_reference()
        candidate = builder.build(source)
        self.assertEqual(hashlib.sha256(candidate).hexdigest(),
                         'f4138afe02c2a8bcb7fea41294220908ea1ea78e2a3fbd0cc564be5d87dc9b73')
        self.assertEqual(sum(a != b for a, b in zip(source, candidate)), 72)
        self.assertEqual(candidate[0x4008], source[0x4008])
        self.assertEqual(hashlib.sha256(source).hexdigest(), builder.SOURCE_SHA256)

    def test_one_change_outside_local_preimages_is_rejected(self):
        changed = bytearray(self.get_reference())
        changed[0x6000] ^= 1
        with self.assertRaisesRegex(ValueError, 'SHA-256'):
            builder.validate_base(changed)

    def test_selected_bounded_controls(self):
        source = self.get_reference()
        candidate = builder.build(source)
        for speed, rpm in ((0, 80), (0, 81), (2, 80), (2, 81)):
            with self.subTest(speed=speed, rpm=rpm):
                self.assertEqual(verifier.run(candidate, speed, rpm, 0, 0, 0)['cut'], rpm > 80)
        self.assertEqual(verifier.run(candidate, 3, 81, 0, 0, 0),
                         verifier.run(source, 3, 81, 0, 0, 0))


if __name__ == '__main__':
    unittest.main()
