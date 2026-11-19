"""Independent public factory subsets retain mode, identity and wire boundaries."""
import hashlib
import json
import unittest
import xml.etree.ElementTree as E
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
NAMES=['Akai Pro AMX','ION ICUE','Reloop DIGITAL JOCKEY']

class ProMixerRemainingTests(unittest.TestCase):
    def test_bounded_manual_subsets_exclude_unqualified_writes_and_calibration(self):
        by={p['id']:p for p in json.loads((ROOT/'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']}
        for name,count in zip(NAMES,[32,30,118]):
            self.assertTrue(name in by,name);p=by[name]
            self.assertFalse(p['autoSelect']);self.assertEqual(len(p['inputs']),count)
            self.assertEqual((p['outputs'],p['startup'],p['shutdown']),([],[],[]));self.assertNotIn('audioOutput',p)
            self.assertTrue(all(r['channel']==0 for r in p['inputs']))
            self.assertFalse(any(r['action'].startswith(('jog','tempo','browse')) for r in p['inputs']))
        self.assertFalse(any(r['action']=='crossfader' for r in by[NAMES[1]]['inputs']))
        self.assertEqual(sum(r.get('releaseOnly',False) for r in by[NAMES[2]]['inputs']),48)

    def test_every_wire_exists_in_its_own_pinned_document(self):
        from promixer_remaining import REMAINING_PROMIXER_REFERENCES,remaining_promixer_profiles
        by={p['id']:p for p in remaining_promixer_profiles()}
        for name,ref in REMAINING_PROMIXER_REFERENCES.items():
            p=ROOT/'TestBuilds/r388/upstream/documents'/ref['member']
            if not p.exists():continue
            self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(),ref['memberSHA256'])
            wires=set()
            for row in E.fromstring(p.read_bytes()):
                d={c.tag:(c.text or '').strip() for c in row}
                if d.get('control_group')!='INPUT':continue
                status,number=int(d['midichan']),int(d['control_midino'])
                if status>>4 in [9,11] and 0<=number<128:wires.add(('note' if status>>4==9 else 'control',status&15,number))
            for r in by[name]['inputs']:self.assertIn((r['kind'],r['channel'],r['number']),wires)
