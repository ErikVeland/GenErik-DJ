"""Original APC mini facts remain separate from the MK2 RGB protocol."""
import hashlib
import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class APCMiniOriginalTests(unittest.TestCase):
    def test_own_grid_faders_shift_and_lamps(self):
        rows = json.loads((ROOT / 'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']
        p = next(p for p in rows if p['id'] == 'Akai APC MINI')
        self.assertEqual((len(p['inputs']), len(p['outputs']), p['autoSelect'], p['role']), (74, 52, True, 'accessory'))
        self.assertEqual(p['startup'], []); self.assertNotIn('audioOutput', p)
        self.assertEqual(p['shutdown'], [[144, n, 0] for n in range(64)])
        self.assertEqual({r['number'] for r in p['inputs'] if r['kind'] == 'note' and r['action'] != 'shift'}, set(range(64)))
        self.assertEqual({r['number'] for r in p['inputs'] if r['kind'] == 'control'}, set(range(48, 57)))
        self.assertTrue(all(r.get('shifted') is False for r in p['inputs'] if r['action'] != 'shift'))
        self.assertTrue(all(r['channel'] == 0 and r['onValue'] in [1, 3, 5] and r['offValue'] == 0 and r['offUsesNoteOn'] for r in p['outputs']))
        self.assertEqual(p['bankChanges'], [{'channel': 0, 'number': 98, 'anyPositive': True, 'decks': list('abcd'), 'releaseShiftChannels': []}])

    def test_all_grid_numbers_match_own_hardware_owner_table(self):
        p = ROOT / 'TestBuilds/r438/upstream/apc-mini-README.md'
        if not p.exists(): return
        text = p.read_text(); section = text.split('## Grid Buttons')[1].split('## Vertical Buttons')[0]
        grid = [[int(x, 16) for x in re.findall(r'`([0-9a-f]{2})`', line)] for line in section.splitlines() if '`' in line]
        self.assertEqual(grid, [list(range(8 * row, 8 * row + 8)) for row in range(7, -1, -1)])
        self.assertIn('Button press or release: always `7f`', text)
        self.assertIn('`08 80` button release', text)

    def test_own_source_pins_and_independent_definition(self):
        from apc_mini_original import APC_MINI_ORIGINAL_REFERENCES
        ref = APC_MINI_ORIGINAL_REFERENCES['Akai APC MINI']
        catalogue = json.loads((ROOT / 'docs/coordination/controller-catalogue.json').read_text())
        self.assertEqual(next(d for d in catalogue['definitions'] if d['id'] == 'reviewed:apc-mini-original-native')['source'], ref)
        for f in ref['files']:
            p = ROOT / f['cachePath']
            if p.exists(): self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(), f['sha256'])
