"""Independent public standalone cores reject sibling and copied-role assumptions."""
import hashlib
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class LegacyStandaloneCoresTests(unittest.TestCase):
    def test_independent_activation_counts_and_owned_directional_wheels(self):
        records = json.loads((ROOT / 'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']
        by = {p['id']: p for p in records}
        for name, count, lamps, automatic in [('Denon DJ HD2500', 24, 4, False), ('Stanton SCS.4DJ', 44, 6, True), ('Gemini FirstMix I/O', 31, 8, True)]:
            self.assertTrue(name in by, name); p = by[name]
            self.assertEqual((len(p['inputs']), len(p['outputs']), p['autoSelect']), (count, lamps, automatic))
            self.assertEqual((p['startup'], p['shutdown']), ([], []))
            self.assertNotIn('audioOutput', p)
        first = by['Gemini FirstMix I/O']
        wheels = [r for r in first['inputs'] if r['encoding'] == 'unsignedCount']
        self.assertEqual([(r['number'], r['inverted']) for r in wheels], [(1, True), (20, False), (2, True), (21, False)])
        self.assertTrue(all(r['argument'] == 350 and r['requiresTouch'] for r in wheels))
        self.assertFalse(any(r['action'].startswith(('level', 'mid', 'cueMix', 'monitor')) for r in first['inputs']))
        self.assertFalse(any(r['action'].startswith('hotcue') for r in by['Stanton SCS.4DJ']['inputs']))

    def test_independent_pinned_public_sources_reach_catalogue(self):
        from legacy_standalone_cores import STANDALONE_REFERENCES
        catalogue = json.loads((ROOT / 'docs/coordination/controller-catalogue.json').read_text())
        by = {d['name']: d for d in catalogue['definitions'] if d['id'].startswith('reviewed:legacy-standalone-')}
        for name, ref in STANDALONE_REFERENCES.items():
            self.assertTrue(name in by, name); self.assertEqual(by[name]['source'], ref)
            for source in ref['files']:
                path = ROOT / source['cachePath']
                if path.exists(): self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), source['sha256'])
