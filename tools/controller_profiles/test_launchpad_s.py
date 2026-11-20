"""Launchpad S grid and colour facts come from its own manufacturer manual."""
import hashlib
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class LaunchpadSTests(unittest.TestCase):
    def test_independent_grid_setup_and_feedback(self):
        rows = json.loads((ROOT / 'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']
        p = next(p for p in rows if p['id'] == 'Novation Launchpad S')
        self.assertEqual((len(p['inputs']), len(p['outputs']), p['autoSelect'], p['role']), (64, 52, True, 'accessory'))
        self.assertEqual(p['startup'], [[176, 0, 0], [176, 0, 1], [176, 0, 32]])
        self.assertEqual(p['shutdown'], [[176, 0, 0]])
        self.assertEqual(p['startupAbort'], p['shutdown'])
        self.assertEqual({(r['kind'], r['channel'], r['number']) for r in p['inputs']}, {('note', 0, 16 * y + x) for y in range(8) for x in range(8)})
        self.assertTrue(all(r['onValue'] in [15, 60, 63] and r['offValue'] == 12 and r['offUsesNoteOn'] for r in p['outputs']))
        self.assertNotIn('audioOutput', p)
        self.assertNotIn('Launchpad', p['aliases'])

    def test_own_source_pins(self):
        from launchpad_s import LAUNCHPAD_S_REFERENCES
        ref = LAUNCHPAD_S_REFERENCES['Novation Launchpad S']
        catalogue = json.loads((ROOT / 'docs/coordination/controller-catalogue.json').read_text())
        self.assertEqual(next(d for d in catalogue['definitions'] if d['id'] == 'manufacturer:launchpad-s-native-grid')['source'], ref)
        for f in ref['files']:
            p = ROOT / f['cachePath']
            if p.exists(): self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(), f['sha256'])
