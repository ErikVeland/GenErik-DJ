"""Original Seventy-Two roles use its own primary owner's used TSI bindings."""
import hashlib
import json
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]


class Rane72OwnerTests(unittest.TestCase):
    def profile(self):
        rows=json.loads((ROOT/'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']
        p=next((p for p in rows if p['id']=='Rane SEVENTY-TWO'),None);self.assertIsNotNone(p)
        return p

    def test_manual_seven_input_core_does_not_inherit_mkii_or_audio_mixer(self):
        p=self.profile()
        self.assertEqual((p['autoSelect'],len(p['inputs']),p['outputs'],p['startup'],p['shutdown']),(False,7,[],[],[]))
        self.assertNotIn('audioOutput',p);self.assertNotIn('inputModes',p)
        self.assertEqual({r['action']:(r['channel'],r['number']) for r in p['inputs']},{'playA':(4,40),'playB':(5,40),'syncA':(4,41),'syncB':(5,41),'loadA':(15,2),'loadB':(15,3),'browse':(15,0)})
        self.assertTrue(all(not r.get('anyChannel') for r in p['inputs']))
        self.assertEqual(next(r for r in p['inputs'] if r['action']=='browse')['encoding'],'twosComplement')
        self.assertIn('MKII',p['excludedAliases']);self.assertNotIn('Seventy',p['aliases'])

    def test_used_primary_tsi_addresses_commands_and_targets(self):
        p=self.profile()
        from tsi_facts import inspect_tsi
        path=ROOT/'TestBuilds/r476/upstream/rane72-data/Rane 72 Complete Mapping.tsi'
        if not path.exists():return
        rows=inspect_tsi(path.read_bytes())[0]['mappings']
        for r in p['inputs']:
            a=r['action'];n=r['number'];ch=r['channel']+1
            signal=f'Ch{ch:02}.CC.{n:03}' if r['kind']=='control' else f'Ch{ch:02}.Note.'+['C','C#','D','D#','E','F','F#','G','G#','A','A#','B'][n%12]+str(n//12-1)
            cmd=3200 if a=='browse' else 100 if a.startswith('play') else 125 if a.startswith('sync') else 3076
            matches=[x for x in rows if x['direction']==0 and x['signal']==signal and x['commandID']==cmd and x['target']==(1 if r.get('targetDeck')=='b' else 0)]
            self.assertTrue(matches,(a,signal))
            self.assertTrue(all(x['inverted']==0 for x in matches))
            if a=='browse':self.assertTrue(all(x['encoderMode']==1 for x in matches))

    def test_author_download_pins_and_unconditional_subset(self):
        from rane72_owner import RANE72_OWNER_REFERENCES
        ref=RANE72_OWNER_REFERENCES['Rane SEVENTY-TWO']
        for f in ref['files']:
            p=ROOT/f['cachePath']
            if p.exists():self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(),f['sha256'])
        path=ROOT/'TestBuilds/r476/upstream/rane72-conditions.json'
        if path.exists():
            rows=json.loads(path.read_text())
            selected=[r for r in rows if r['direction']==0 and r['commandID'] in [100,125,3076,3200]]
            self.assertEqual(len(selected),8)
            self.assertTrue(all(r['conditions']==[[0,0],[0,0]] for r in selected))
