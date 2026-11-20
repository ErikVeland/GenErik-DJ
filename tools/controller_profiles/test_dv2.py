"""DV2 USB uses its own manufacturer Bn/9n contract without a channel guess."""
import hashlib
import json
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]


class DV2Tests(unittest.TestCase):
    def test_manual_wildcard_mixer_and_two_pfl_notes(self):
        profiles=json.loads((ROOT/'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']
        p=next((p for p in profiles if p['id']=='American Audio DV2'),None);self.assertIsNotNone(p)
        self.assertEqual((len(p['inputs']),p['autoSelect'],p['role']),(16,False,'accessory'))
        self.assertEqual((p['outputs'],p['startup'],p['shutdown']),([],[],[]));self.assertNotIn('audioOutput',p)
        self.assertNotIn('bankChanges',p);self.assertNotIn('inputModes',p)
        self.assertTrue(all(x['anyChannel'] and x['channel']==0 and x['encoding']=='absolute' and not x['inverted'] for x in p['inputs']))
        for deck,gain,high,mid,low,level in [('a',47,48,49,50,58),('b',51,52,53,54,59)]:
            own=[x for x in p['inputs'] if x.get('targetDeck')==deck]
            self.assertEqual({x['action'][:-1]:x['number'] for x in own if x['kind']=='control'},dict(gain=gain,high=high,mid=mid,low=low,level=level))
            cue=next(x for x in own if x['kind']=='note');self.assertEqual((cue['action'],cue['number']),('cue'+deck.upper(),9 if deck=='a' else 10))
        self.assertEqual({x['action']:x['number'] for x in p['inputs'] if 'targetDeck' not in x},dict(master=55,cueMix=56,monitor=57,crossfader=60))
        self.assertFalse(any(x['action'].startswith(('play','cuePreview','jog','tempo','hotcue','filter')) for x in p['inputs']))

    def test_own_primary_source_pins(self):
        from dv2 import DV2_REFERENCES
        for f in DV2_REFERENCES['American Audio DV2']['files']:
            p=ROOT/f['cachePath']
            if p.exists():self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(),f['sha256'])
