"""Separate Rane tables retain hardware ownership and disputed wire boundaries."""
import hashlib
import json
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
NAMES=['Rane SIXTY TWO','Rane SIXTY FOUR','Rane TTM57 MKII']

class LegacyRaneTests(unittest.TestCase):
    def test_manual_cores_keep_separate_channels_outputs_and_calibration(self):
        by={p['id']:p for p in json.loads((ROOT/'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']}
        for name,count,outputs in zip(NAMES,[44,83,24],[14,39,0]):
            self.assertTrue(name in by,name);p=by[name]
            self.assertEqual((p['autoSelect'],len(p['inputs']),len(p['outputs'])),(False,count,outputs))
            self.assertEqual((p['startup'],p['shutdown']),([],[]));self.assertNotIn('audioOutput',p)
            self.assertFalse(any(r['action'].startswith(('jog','tempo','cuePreview')) for r in p['inputs']))
            self.assertTrue(all(r['kind']=='note' and r['onValue']==64 and r['offValue']==0 for r in p['outputs']))
        for name in NAMES[:2]:self.assertTrue(all(r['channel']==0 for r in by[name]['inputs']))
        p=by[NAMES[1]];self.assertFalse(any(r['kind']=='note' and r['number']==16 for r in p['inputs']+p['outputs']))
        self.assertEqual({r['targetDeck'] for r in p['inputs'] if r['action'].startswith('hotcue')},set('abcd'))
        p=by[NAMES[2]];self.assertFalse(any(r['action'].startswith('hotcue') for r in p['inputs']))

    def test_each_own_primary_document_is_pinned(self):
        from legacy_rane import LEGACY_RANE_REFERENCES
        for ref in LEGACY_RANE_REFERENCES.values():
            p=ROOT/'TestBuilds/r419/upstream'/ref['cacheName']
            if p.exists():self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(),ref['sha256'])
