"""LPD8 MK2 uses only the separately published Program1 input footprint."""
import hashlib
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class LPD8MK2Tests(unittest.TestCase):
    def test_manual_published_program_contract(self):
        records = json.loads((ROOT / 'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']
        p = next(p for p in records if p['id'] == 'Akai LPD8 MK2')
        self.assertEqual((len(p['inputs']), p['autoSelect'], p['role']), (16, False, 'accessory'))
        self.assertEqual((p['outputs'], p['startup'], p['shutdown']), ([], [], []))
        self.assertNotIn('audioOutput', p)
        self.assertTrue(all(r['channel'] == 0 and r['encoding'] == 'absolute' for r in p['inputs']))
        self.assertEqual({(r['kind'], r['number']) for r in p['inputs']}, {(kind, n) for kind in ['note', 'control'] for n in range(36, 44)})
        self.assertEqual([(r['number'], r['targetDeck'], r['action']) for r in p['inputs'] if r['kind'] == 'note'], [(n, deck, f'hotcue{slot + 1}{deck.upper()}') for deck, base in [('a', 36), ('b', 40)] for slot, n in enumerate(range(base, base + 4))])
        self.assertNotIn('LPD8', p['aliases'])

    def test_own_published_reference_pins(self):
        from lpd8_mk2 import LPD8_MK2_REFERENCES
        ref = LPD8_MK2_REFERENCES['Akai LPD8 MK2']
        catalogue = json.loads((ROOT / 'docs/coordination/controller-catalogue.json').read_text())
        self.assertEqual(next(d for d in catalogue['definitions'] if d['id'] == 'reviewed:lpd8-mk2-vdj-program1')['source'], ref)
        for f in ref['files']:
            p = ROOT / f['cachePath']
            if p.exists(): self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(), f['sha256'])
