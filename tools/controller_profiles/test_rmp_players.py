"""Two RMP players use separate manufacturer facts without sibling wire inference."""
import hashlib
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class RMPPlayerTests(unittest.TestCase):
    def test_separate_automatic_input_only_contracts(self):
        profiles = json.loads((ROOT / 'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']
        for name, play, loop_in, lock in [('Reloop RMP-3', 1, 22, 20), ('Reloop RMP-2.5a', 6, 12, 19)]:
            p = next(p for p in profiles if p['id'] == name)
            self.assertEqual((len(p['inputs']), p['autoSelect'], p['role']), (38, True, 'player'))
            self.assertEqual((p['outputs'], p['startup'], p['shutdown']), ([], [], []))
            self.assertNotIn('audioOutput', p)
            self.assertTrue(all(r['kind'] == 'note' and r['channel'] == 0 and r['anyChannel'] and r['encoding'] == 'absolute' for r in p['inputs']))
            main = {r['action']:r['number'] for r in p['inputs'] if not r.get('releaseOnly')}
            self.assertEqual((main['playA'], main['loopInA'], main['keylockA'], main['cuePreviewA']), (play, loop_in, lock, 7))
            self.assertFalse(any(r['action'] in ['shift', 'jogA', 'jogTouchA', 'tempoA', 'loadA'] for r in p['inputs']))
            self.assertEqual(sum(r['action'].startswith('hotcue') and not r.get('releaseOnly') for r in p['inputs']), 8)
            self.assertEqual({r['number'] for r in p['inputs'] if r.get('pulse')}, {50,51,113,114,13,19} if name.endswith('-3') else {50,51,113,114,4,5})

    def test_own_source_pins_and_definitions(self):
        from rmp_players import RMP_REFERENCES
        c = json.loads((ROOT / 'docs/coordination/controller-catalogue.json').read_text())
        for index, (name, ref) in enumerate(RMP_REFERENCES.items()):
            definition = 'reviewed:rmp3-preset-buttons' if index == 0 else 'reviewed:rmp25-preset-buttons'
            self.assertEqual(next(d for d in c['definitions'] if d['id'] == definition)['source'], ref)
            for f in ref['files']:
                p = ROOT / f['cachePath']
                if p.exists(): self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(), f['sha256'])
