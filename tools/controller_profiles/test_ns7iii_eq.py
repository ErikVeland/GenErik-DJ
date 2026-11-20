"""NS7III imports only the owner's explicitly hardware-probed EQ addresses."""
import hashlib
import json
import re
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]


class NS7IIIEQTests(unittest.TestCase):
    def test_manual_coarse_eq_only_keeps_other_reports_inactive(self):
        rows=json.loads((ROOT/'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']
        p=next((p for p in rows if p['id']=='Numark NS7 III'),None);self.assertIsNotNone(p)
        self.assertEqual((p['autoSelect'],p['role'],len(p['inputs'])),(False,'accessory',12))
        self.assertEqual((p['outputs'],p['startup'],p['shutdown']),([],[],[]));self.assertNotIn('audioOutput',p)
        expected={}
        for deck,base in zip('abcd',[9,14,20,25]):
            for delta,action in enumerate(['low','mid','high']):expected[(deck,action+('A' if deck in 'ac' else 'B'))]=base+delta
        self.assertEqual({(r['targetDeck'],r['action']):r['number'] for r in p['inputs']},expected)
        self.assertTrue(all(r['kind']=='control' and r['channel']==0 and r['encoding']=='absolute' and not r.get('anyChannel') and not r.get('inverted') and 'lowNumber' not in r for r in p['inputs']))
        self.assertFalse(p.get('bankChanges'));self.assertNotIn('NS7II',p['aliases']);self.assertNotIn('NS7',p['aliases'])

    def test_pinned_source_distinguishes_probed_eq_from_unconfirmed_values(self):
        from ns7iii_eq import NS7III_EQ_REFERENCES
        ref=NS7III_EQ_REFERENCES['Numark NS7 III']
        for f in ref['files']:
            p=ROOT/f['cachePath']
            if p.exists():self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(),f['sha256'])
        p=ROOT/'TestBuilds/r464/upstream/ns7iii_map.h'
        if p.exists():
            s=p.read_text();self.assertIn('probed from hardware',s);self.assertIn('unconfirmed by capture',s)
            for deck,base in zip('abcd',[9,14,20,25]):
                for delta,action in enumerate(['low','mid','high']):
                    self.assertRegex(s,rf'eq_{action}_{deck}\s+B0\s+{base+delta}\\n')
