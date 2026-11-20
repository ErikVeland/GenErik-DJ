"""CDMP-7000 own-model normal player facts stay separate from sibling claims."""
import hashlib
import json
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]


class CDMP7000Tests(unittest.TestCase):
    def profile(self):
        rows=json.loads((ROOT/'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']
        p=next((p for p in rows if p['id']=='Gemini CDMP-7000'),None)
        self.assertIsNotNone(p)
        return p

    def test_manual_raw_zero_player_keeps_thirteen_own_inputs(self):
        p=self.profile()
        self.assertEqual((p['role'],p['autoSelect'],len(p['inputs'])),('player',False,13))
        self.assertEqual((p['outputs'],p['startup'],p['shutdown']),([],[],[]))
        self.assertNotIn('audioOutput',p);self.assertNotIn('bankChanges',p)
        self.assertTrue(all(r['channel']==0 and not r.get('anyChannel') for r in p['inputs']))
        self.assertEqual({r['action']:r['number'] for r in p['inputs']},{'playA':2,'cuePreviewA':1,'pitchBendUpA':3,'pitchBendDownA':4,'loadA':15,'loopInA':16,'loopOutA':17,'reloopA':18,'browsePrevious':11,'browseNext':12,'tempoA':33,'jogA':32,'jogTouchA':24})
        self.assertFalse(any(r['action'].startswith(('hotcue','sync','keylock','reverse')) for r in p['inputs']))
        self.assertIn('CDJ-700',p['excludedAliases']);self.assertIn('CDMP-2700',p['excludedAliases'])

    def test_motion_and_navigation_keep_explicit_source_contracts(self):
        p=self.profile();by={r['action']:r for r in p['inputs']}
        self.assertEqual((by['jogA']['encoding'],by['jogA']['argument']),('binaryOffset',128))
        self.assertEqual((by['tempoA']['kind'],by['tempoA']['encoding'],by['tempoA']['inverted']),('control','absolute',True))
        self.assertTrue(all(by[a].get('pulse') for a in ['browsePrevious','browseNext']))
        path=ROOT/'TestBuilds/r475/upstream/cdmp7000.midi.xml'
        if path.exists():
            controls=ET.parse(path).findall('.//controls/control')
            wires={(int(x.findtext('status'),0)&0xF0,int(x.findtext('midino'),0)) for x in controls if x.findtext('midino')}
            for r in p['inputs']:self.assertIn((0x90 if r['kind']=='note' else 0xB0,r['number']),wires)

    def test_primary_owner_pins_are_not_reported_sibling_compatibility(self):
        from cdmp7000 import CDMP7000_REFERENCES
        ref=CDMP7000_REFERENCES['Gemini CDMP-7000']
        self.assertEqual(ref['upstreamRevision'],'3236e2380a1b24c662fc58777d266b21f9cc46ec')
        for f in ref['files']:
            p=ROOT/f['cachePath']
            if p.exists():self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(),f['sha256'])
