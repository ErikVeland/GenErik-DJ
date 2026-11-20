"""GMX own primary MIDI facts remain separate from its HID interface and DRIVE."""
import hashlib
import json
import re
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]


class GMXTests(unittest.TestCase):
    def test_manual_core_uses_independent_midi_channels_and_no_hid_or_mode_guess(self):
        rows=json.loads((ROOT/'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']
        p=next((p for p in rows if p['id']=='Gemini GMX'),None);self.assertIsNotNone(p)
        self.assertEqual((p['autoSelect'],len(p['inputs']),p['startup'],p['shutdown']),(False,46,[],[]))
        self.assertEqual(len(p['outputs']),8)
        self.assertNotIn('audioOutput',p);self.assertFalse(p.get('bankChanges') or p.get('inputModes') or p.get('inputProtocol'))
        self.assertEqual({r['channel'] for r in p['inputs']},{0,1,3})
        self.assertEqual(sum(r['inverted'] for r in p['inputs']),6)
        self.assertFalse(any(r['action'].startswith(('hotcue','jog','sync')) for r in p['inputs']))
        self.assertNotIn('GMX DRIVE',p['aliases']);self.assertEqual(sum(r['action']=='shift' for r in p['inputs']),2)
        self.assertEqual(sum(r.get('shifted') is True for r in p['inputs']),4)

    def test_positive_midi_wires_are_qualified_by_the_own_xml_or_numeric_notes(self):
        source=ROOT/'TestBuilds/r471/upstream/gmx.midi.xml'
        if not source.exists():self.skipTest('Primary owner cache is optional')
        root=ET.parse(source);self.assertEqual(root.findtext('./info/name'),'Gemini GMX')
        wires={(int(c.findtext('status'),16),int(c.findtext('midino'))):c.findtext('key') for c in root.findall('.//controls/control')}
        profiles=json.loads((ROOT/'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles'];p=next(x for x in profiles if x['id']=='Gemini GMX')
        spec=(source.parent/'gmx-midi-spec.txt').read_text()
        for r in p['inputs']:
            key=((0x90 if r['kind']=='note' else 0xB0)+r['channel'],r['number'])
            if key in wires:continue
            self.assertEqual(r['kind'],'note');self.assertIn(r['channel'],[0,1])
            self.assertRegex(spec,rf'(?m)^\s*{r["number"]}\s+(Loop In|Loop Out|Loop x2|Loop /2|Range|Shift)')
        self.assertIn('Channel 4: Global',spec);self.assertIn('Crossfader (0 = B, 127 = A)',spec)
        self.assertIn('Master Volume (0 = max, 127 = min)',spec);self.assertIn('Cue Mix (0 = master, 127 = cue)',spec)

    def test_primary_owner_sources_and_separate_manufacturer_guide_are_pinned(self):
        from gmx import GMX_REFERENCES
        ref=GMX_REFERENCES['Gemini GMX'];self.assertEqual(ref['upstreamRevision'],'67f88e747bd8c8e04048f29945e7d87506e863f1')
        for f in ref['files']:
            p=ROOT/f['cachePath']
            if p.exists():self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(),f['sha256'])
