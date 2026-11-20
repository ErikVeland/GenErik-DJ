"""SmartPAD Clip wires are independently qualified and exclude unresolved held contacts."""
import hashlib
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class SmartPADTests(unittest.TestCase):
    def test_independent_default_clip_contract(self):
        rows = json.loads((ROOT / 'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']
        p = next(p for p in rows if p['id'] == 'MIDIPLUS SMARTPAD')
        self.assertEqual((len(p['inputs']), p['autoSelect'], p['role']), (60, True, 'accessory'))
        self.assertEqual((p['outputs'], p['startup'], p['shutdown']), ([], [], []))
        self.assertNotIn('audioOutput', p)
        self.assertTrue(all(r['kind'] == 'note' and r['channel'] == 0 and r['encoding'] == 'absolute' for r in p['inputs']))
        self.assertFalse(any(r['action'].startswith(('cuePreview', 'jog', 'pitchBend')) for r in p['inputs']))
        grid = {16 * row + col for row in range(8) for col in range(8)}
        self.assertEqual({r['number'] for r in p['inputs']}, grid - {49, 53, 113, 117})
        for deck in 'abcd':
            self.assertEqual(sum(r['action'].startswith('hotcue') and r['targetDeck'] == deck for r in p['inputs']), 8)

    def test_source_pins_and_own_factory_bounds(self):
        from smartpad import SMARTPAD_REFERENCES
        ref = SMARTPAD_REFERENCES['MIDIPLUS SMARTPAD']
        c = json.loads((ROOT / 'docs/coordination/controller-catalogue.json').read_text())
        self.assertEqual(next(d for d in c['definitions'] if d['id'] == 'reviewed:smartpad-clip-grid')['source'], ref)
        for f in ref['files']:
            p = ROOT / f['cachePath']
            if p.exists(): self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(), f['sha256'])
        path = ROOT / 'TestBuilds/r443/upstream/smartpad-owner-notes.txt'
        if path.exists():
            text = path.read_text()
            self.assertIn('0   1   2   3   4   5   6   7', text)
            self.assertIn('16  17  18  19  20  21  22  23', text)
            self.assertIn('112                         119', text)
