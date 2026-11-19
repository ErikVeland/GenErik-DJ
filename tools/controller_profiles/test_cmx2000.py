"""CMX-2000 manual native banks retain separate manufacturer wire evidence."""
import hashlib
import json
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]


class CMX2000Tests(unittest.TestCase):
    def test_manual_native_banks_retain_asymmetric_cue_evidence(self):
        profiles=json.loads((ROOT/'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']
        p=next((p for p in profiles if p['id']=='OMNITRONIC CMX-2000'),None)
        self.assertIsNotNone(p)
        self.assertEqual((p['autoSelect'],len(p['inputs']),p['outputs']),(False,119,[]))
        self.assertEqual((p['startup'],p['shutdown']),([],[]));self.assertNotIn('audioOutput',p)
        self.assertEqual([(r['channel'],r['number'],r['releaseNumber'],r['deckBank']) for r in p['bankChanges']],[(0,25,75,0),(1,25,75,1)])
        for bank,deck in enumerate('ab'):
            own=[x for x in p['inputs'] if x.get('deckBank')==bank]
            self.assertTrue(all(x.get('targetDeck')==deck for x in own))
            cues=[x for x in own if x['action'].startswith('hotcue') and not x.get('releaseOnly')]
            expected=[(1,43),(2,48),(3,49),(4,50),(5,44),(6,45),(7,46),(8,47)] if bank==0 else [(1,43),(2,48),(3,46),(4,47),(5,44),(6,45)]
            self.assertEqual([(int(x['action'][6:-1]),x['number']) for x in cues],expected)
            self.assertTrue(all(any(y['action']==x['action'] and y['number']==x['number']+50 and y.get('releaseOnly') for y in own) for x in cues))
            load=next(x for x in own if x['action'].startswith('load') and not x.get('releaseOnly'))
            self.assertEqual((load['channel'],load['number']),(0,1+bank*2))
            self.assertEqual({x['number'] for x in own if x['kind']=='control'},{14,15,16,17,18,19,54,55,56,57,58,59,25})
        self.assertFalse(any(x['kind']=='pitch' or x['action'].startswith(('jog','tempo')) for x in p['inputs']))
        self.assertFalse(any(x['channel']==1 and x['kind']=='note' and x['number'] in [49,50,99,100] for x in p['inputs']))

    def test_own_primary_source_pins(self):
        from cmx2000 import CMX_REFERENCES
        for f in CMX_REFERENCES['OMNITRONIC CMX-2000']['files']:
            p=ROOT/f['cachePath']
            if p.exists():self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(),f['sha256'])
