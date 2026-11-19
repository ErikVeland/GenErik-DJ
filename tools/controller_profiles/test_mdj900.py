"""Own MDJ-900 XML facts do not establish sibling or complete-mode support."""
import hashlib
import json
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]


class MDJ900Tests(unittest.TestCase):
    def profile(self):
        p=next((p for p in json.loads((ROOT/'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles'] if p['id']=='Gemini MDJ-900'),None);self.assertIsNotNone(p);return p

    def test_new_inventory_model_has_independent_manual_twenty_three_input_core(self):
        p=self.profile()
        self.assertEqual((p['autoSelect'],p['role'],len(p['inputs'])),(False,'player',23))
        self.assertTrue(all(r['channel']==0 and not r.get('anyChannel') for r in p['inputs']))
        self.assertEqual((p['outputs'],p['startup'],p['shutdown']),([],[],[]));self.assertNotIn('audioOutput',p)
        self.assertIn('MDJ-1000',p['excludedAliases']);self.assertIn('MDJ-500',p['excludedAliases'])
        c=json.loads((ROOT/'docs/coordination/controller-catalogue.json').read_text());m=next(x for x in c['models'] if x['name']=='Gemini MDJ-900')
        self.assertEqual((m['isPhysicalModel'],m['implementation'],m['inputBindingCount']),(True,'partial-midi-profile',23))
        self.assertFalse(c['releaseGate']['manufacturerAuditComplete'])

    def test_exact_own_normal_roles_without_inferred_filter_motion_or_roll(self):
        p=self.profile()
        self.assertEqual({r['action']:r['number'] for r in p['inputs']},{'playA':2,'cuePreviewA':1,'loopInA':4,'loopOutA':5,'reloopA':6,'loopDownA':7,'loopUpA':8,'keylockA':19,'loadA':9,'syncA':52,'pitchBendDownA':18,'pitchBendUpA':17,'hotcue1A':38,'hotcue2A':39,'hotcue3A':40,'hotcue4A':41,'clearHotcue1A':42,'clearHotcue2A':43,'clearHotcue3A':44,'clearHotcue4A':45,'browsePrevious':11,'browseNext':12,'tempoA':1})
        self.assertTrue(all(not r.get('releaseOnly') for r in p['inputs']))
        self.assertTrue(next(r for r in p['inputs'] if r['action']=='tempoA')['inverted'])
        self.assertTrue(all(r.get('pulse') for r in p['inputs'] if r['action'].startswith('browse')))

    def test_hash_pinned_primary_owner_xml_qualifies_every_wire(self):
        p=self.profile()
        from mdj900 import MDJ900_REFERENCES
        ref=MDJ900_REFERENCES[p['id']]
        self.assertEqual(ref['upstreamRevision'],'cfa171fa3f7e758e212fc6edb2c711dba3a4a8eb')
        for f in ref['files']:
            path=ROOT/f['cachePath']
            if path.exists():self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(),f['sha256'])
        path=ROOT/'TestBuilds/r477/upstream/mdj900.midi.xml'
        if not path.exists():return
        controls=ET.parse(path).findall('.//controls/control')
        for r in p['inputs']:
            matches=[x for x in controls if int(x.findtext('status'),0)==(0x90 if r['kind']=='note' else 0xB0) and int(x.findtext('midino'),0)==r['number']]
            self.assertEqual(len(matches),1,r['action'])
