"""PMX-20 uses common manufacturer/specification facts and excludes conflicts."""
import hashlib
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class PMX20Tests(unittest.TestCase):
    def test_independent_manual_core_and_optional_lamps(self):
        profiles = json.loads((ROOT / 'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']
        p = next(p for p in profiles if p['id'] == 'Gemini PMX20')
        self.assertEqual((len(p['inputs']), len(p['outputs']), p['autoSelect'], p['role']), (76, 40, False, 'accessory'))
        self.assertEqual((p['startup'], p['shutdown']), ([], [])); self.assertNotIn('audioOutput', p)
        self.assertEqual(len(p['bankChanges']), 12)
        for ch, deck in enumerate('abcd'):
            rows = [r for r in p['inputs'] if r.get('targetDeck') == deck]
            self.assertEqual({r['number'] for r in rows if r['action'].startswith('hotcue')}, set(range(1, 9)))
            for slot in range(8):
                row = next(r for r in rows if r['action'].startswith(f'hotcue{slot + 1}'))
                self.assertEqual((row['channel'], row['number']), (ch, 8 - slot))
        self.assertTrue(all(r['onValue'] == 1 and r['offValue'] == 0 and r['offUsesNoteOn'] for r in p['outputs']))
        self.assertFalse(any(r['number'] in [33, 34, 64] for r in p['outputs']))

    def test_disputed_and_unqualified_controls_stay_inactive(self):
        from pmx20 import pmx20_profiles
        p = pmx20_profiles()[0]
        self.assertFalse(any(r['channel'] == 4 and r['kind'] == 'note' and r['number'] in [68, 69, 70] for r in p['inputs']))
        self.assertFalse(any(r['kind'] == 'control' and r['number'] == 66 for r in p['inputs']))
        self.assertEqual({r['targetDeck'] for r in p['inputs'] if r['action'].startswith('load')}, {'a','b'})
        self.assertFalse(any(r['action'].startswith(('play', 'cuePreview', 'sync', 'jog', 'tempo', 'fx')) for r in p['inputs']))

    def test_own_source_pins_and_definition(self):
        from pmx20 import PMX20_REFERENCES
        ref = PMX20_REFERENCES['Gemini PMX20']
        c = json.loads((ROOT / 'docs/coordination/controller-catalogue.json').read_text())
        self.assertEqual(next(d for d in c['definitions'] if d['id'] == 'reviewed:pmx20-common-core')['source'], ref)
        for f in ref['files']:
            p = ROOT / f['cachePath']
            if p.exists(): self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(), f['sha256'])
