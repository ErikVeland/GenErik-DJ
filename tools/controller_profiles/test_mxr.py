"""Separate MXR manufacturer tables control channels, model differences and lamps."""
import hashlib
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class MXRTests(unittest.TestCase):
    def test_independent_model_contracts_and_controller_mode_channels(self):
        records = json.loads((ROOT / 'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']
        by = {p['id']: p for p in records}
        for size, inputs, lamps, automatic in [(10, 51, 8, False), (14, 75, 14, True), (19, 71, 10, True)]:
            name = f'American Audio {size}MXR'
            self.assertTrue(name in by, name)
            p = by[name]; ch = 0 if size == 10 else 2
            self.assertEqual((len(p['inputs']), len(p['outputs']), p['autoSelect']), (inputs, lamps, automatic))
            self.assertEqual((p['startup'], p['shutdown']), ([], []))
            self.assertTrue(all(r['channel'] == ch for r in p['inputs'] if not r.get('releaseOnly')))
            self.assertTrue(all(r['channel'] == 0 and r['onValue'] == 127 and r['offValue'] == 0 for r in p['outputs']))
            sync = next(r for r in p['inputs'] if r['action'] == 'syncB' and not r.get('releaseOnly'))
            self.assertEqual(sync['number'], 54 if size == 10 else 55)
            self.assertFalse(any(r['action'].startswith(('jog', 'tempo', 'shift')) for r in p['inputs']))
        self.assertFalse(any(r['action'].startswith('filter') for r in by['American Audio 19MXR']['inputs']))

    def test_primary_pdf_hashes_and_detailed_catalogue_sources(self):
        from mxr import MXR_REFERENCES
        catalogue = json.loads((ROOT / 'docs/coordination/controller-catalogue.json').read_text())
        by = {d['name']: d for d in catalogue['definitions'] if d['id'].startswith('manufacturer:mxr-')}
        for name, ref in MXR_REFERENCES.items():
            self.assertTrue(name in by, name)
            self.assertEqual(by[name]['source'], ref)
            path = ROOT / ref['cachePath']
            if path.exists(): self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), ref['sha256'])
