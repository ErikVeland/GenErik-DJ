"""MIDI Fighter 3D uses its own banked pad addresses and LED override values."""
import hashlib
import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class MidiFighter3DTests(unittest.TestCase):
    def test_independent_manual_banked_contract(self):
        rows = json.loads((ROOT / 'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']
        p = next(p for p in rows if p['id'] == 'DJ TechTools MIDI Fighter 3D')
        self.assertEqual((len(p['inputs']), len(p['outputs']), p['autoSelect'], p['role']), (64, 52, False, 'accessory'))
        self.assertEqual((p['startup'], p['shutdown']), ([], [])); self.assertNotIn('audioOutput', p)
        self.assertEqual({(r['kind'], r['channel'], r['number']) for r in p['inputs']}, {('note', 2, n) for n in range(36, 100)})
        self.assertEqual(p['bankChanges'], [{'channel': 3, 'number': n, 'anyPositive': True, 'decks': list('abcd')} for n in range(4)])
        self.assertTrue(all(r['onValue'] in [76, 80, 84] and r['offValue'] == 67 and r['offUsesNoteOn'] for r in p['outputs']))
        self.assertFalse(any(r['channel'] == 3 for r in p['outputs']))

    def test_each_arcade_wire_matches_both_separate_manufacturer_tables(self):
        from midi_fighter_3d import midi_fighter_3d_profiles
        for mode in ['ableton', 'traktor']:
            p = ROOT / f'TestBuilds/r437/upstream/mf3d-{mode}.txt'
            if not p.exists(): continue
            facts = {(int(bank), int(button)): int(number) for bank, button, number in re.findall(r'Bank (\d) Button (\d+)\s+3,4,5(?:,6)?\s+Note & CC\*\s+(\d+)', p.read_text())}
            self.assertEqual(len(facts), 64)
            self.assertEqual(set(facts.values()), {r['number'] for r in midi_fighter_3d_profiles()[0]['inputs']})
            for bank in range(1, 5):
                for button in range(1, 17): self.assertEqual(facts[bank, button], 36 + 16 * (bank - 1) + 4 * (3 - (button - 1) // 4) + (button - 1) % 4)

    def test_own_source_pins_and_definition(self):
        from midi_fighter_3d import MF3D_REFERENCES
        ref = MF3D_REFERENCES['DJ TechTools MIDI Fighter 3D']
        catalogue = json.loads((ROOT / 'docs/coordination/controller-catalogue.json').read_text())
        self.assertEqual(next(d for d in catalogue['definitions'] if d['id'] == 'manufacturer:midi-fighter-3d-banked-native')['source'], ref)
        for f in ref['files']:
            p = ROOT / f['cachePath']
            if p.exists(): self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(), f['sha256'])
