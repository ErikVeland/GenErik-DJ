"""KUT uses its own Bn mixer chart without assuming a fixed MIDI channel."""
import hashlib
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class ReloopKUTTests(unittest.TestCase):
    def test_manual_continuous_mixer_contract(self):
        profiles = json.loads((ROOT / 'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']
        p = next(p for p in profiles if p['id'] == 'Reloop KUT')
        self.assertEqual((len(p['inputs']), p['autoSelect'], p['role']), (14, False, 'accessory'))
        self.assertEqual((p['outputs'], p['startup'], p['shutdown']), ([], [], []))
        self.assertNotIn('audioOutput', p)
        self.assertTrue(all(r.get('anyChannel') and r['channel'] == 0 and r['kind'] == 'control' and r['encoding'] == 'absolute' for r in p['inputs']))
        self.assertEqual({r['number'] for r in p['inputs']}, {1, 2, 3, 4, 5, 7, 8, 9, 10, 11, 13, 16, 18, 19})
        self.assertEqual({r['action']:r['number'] for r in p['inputs'] if r.get('targetDeck') == 'a'}, {'gainA':1,'highA':2,'midA':3,'lowA':4,'levelA':5})
        self.assertEqual({r['action']:r['number'] for r in p['inputs'] if r.get('targetDeck') == 'b'}, {'gainB':7,'highB':8,'midB':9,'lowB':10,'levelB':11})

    def test_own_source_pins_and_definition(self):
        from reloop_kut import KUT_REFERENCES
        ref = KUT_REFERENCES['Reloop KUT']
        c = json.loads((ROOT / 'docs/coordination/controller-catalogue.json').read_text())
        self.assertEqual(next(d for d in c['definitions'] if d['id'] == 'reviewed:reloop-kut-continuous')['source'], ref)
        for f in ref['files']:
            p = ROOT / f['cachePath']
            if p.exists(): self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(), f['sha256'])
