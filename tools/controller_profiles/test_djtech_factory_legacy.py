"""Separate manufacturer DJ-Tech definitions qualify explicit-channel cores."""
import hashlib
import json
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]


class DJTechLegacyFactoryTests(unittest.TestCase):
    def test_both_manual_profiles_keep_unqualified_globals_and_motion_inactive(self):
        profiles=json.loads((ROOT/'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']
        for name,count in [('DJ-Tech DRAGON TWO',220),('DJ-Tech 4MIX',164)]:
            p=next((p for p in profiles if p['id']==name),None);self.assertIsNotNone(p,name)
            self.assertEqual((p['autoSelect'],len(p['inputs']),p['startup'],p['shutdown']),(False,count,[],[]))
            self.assertEqual(len(p['outputs']),32 if name=='DJ-Tech DRAGON TWO' else 28)
            self.assertNotIn('audioOutput',p);self.assertFalse(p.get('bankChanges') or p.get('inputModes'))
            self.assertTrue(all(1<=r['channel']<=4 and not r.get('anyChannel') for r in p['inputs']))
            self.assertFalse(any(r['action'].startswith(('tempo','jog','keylock')) or r['action'] in ['crossfader','master','monitor','cueMix','browse'] for r in p['inputs']))
            self.assertEqual(sum(r['action']=='shift' for r in p['inputs']),4)
            if name=='DJ-Tech 4MIX':self.assertTrue(all(r['kind']=='note' for r in p['inputs']))

    def test_every_active_wire_and_explicit_shift_release_is_in_its_own_definition(self):
        from djtech_factory_legacy import DJTECH_LEGACY_REFERENCES
        profiles=json.loads((ROOT/'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']
        for name,ref in DJTECH_LEGACY_REFERENCES.items():
            p=next(p for p in profiles if p['id']==name);source=ROOT/ref['definitionCache']
            if not source.exists():continue
            root=ET.parse(source).getroot();wires=set()
            for r in root:
                if r.tag not in ['button','slider'] or r.get('channel') is None:continue
                wires.add(('note' if r.tag=='button' else 'control',int(r.get('channel')),int(r.get('note') if r.tag=='button' else r.get('cc'),16)))
            for r in p['inputs']:self.assertIn((r['kind'],r['channel'],r['number']),wires)
            self.assertEqual({int(r.get('channel')) for r in root.findall('button') if r.get('name')=='SHIFT'},{1,2,3,4})

    def test_archives_and_each_factory_member_are_pinned_separately(self):
        from djtech_factory_legacy import DJTECH_LEGACY_REFERENCES
        refs=list(DJTECH_LEGACY_REFERENCES.values());self.assertNotEqual(refs[0]['sha256'],refs[1]['sha256'])
        for ref in refs:
            for f in ref['files']:
                p=ROOT/f['cachePath']
                if p.exists():self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(),f['sha256'])
