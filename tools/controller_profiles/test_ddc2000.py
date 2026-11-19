"""DDC-2000 facts come from its own manufacturer manual and factory definition."""
import hashlib
import json
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]


class DDC2000Tests(unittest.TestCase):
    def test_factory_mode1_core_uses_own_channels_and_resolved_shifted_globals(self):
        rows=json.loads((ROOT/'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']
        p=next((p for p in rows if p['id']=='OMNITRONIC DDC-2000'),None)
        self.assertIsNotNone(p)
        self.assertEqual((p['autoSelect'],len(p['inputs']),len(p['outputs'])),(True,211,36))
        self.assertEqual((p['startup'],p['shutdown']),([],[]))
        self.assertNotIn('audioOutput',p)
        for ch,deck in enumerate('abcd'):
            own=[x for x in p['inputs'] if x.get('targetDeck')==deck]
            for action,n in [('play',24),('cuePreview',23),('sync',18),('keylock',16),('cue',28),('load',34+ch%2),('loopIn',4),('loopOut',5),('reloop',6),('pitchBendDown',19),('pitchBendUp',20),('loop',1),('jogTouch',38)]:
                a=action+('A' if ch%2==0 else 'B')
                normal=next(x for x in own if x['action']==a and not x.get('releaseOnly'))
                self.assertEqual((normal['channel'],normal['number']),(ch,n))
                self.assertTrue(any(x['action']==a and x['number']==n+50 and x.get('releaseOnly') for x in own))
            jog=next(x for x in own if x['action'].startswith('jog') and x['kind']=='control')
            self.assertEqual((jog['number'],jog['encoding'],jog['argument'],jog['shifted']),(2,'binaryOffset',150,False))
            tempo=next(x for x in own if x['action'].startswith('tempo'))
            self.assertEqual((tempo['kind'],tempo['inverted']),('pitch',True))
            jumps=[x for x in own if x['action'].startswith('fixedJump') and not x.get('releaseOnly')]
            self.assertEqual([(x['number'],x['argument']) for x in jumps],[(58,-4),(59,4)])
            self.assertTrue(all(x['number'] not in [22,72,7,57] for x in own if x['kind']=='note'))
        for action,numbers in [('crossfader',[16,46]),('cueMix',[19,49]),('monitor',[20,50])]:
            self.assertEqual([x['number'] for x in p['inputs'] if x['action']==action],numbers)
        self.assertEqual([(x['action'],x['number']) for x in p['inputs'] if x['action'] in ['browse','browseGroups']],[('browse',14),('browseGroups',44)])
        self.assertEqual(len(p['bankChanges']),8)
        self.assertTrue(all(x['number'] in [17,67] for x in p['bankChanges']))

    def test_own_primary_source_pins(self):
        from ddc2000 import DDC_REFERENCES
        for f in DDC_REFERENCES['OMNITRONIC DDC-2000']['files']:
            p=ROOT/f['cachePath']
            if p.exists():self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(),f['sha256'])
