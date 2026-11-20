"""Independent single-player facts retain bounded layers, contacts and identity."""
import hashlib
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
NAMES = ['Audiophony CDX6', 'CITRONIC MPCD-X3', 'Stanton CMP.800', 'Synq DMC-1000']


class LegacySinglePlayerTests(unittest.TestCase):
    def test_separate_recipes_reject_generic_identity_and_unqualified_functions(self):
        by = {p['id']: p for p in json.loads((ROOT / 'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']}
        for name in NAMES:
            self.assertTrue(name in by, name); p = by[name]
            self.assertEqual((len(p['inputs']), len(p['outputs'])), (68 if name.startswith('Synq') else 66, 8))
            self.assertEqual(p['autoSelect'], name.startswith('Synq'))
            self.assertEqual(p['inputProtocol'], 'legacySinglePlayer')
            self.assertFalse(set(p['aliases']) & {'MIDI', 'MIDI B', 'USB Audio Device'})
            self.assertEqual((p['startup'], p['shutdown']), ([], [])); self.assertNotIn('audioOutput', p)
            self.assertFalse(any(r['action'].startswith(('hotcue', 'sync', 'level', 'gain', 'pause')) for r in p['inputs']))
            wheels = [r for r in p['inputs'] if r['action'].startswith('jog') and r['kind'] != 'note']
            self.assertEqual(len(wheels), 2)
            self.assertTrue(all(r['argument'] == 1024 and r['requiresTouch'] for r in wheels))
            self.assertTrue(all(r['kind'] == 'note' and r['offUsesNoteOn'] for r in p['outputs']))

    def test_each_recipe_has_its_own_pinned_manufacturer_guide(self):
        from legacy_single_players import SINGLE_PLAYER_REFERENCES
        catalogue = json.loads((ROOT / 'docs/coordination/controller-catalogue.json').read_text())
        by = {d['name']: d for d in catalogue['definitions'] if d['id'].startswith('reviewed:legacy-single-')}
        hashes = set()
        for name, ref in SINGLE_PLAYER_REFERENCES.items():
            self.assertIn(name, by); self.assertEqual(by[name]['source'], ref)
            hashes.add(ref['files'][0]['sha256'])
            for source in ref['files']:
                path = ROOT / source['cachePath']
                if path.exists(): self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), source['sha256'])
        self.assertEqual(len(hashes), 4)
