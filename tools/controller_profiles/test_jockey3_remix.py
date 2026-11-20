"""Independent Jockey 3 Remix transport and mixer facts."""
import hashlib
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class Jockey3RemixTests(unittest.TestCase):
    def test_own_manual_four_deck_core(self):
        rows = json.loads((ROOT / 'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']
        p = next((p for p in rows if p['id'] == 'Reloop Jockey 3 Remix'), None)
        self.assertIsNotNone(p)
        self.assertEqual((p['autoSelect'], p['role'], len(p['inputs']), len(p['outputs'])), (False, 'accessory', 144, 32))
        self.assertEqual((p['startup'], p['shutdown']), ([], []))
        self.assertNotIn('audioOutput', p)
        for ch, deck in enumerate('abcd'):
            own = [r for r in p['inputs'] if r.get('targetDeck') == deck]
            normal = {r['action']: r['number'] for r in own if not r.get('releaseOnly')}
            suffix = 'A' if deck in 'ac' else 'B'
            for action, n in [('play',26), ('cuePreview',25), ('sync',23), ('cue',28), ('load',27), ('keylock',87), ('pitchBendDown',41), ('pitchBendUp',42)]:
                self.assertEqual(normal[action + suffix], n)
            self.assertTrue(all(r['channel'] == ch for r in own))
            self.assertEqual({r['number'] for r in own if r.get('releaseOnly')}, {86,88,89,90,91,104,105,24,74,75,76,77,106,107})
        self.assertFalse(any(r['kind'] == 'pitch' or r['action'] in ['jogA','jogB','shift','master','monitor'] for r in p['inputs']))
        self.assertTrue(all(r['onValue'] == 127 and r['offValue'] == 0 for r in p['outputs']))

    def test_primary_manual_pin(self):
        from jockey3_remix import JOCKEY_REMIX_REFERENCES
        ref = JOCKEY_REMIX_REFERENCES['Reloop Jockey 3 Remix']
        for f in ref['files']:
            p = ROOT / f['cachePath']
            if p.exists(): self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(), f['sha256'])
        c = json.loads((ROOT / 'docs/coordination/controller-catalogue.json').read_text())
        self.assertEqual(next(d for d in c['definitions'] if d['id'] == 'reviewed:jockey3-remix-core')['source'], ref)
