"""Own DJ-808 primary revision qualifies a bounded manual MIDI subset."""
import hashlib
import json
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]


class DJ808Tests(unittest.TestCase):
    def test_manual_core_keeps_driver_mode_and_feedback_unowned(self):
        rows=json.loads((ROOT/'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']
        p=next((p for p in rows if p['id']=='Roland DJ-808'),None);self.assertIsNotNone(p)
        self.assertEqual((p['autoSelect'],len(p['inputs']),p['outputs'],p['startup'],p['shutdown']),(False,113,[],[],[]))
        self.assertNotIn('audioOutput',p);self.assertNotIn('inputModes',p)
        self.assertEqual(sum(r['encoding']=='paired14Bit' for r in p['inputs']),20)
        self.assertFalse(any(r['action'].startswith(('tempo','jog','hotcue','load')) or r['action']=='crossfader' for r in p['inputs']))
        self.assertEqual(p['bankChanges'],[{'channel':i,'number':8,'anyPositive':True,'decks':list('ac' if i==0 else 'bd')} for i in range(2)])
        self.assertNotIn('DJ-505',p['aliases']);self.assertNotIn('DJ-707M',p['aliases'])

    def test_every_positive_command_and_pair_is_in_the_own_model_xml(self):
        rows=json.loads((ROOT/'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']
        p=next((p for p in rows if p['id']=='Roland DJ-808'),None);self.assertIsNotNone(p)
        source=ROOT/'TestBuilds/r469/upstream/dj808.midi.xml'
        if not source.exists():self.skipTest('Pinned source cache is optional')
        root=ET.parse(source);self.assertEqual(root.findtext('./info/name'),'Roland DJ-808')
        wires={(int(c.findtext('status'),16),int(c.findtext('midino'),16)):c.findtext('key') for c in root.findall('.//controls/control') if c.findtext('midino') is not None}
        for r in p['inputs']:
            if r.get('releaseOnly'):continue
            wire=((0x90 if r['kind']=='note' else 0xB0)+r['channel'],r['number']);self.assertIn(wire,wires)
            if r['encoding']=='paired14Bit':
                self.assertTrue(wires[wire].endswith('.inputMSB'))
                low=(wire[0],r['lowNumber']);self.assertIn(low,wires)
                self.assertEqual(wires[low],wires[wire][:-3]+'LSB')
                self.assertIn((r['number'],r['lowNumber']),[(22,52),(23,53),(24,54),(25,55),(28,58)])
        s=(source.parent/'dj808-scripts.js').read_text();self.assertIn('var DJ808 = {};',s);self.assertIn('keep-alive',s)

    def test_primary_pr_and_manufacturer_guide_are_hash_locked(self):
        from roland_dj808 import DJ808_REFERENCES
        ref=DJ808_REFERENCES['Roland DJ-808'];self.assertEqual(ref['upstreamRevision'],'e1f90cde7a2904ae4c9de48614d1df85d3f2e34a')
        for f in ref['files']:
            p=ROOT/f['cachePath']
            if p.exists():self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(),f['sha256'])
