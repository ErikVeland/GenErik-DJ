"""DJinn factory channels and mode ownership come from the own manufacturer manual."""
import hashlib
import json
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]


class DJinnTests(unittest.TestCase):
    def test_common_players_and_separate_manual_mode3_mixer(self):
        profiles=json.loads((ROOT/'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']
        for name,count,automatic in [('Audiophony DJINN',64,True),('Audiophony DJINN (MIDI mode 3)',90,False)]:
            p=next((r for r in profiles if r['id']==name),None);self.assertIsNotNone(p,name)
            self.assertEqual((len(p['inputs']),len(p['outputs']),p['autoSelect']),(count,14,automatic))
            self.assertEqual((p['startup'],p['shutdown']),([],[]));self.assertNotIn('audioOutput',p)
            for ch,deck in [(0,'a'),(2,'b')]:
                own=[r for r in p['inputs'] if r.get('targetDeck')==deck]
                for action,n in [('play',32),('cuePreview',31),('keylock',29),('loopIn',2),('loopOutOrExit',3),('reloop',4),('pitchBendDown',34),('pitchBendUp',35),('load',1)]:
                    a=action+deck.upper();x=next(r for r in own if r['action']==a and not r.get('releaseOnly'))
                    self.assertEqual((x['channel'],x['number']),(ch,n))
                    self.assertTrue(any(r['action']==a and r['number']==n+63 and r.get('releaseOnly') for r in own))
                self.assertEqual([r['number'] for r in own if r['action'].startswith('hotcue') and not r.get('releaseOnly')],[8,9,10,11])
                self.assertEqual({r['number'] for r in p['inputs'] if r['channel']==ch and r['action'] in ['browse','browseGroups']},{22 if ch==0 else 38,23 if ch==0 else 39,85 if ch==0 else 101,86 if ch==0 else 102})
            self.assertFalse(any(r['action'].startswith(('jog','tempo','sync','filter','cueMix','cueA','cueB')) for r in p['inputs']))
            self.assertTrue(all(not r.get('anyChannel') for r in p['inputs']))
            self.assertEqual([r['channel'] for r in p['bankChanges']],[0,2])
            if automatic:self.assertFalse(any(r['channel']==1 or r['action'].startswith(('gain','high','mid','low','level','master','monitor','crossfader')) for r in p['inputs']))
            else:
                self.assertEqual({r['number'] for r in p['inputs'] if r['channel']==1},{48,49,51,111,112,114})
                self.assertEqual({r['number'] for r in p['inputs'] if r['action'] in ['gainA','highA','midA','lowA','levelA']},{16,17,18,19,20,79,80,81,82,83})
                self.assertEqual({r['number'] for r in p['inputs'] if r['action'] in ['gainB','highB','midB','lowB','levelB']},{32,33,34,35,36,95,96,97,98,99})

    def test_own_primary_source_pin(self):
        from djinn import DJINN_REFERENCES
        for ref in DJINN_REFERENCES.values():
            for f in ref['files']:
                p=ROOT/f['cachePath']
                if p.exists():self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(),f['sha256'])
