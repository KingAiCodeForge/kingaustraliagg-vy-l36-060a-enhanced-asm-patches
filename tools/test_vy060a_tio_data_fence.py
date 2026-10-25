"""Negative and real-image tests for VY TIO code/data classification."""
import hashlib
import importlib.util
from pathlib import Path
import tempfile
import unittest

SRC = Path(__file__).resolve().parents[1] / 'tools' / 'vy060a_tio_data_fence.py'
spec = importlib.util.spec_from_file_location('tio_data_fence', SRC)
assert spec is not None and spec.loader is not None
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)


class TioFenceTests(unittest.TestCase):
    def sample(self):
        b = bytearray(m.IMAGE_SIZE)
        for name, a, z, h in m.SECTIONS:
            self.assertEqual(z - a, {'tio_translation':80, 'tio_index':32,
            'tio_requests':6,'tio_register_initialisation':18,'tio_microcode':2048}[name])
        b[m.STARTUP_ENTRY[0]:m.STARTUP_ENTRY[0]+len(m.STARTUP_ENTRY[1])] = m.STARTUP_ENTRY[1]
        return b

    def test_region_geometry_and_byte_conservation(self):
        self.assertEqual(m.DATA_END - m.DATA_START, 2184)
        self.assertEqual(sum(z-a for _,a,z,_ in m.SECTIONS), 2184)
        for i in range(4):self.assertEqual(m.SECTIONS[i][2],m.SECTIONS[i+1][1])
        self.assertEqual(m.STARTUP_ENTRY[0],m.DATA_END)

    def test_wrong_image_length(self):
        with self.assertRaises(ValueError):m.image_audit(b'\x00')

    def test_unrecognized_image_must_not_qualify(self):
        d=m.image_audit(self.sample())
        self.assertEqual(d['classification'],'UNQUALIFIED_TIO_BYTES')
        self.assertIsNone(d['recognized_full_image'])

    def test_optional_listing_tags_data_not_executable(self):
        listing=b'\n'.join([
          b'LC3AE: 39 rts',
          b'LC3AF: 00 test',
          b'LC3B0: 20 FD bra $c3af',
          b'LCC36: 00 test',
          b'LCC37: 8D 18 bsr $cc51',
          b'LCC39: BD C3 AF jsr $c3af',
        ])
        r=m.listing_audit(listing)
        self.assertEqual(r['tio_data_rows_mislabelled_as_hc11'],3)
        self.assertEqual(r['false_control_flow_rows'],1)
        self.assertEqual(r['false_control_flow_by_mnemonic'],{'bra':1})
        self.assertEqual(r['direct_branch_into_data_candidates_from_outside'][0]['target_cpu'],'0xC3AF')
        self.assertEqual(r['other_listing_rows'],3)

    def test_crossing_boundary_is_anomaly(self):
        r=m.listing_audit(b'LC3AD: 00 00 00 test\nLCC36: 00 00 test\n')
        self.assertEqual(len(r['straddling_rows']),2)

    def test_reject_non_bank3_listing(self):
        with self.assertRaisesRegex(ValueError,'non-bank3'):
            m.listing_audit(b'L2000: 7E 2B AF jmp $2baf\n')

    def test_data_not_entire_bank_and_no_caves(self):
        r=m.analyze([], listing=self._listing())
        self.assertFalse(r['firmware_qualified'])
        self.assertEqual(r['safe_code_caves'],[])
        self.assertEqual(r['listing']['tio_data_rows_mislabelled_as_hc11'],1)

    def _listing(self):
        d=tempfile.TemporaryDirectory()
        self.addCleanup(d.cleanup)
        p=Path(d.name)/'b3.asm'
        p.write_text('LC3AF: 00 test\n')
        return p

    def test_output_not_written_over_image(self):
        with tempfile.TemporaryDirectory() as d:
            im=Path(d)/'source.bin';im.write_bytes(bytes(self.sample()))
            before=hashlib.sha256(im.read_bytes()).hexdigest()
            r=m.analyze([im]);self.assertIsNone(r['images'][0]['recognized_full_image'])
            self.assertEqual(hashlib.sha256(im.read_bytes()).hexdigest(),before)

    def test_tio_mutation_remains_unqualified(self):
        path=Path(__file__).resolve().parents[1]/'inputs'/'Enhanced_v1.0a_exact.bin'
        if not path.is_file():self.skipTest('parent not supplied')
        b=bytearray(path.read_bytes());b[m.DATA_START+8]^=1
        r=m.image_audit(bytes(b))
        self.assertEqual(r['classification'],'UNQUALIFIED_TIO_BYTES')
        self.assertFalse(r['tio_data_identical_to_source'])
        self.assertIsNone(r['recognized_full_image'])

    def test_outside_tio_mutation_does_not_prove_full_image(self):
        path=Path(__file__).resolve().parents[1]/'inputs'/'Enhanced_v1.0a_exact.bin'
        if not path.is_file():self.skipTest('parent not supplied')
        b=bytearray(path.read_bytes());b[0x3000]^=1
        r=m.image_audit(bytes(b))
        self.assertEqual(r['classification'],'TIO_MATCH_BUT_IMAGE_UNRECOGNIZED')
        self.assertTrue(r['tio_data_identical_to_source'])
        self.assertIsNone(r['recognized_full_image'])

    def test_actual_parent_and_stock_if_present(self):
        root=Path(__file__).resolve().parents[1]/'inputs'
        names={'Enhanced_v1.0a_exact.bin':'ENHANCED_V1_0A',
               'Enhanced_v1.1a_exact.bin':'ENHANCED_V1_1A',
               'stock_92118883.bin':'92118883_STOCK'}
        if not all((root/x).is_file() for x in names):
            self.skipTest('Exact real image inputs intentionally omitted from GitHub')
        r=m.analyze([root/n for n in names]);self.assertTrue(r['all_present_known_images_match'])
        self.assertTrue(r['byte_identity_across_provided_images'])
        self.assertTrue(all(x['startup_entry_matches_exact_parent'] for x in r['images']))
        for result in r['images']:
            self.assertEqual(result['recognized_full_image'],names[Path(result['path_label']).name])
            self.assertTrue(all(s['byte_identity_match'] for s in result['tio_sections']))


if __name__ == '__main__':unittest.main()