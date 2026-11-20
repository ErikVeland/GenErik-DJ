"""PMX-10 keeps independent manufacturer facts and unresolved encodings separate."""
import hashlib
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class PMX10Tests(unittest.TestCase):
    def test_independent_manual_two_deck_contract(self):
        profiles = json.loads((ROOT / 'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']
        p = next(p for p in profiles if p['id'] == 'Gemini PMX10')
        self.assertEqual((len(p['inputs']), len(p['outputs']), p['autoSelect'], p['role']), (40, 19, False, 'accessory'))
        self.assertEqual((p['startup'], p['shutdown']), ([], [])); self.assertNotIn('audioOutput', p)
        self.assertEqual(len(p['bankChanges']), 4)
        self.assertEqual({r['targetDeck'] for r in p['inputs'] if 'targetDeck' in r}, {'a', 'b'})
        self.assertTrue(all(r['encoding'] == 'absolute' for r in p['inputs']))
        self.assertFalse(any(r['kind'] == 'control' and r['number'] in [36, 66] for r in p['inputs']))
        self.assertFalse(any(r['action'].startswith(('play', 'cuePreview', 'sync', 'jog', 'tempo', 'fx')) for r in p['inputs']))
        self.assertTrue(all(r['kind'] == 'note' and r['channel'] < 2 and r['onValue'] == 1 and r['offValue'] == 0 and r['offUsesNoteOn'] for r in p['outputs']))
        self.assertFalse(any(r['action'] == 'cueA' for r in p['outputs']))

    def test_own_source_pins_and_definition(self):
        from pmx10 import PMX10_REFERENCES
        ref = PMX10_REFERENCES['Gemini PMX10']
        c = json.loads((ROOT / 'docs/coordination/controller-catalogue.json').read_text())
        self.assertEqual(next(d for d in c['definitions'] if d['id'] == 'reviewed:pmx10-manufacturer-core')['source'], ref)
        for f in ref['files']:
            p = ROOT / f['cachePath']
            if p.exists(): self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(), f['sha256'])
