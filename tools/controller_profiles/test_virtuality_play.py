"""Original PLAY uses its own narrow manual MIDI note contract."""
import hashlib
import json
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]


class VirtualityPlayTests(unittest.TestCase):
    def test_original_manual_core_has_no_inferred_bank_or_motion(self):
        rows=json.loads((ROOT/'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']
        p=next((p for p in rows if p['id']=='Audiophony PLAY'),None);self.assertIsNotNone(p)
        self.assertEqual((p['role'],p['autoSelect']),('player',False))
        self.assertEqual({r['action']:r['number'] for r in p['inputs']},{'playA':53,'cuePreviewA':52,'keylockA':29,'loopInA':38,'loopOutOrExitA':37,'reloopA':36,'pitchBendDownA':33,'pitchBendUpA':32})
        self.assertTrue(all(r['kind']=='note' and r.get('anyChannel') and r['channel']==0 and r['targetDeck']=='a' for r in p['inputs']))
        self.assertEqual((p['startup'],p['shutdown'],p['outputs']),([],[],[]));self.assertNotIn('audioOutput',p)
        self.assertEqual({r['number'] for r in p['bankChanges']},{47,56})
        self.assertTrue(all(r['decks']==['a'] and r.get('anyChannel') for r in p['bankChanges']))
        self.assertNotIn('PLAY',p['aliases']);self.assertNotIn('CDMP700',p['aliases'])

    def test_manufacturer_manual_pin(self):
        from virtuality_play import VIRTUALITY_PLAY_REFERENCES
        ref=VIRTUALITY_PLAY_REFERENCES['Audiophony PLAY'];p=ROOT/ref['files'][0]['cachePath']
        if p.exists():self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(),ref['sha256'])
