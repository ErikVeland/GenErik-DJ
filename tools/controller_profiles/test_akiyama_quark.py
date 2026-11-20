"""Original QUARK facts do not inherit QUARK SC behaviour."""
import hashlib
import json
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]


class QuarkTests(unittest.TestCase):
    def test_independent_automatic_core(self):
        rows=json.loads((ROOT/'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']
        p=next((p for p in rows if p['id']=='Akiyama QUARC'),None)
        self.assertIsNotNone(p)
        self.assertEqual((p['autoSelect'],len(p['inputs']),len(p['outputs'])),(True,164,44))
        self.assertEqual((p['startup'],p['shutdown']),([],[]))
        self.assertNotIn('audioOutput',p)
        self.assertIn('Akiyama QUARK',p['aliases'])
        self.assertIn('QUARK SC',p['excludedAliases'])
        for ch,deck in enumerate('abcd'):
            own=[r for r in p['inputs'] if r.get('targetDeck')==deck]
            self.assertEqual(len(own),40)
            suffix='A' if deck in 'ac' else 'B'
            self.assertEqual(next(r['number'] for r in own if r['action']=='cuePreview'+suffix and not r.get('releaseOnly')),53)
            self.assertEqual({r['number'] for r in own if r['action'].startswith('hotcue') and not r.get('releaseOnly')},{23,26,29,32,35,38})
            self.assertEqual({r['number'] for r in own if r['kind']=='control' and r['encoding']=='absolute'},{9,10,11,12,59})
            self.assertTrue(all(r['channel']==ch for r in own))
        self.assertTrue(all(r['onValue']==127 and r['offValue']==0 for r in p['outputs']))

    def test_public_table_excerpt_pin(self):
        from akiyama_quark import QUARK_REFERENCES
        ref=QUARK_REFERENCES['Akiyama QUARC']
        for f in ref['files']:
            p=ROOT/f['cachePath']
            if p.exists(): self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(),f['sha256'])
        self.assertIn('excerpt',ref['review'])
