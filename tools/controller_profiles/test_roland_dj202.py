"""DJ-202 facts retain its own loop numbers and nonstandard low-byte addresses."""
import hashlib
import json
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class DJ202Tests(unittest.TestCase):
    def test_independent_manual_normal_contract(self):
        rows = json.loads((ROOT / 'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']
        p = next(p for p in rows if p['id'] == 'Roland DJ-202')
        self.assertEqual((len(p['inputs']), p['autoSelect']), (110, False))
        self.assertEqual((p['outputs'], p['startup'], p['shutdown']), ([], [], []))
        self.assertNotIn('audioOutput', p)
        pairs = [r for r in p['inputs'] if r['encoding'] == 'paired14Bit']
        self.assertEqual(len(pairs), 24)
        self.assertEqual({(r['number'], r['lowNumber']) for r in pairs}, {(9, 59), (22, 52), (23, 53), (24, 54), (25, 55), (28, 58)})
        self.assertTrue(all(r['inverted'] and r['shifted'] is False for r in pairs if r['number'] == 9))
        self.assertFalse(any(r['action'].startswith(('jog', 'wheelJog', 'load', 'crossfader', 'hotcue')) for r in p['inputs']))

    def test_all_active_wires_have_own_xml_facts(self):
        from roland_dj202 import dj202_profiles
        path = ROOT / 'TestBuilds/r436/upstream/Roland_DJ-202.midi.xml'
        if not path.exists(): return
        rows = ET.parse(path).findall('.//controls/control')
        facts = {(int(r.findtext('status'), 0), int(r.findtext('midino'), 0)): r.findtext('key') for r in rows}
        for r in dj202_profiles()[0]['inputs']:
            key = (r['channel'] + (0x90 if r['kind'] == 'note' else 0xB0), r['number'])
            self.assertIn(key, facts)
            if r['encoding'] == 'paired14Bit':
                self.assertIn('inputMSB', facts[key]); self.assertIn('inputLSB', facts[(key[0], r['lowNumber'])])
            if r['action'].startswith(('loopIn', 'loopOut', 'reloop')):
                self.assertIn('loopButton', facts[key]); self.assertIn(r['number'], [21, 22, 24])
        self.assertNotEqual({r['number'] for r in dj202_profiles()[0]['inputs'] if r['action'].startswith('loopIn')}, {56})

    def test_own_source_pins_and_independent_definition(self):
        from roland_dj202 import DJ202_REFERENCES
        ref = DJ202_REFERENCES['Roland DJ-202']
        catalogue = json.loads((ROOT / 'docs/coordination/controller-catalogue.json').read_text())
        self.assertEqual(next(d for d in catalogue['definitions'] if d['id'] == 'reviewed:roland-dj202')['source'], ref)
        for f in ref['files']:
            p = ROOT / f['cachePath']
            if p.exists(): self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(), f['sha256'])
