"""Separate MPD226/232 manufacturer members qualify a manual Bitwig-mode core."""
import hashlib
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class MPD2BitwigTests(unittest.TestCase):
    def test_manual_model_specific_main_ports_and_bounded_native_banks(self):
        by = {p['id']: p for p in json.loads((ROOT / 'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']}
        for model in [226, 232]:
            name = f'Akai MPD{model}'; self.assertTrue(name in by, name); p = by[name]
            self.assertEqual((len(p['inputs']), len(p['outputs']), p['autoSelect'], p['inputProtocol']), (100, 0, False, 'mpd2Bitwig'))
            self.assertEqual((p['startup'], p['shutdown']), ([], [])); self.assertNotIn('audioOutput', p)
            pads = [r for r in p['inputs'] if r['kind'] == 'note']; self.assertEqual(len(pads), 64)
            self.assertTrue(all(r['channel'] == 9 and 36 <= r['number'] <= 99 for r in pads))
            controls = [r for r in p['inputs'] if r['kind'] == 'control']; self.assertEqual(len(controls), 36)
            self.assertTrue(all(r['channel'] in [1, 2, 3] and r['number'] in list(range(30, 34)) + list(range(40, 44)) + list(range(50, 54)) for r in controls))
            self.assertTrue(all(r['encoding'] == 'signedStep' for r in controls if r['number'] >= 50))
            self.assertNotIn(f'MPD{model} Remote', p['aliases'])

    def test_separate_own_members_and_shared_input_facts_reach_catalogue(self):
        from mpd2_bitwig import MPD2_REFERENCES
        catalogue = json.loads((ROOT / 'docs/coordination/controller-catalogue.json').read_text())
        by = {d['name']: d for d in catalogue['definitions'] if d['id'].startswith('reviewed:mpd2-bitwig-')}
        for name, ref in MPD2_REFERENCES.items():
            self.assertTrue(name in by, name); self.assertEqual(by[name]['source'], ref)
            for f in ref['files']:
                path = ROOT / f['cachePath']
                if path.exists(): self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), f['sha256'])
            path = ROOT / ref['files'][1]['cachePath']
            if path.exists():
                source = path.read_text(); self.assertIn(name.split(' ', 1)[1], source)
                self.assertIn('Port A', source); self.assertIn('Remote', source)
