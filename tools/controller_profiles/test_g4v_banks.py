"""The separate unmerged G4V revision qualifies explicit native manual banks."""
import json
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]


class G4VBanksTests(unittest.TestCase):
    def test_every_active_wire_has_an_independent_pinned_xml_assignment(self):
        profiles=json.loads((ROOT/'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']
        p=next(x for x in profiles if x['id']=='Gemini G4V')
        self.assertEqual(len(p['inputs']),39);self.assertNotIn('role',p)
        self.assertEqual(p['bankChanges'],[{'channel':i,'number':38,'onValue':127,'decks':list('ac' if i==0 else 'bd'),'deckBank':i} for i in range(2)])
        source=ROOT/'TestBuilds/r468/upstream/g4v.midi.xml'
        if not source.exists():self.skipTest('Pinned primary PR cache is optional')
        definitions=ET.parse(source).findall('.//controls/control')
        wires={(int(c.findtext('status'),16),int(c.findtext('midino'),16)):c.findtext('key') for c in definitions}
        for r in p['inputs']:
            wire=((0x90 if r['kind']=='note' else 0xB0)+r['channel'],r['number']);self.assertIn(wire,wires)
            if 'deckBank' in r:
                self.assertEqual(r['deckBank'],r['channel']);self.assertIn(r['action'],['playA','playB','cuePreviewA','cuePreviewB','syncA','syncB','keylockA','keylockB'])
        for i in range(2):self.assertIn('deckToggleBtn',wires[(0x90+i,38)])
        s=(source.parent/'g4v-scripts.js').read_text();self.assertIn('this.deck.toggle();',s)
        self.assertIn('invert: 1,',s)
