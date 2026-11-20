"""Radius player revisions retain independent pins and distinct TAP families."""
import hashlib
import json
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]


class RadiusLegacyTests(unittest.TestCase):
    def test_independent_manual_and_factory_contracts(self):
        rows=json.loads((ROOT/'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']
        for name,count,automatic,offset,cues in [('American Audio RADIUS 1000 (2009 factory mapping)',39,False,63,3),('American Audio RADIUS 1000',38,False,61,3),('American Audio RADIUS 3000',40,True,63,4)]:
            p=next((r for r in rows if r['id']==name),None);self.assertIsNotNone(p,name)
            self.assertEqual((len(p['inputs']),p['autoSelect'],p['role']),(count,automatic,'player'))
            self.assertEqual((p['outputs'],p['startup'],p['shutdown']),([],[],[]));self.assertNotIn('audioOutput',p)
            for action,n in [('playA',42),('cuePreviewA',48),('keylockA',6),('loopInA',11),('loopOutOrExitA',5),('reloopA',23),('pitchBendDownA',7),('pitchBendUpA',13),('loopDownA',14),('loopUpA',8)]:
                x=next(r for r in p['inputs'] if r['action']==action and not r.get('releaseOnly'));self.assertEqual(x['number'],n)
                self.assertTrue(any(r['action']==action and r['number']==n+offset and r.get('releaseOnly') for r in p['inputs']))
            self.assertEqual(sum(x['action'].startswith('hotcue') and not x.get('releaseOnly') for x in p['inputs']),cues)
            self.assertFalse(any(x['action'] in ['syncA','syncDisableA','master','crossfader'] for x in p['inputs']))
            legacy='2009' in name
            self.assertTrue(all(x.get('anyChannel') for x in p['inputs']) if not legacy else all(not x.get('anyChannel') and x['channel']==0 for x in p['inputs']))
            if legacy:
                jog=next(x for x in p['inputs'] if x['action']=='jogA')
                self.assertEqual((jog['number'],jog['encoding'],jog['argument'],jog['shifted']),(53,'binaryOffset',1024,False))
                self.assertEqual({x['number'] for x in p['inputs'] if x['action']=='jogTouchA'},{38,101})
            else:
                self.assertTrue(all(x['kind']=='note' for x in p['inputs']))
                self.assertEqual(sum(x.get('pulse',False) for x in p['inputs']),8)
        c=json.loads((ROOT/'docs/coordination/controller-catalogue.json').read_text())
        self.assertFalse(any('2009 factory' in m['name'] for m in c['models']))

    def test_separate_primary_source_pins(self):
        from radius_legacy_players import RADIUS_PLAYER_REFERENCES
        for ref in RADIUS_PLAYER_REFERENCES.values():
            for f in ref['files']:
                p=ROOT/f['cachePath']
                if p.exists():self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(),f['sha256'])
