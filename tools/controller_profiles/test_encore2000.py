"""Encore 2000 uses its own normal/TAP chart with explicit channel preconditions."""
import hashlib
import json
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]


class Encore2000Tests(unittest.TestCase):
    def test_configured_manual_core_without_mix_channel_guess(self):
        r=json.loads((ROOT/'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']
        p=next((p for p in r if p['id']=='American Audio ENCORE 2000'),None)
        self.assertIsNotNone(p)
        self.assertEqual((p['autoSelect'],len(p['inputs']),len(p['outputs'])),(False,68,6))
        self.assertEqual((p['startup'],p['shutdown']),([],[]))
        self.assertNotIn('audioOutput',p)
        for ch,deck in enumerate('ab'):
            own=[x for x in p['inputs'] if x.get('targetDeck')==deck]
            suffix=deck.upper()
            for action,n in [('play',23),('cuePreview',19),('keylock',6),('loopIn',15),('loopOut',11),('reloop',12),('pitchBendDown',8),('pitchBendUp',16)]:
                normal=next(x for x in own if x['action']==action+suffix and not x.get('releaseOnly'))
                self.assertEqual((normal['channel'],normal['number']),(ch,n))
                self.assertTrue(any(x['action']==normal['action'] and x['number']==n+63 and x.get('releaseOnly') for x in own))
            self.assertEqual({x['number'] for x in own if x['kind']=='control'},{33,34,35,36,37,96,97,98,99,100})
        self.assertTrue(all(x['channel'] in [0,1] and not x.get('anyChannel') for x in p['inputs']))
        self.assertFalse(any(x['action'] in ['master','monitor','cueMix','crossfader','jogA','jogB','tempoA','tempoB','shift'] for x in p['inputs']))
        self.assertEqual(len(p['bankChanges']),2)
        self.assertTrue(all(x['number']==4 and x['releaseShiftChannels']==[] for x in p['bankChanges']))

    def test_own_manufacturer_source_pin(self):
        from encore2000 import ENCORE_REFERENCES
        for f in ENCORE_REFERENCES['American Audio ENCORE 2000']['files']:
            p=ROOT/f['cachePath']
            if p.exists():self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(),f['sha256'])
