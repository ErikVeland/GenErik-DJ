"""Independent player tables keep assignment, channel and protocol boundaries."""
import hashlib
import json
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
NAMES=['Denon DJ SC2900','Denon DJ S3900','Denon DJ S3700','Denon DJ S1200']

class DenonLegacyPlayerTests(unittest.TestCase):
    def test_independent_automatic_players_keep_only_qualified_normal_midi_inputs(self):
        by={p['id']:p for p in json.loads((ROOT/'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']}
        for name,count in zip(NAMES,[21,21,16,10]):
            self.assertTrue(name in by,name);p=by[name]
            self.assertEqual((p['autoSelect'],p['role'],len(p['inputs'])),(True,'player',count))
            self.assertEqual((p['outputs'],p['startup'],p['shutdown']),([],[],[]));self.assertNotIn('audioOutput',p)
            self.assertTrue(all(r['channel']==0 and r.get('anyChannel') for r in p['inputs']))
            self.assertTrue(all(r['decks']==['a'] and r['channel']==0 and r['anyChannel'] and r['onValue']==64 for r in p['bankChanges']))
            self.assertFalse(any(r['action'].startswith(('jog','tempo')) for r in p['inputs']))
            self.assertEqual({r['encoding'] for r in p['inputs'] if r['action']=='browse'},{'zeroForward'})

    def test_each_own_primary_document_is_pinned(self):
        from denon_legacy_players import DENON_PLAYER_REFERENCES
        for ref in DENON_PLAYER_REFERENCES.values():
            p=ROOT/'TestBuilds/r417/upstream'/ref['cacheName']
            if p.exists():self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(),ref['sha256'])
