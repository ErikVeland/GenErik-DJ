"""Two Audiophony factory members retain independent identities and jog scales."""
import hashlib
import json
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]


class AudiophonyFactoryTests(unittest.TestCase):
    def test_independent_factories_and_manual_mixer_boundary(self):
        profiles=json.loads((ROOT/'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']
        for name,count,lamps,automatic,jog in [('Audiophony DJAZZ',211,36,True,150),('Audiophony DJAM',157,32,True,800),('Audiophony DJAM (CTRL MIDI mixer)',213,36,False,800)]:
            p=next((r for r in profiles if r['id']==name),None);self.assertIsNotNone(p,name)
            self.assertEqual((len(p['inputs']),len(p['outputs']),p['autoSelect']),(count,lamps,automatic))
            self.assertEqual((p['startup'],p['shutdown']),([],[]));self.assertNotIn('audioOutput',p)
            self.assertTrue(all(not r.get('anyChannel') for r in p['inputs']))
            for ch,deck in enumerate('abcd'):
                own=[r for r in p['inputs'] if r.get('targetDeck')==deck]
                for action,n in [('play',24),('cuePreview',23),('sync',18),('keylock',16),('loopIn',4),('loopOut',5),('reloop',6),('pitchBendDown',19),('pitchBendUp',20),('loop',1),('load',34+ch%2),('jogTouch',38)]:
                    a=action+('A' if ch%2==0 else 'B');x=next(r for r in own if r['action']==a and not r.get('releaseOnly'))
                    self.assertEqual((x['channel'],x['number']),(ch,n))
                    self.assertTrue(any(r['action']==a and r['number']==n+50 and r.get('releaseOnly') for r in own))
                wheel=next(r for r in own if r['action'].startswith('jog') and r['kind']=='control')
                self.assertEqual((wheel['number'],wheel['encoding'],wheel['argument'],wheel['shifted']),(2,'binaryOffset',jog,False))
                tempo=next(r for r in own if r['kind']=='pitch');self.assertTrue(tempo['inverted'])
            if name=='Audiophony DJAM':
                self.assertTrue(all(r.get('targetDeck') is not None or r['action']=='shift' for r in p['inputs']))
                self.assertFalse(any(r['action'].startswith(('gain','high','mid','low','level','filterKnob','cueA','cueB')) for r in p['inputs']))
            else:
                self.assertEqual({r['number'] for r in p['inputs'] if r['action']=='crossfader'},{16,46})
                self.assertEqual({r['number'] for r in p['inputs'] if r['action']=='master'},{12,42} if 'DJAM' in name else set())
            self.assertEqual(len(p['bankChanges']),8)
        c=json.loads((ROOT/'docs/coordination/controller-catalogue.json').read_text())
        self.assertFalse(any('CTRL MIDI' in m['name'] for m in c['models']))

    def test_separate_primary_facts_and_source_pins(self):
        from audiophony_factory import AUDIOPHONY_FACTORY_REFERENCES
        for ref in AUDIOPHONY_FACTORY_REFERENCES.values():
            for f in ref['files']:
                p=ROOT/f['cachePath']
                if p.exists():self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(),f['sha256'])
