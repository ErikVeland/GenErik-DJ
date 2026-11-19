"""APC20 uses its own mode2 source and independently authored QLC+ wire table."""
import hashlib
import json
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class APC20Tests(unittest.TestCase):
    def test_independent_paired_mode2_contract(self):
        rows = json.loads((ROOT / 'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']
        p = next(p for p in rows if p['id'] == 'Akai APC20')
        self.assertEqual((len(p['inputs']), len(p['outputs']), p['autoSelect'], p['role']), (63, 48, True, 'accessory'))
        self.assertEqual(p['startup'], [[240, 71, 127, 123, 96, 0, 4, 66, 8, 2, 1, 247]])
        self.assertEqual(p['shutdown'], [[240, 71, 127, 123, 96, 0, 4, 64, 8, 2, 1, 247]])
        self.assertEqual(p['startupAbort'], p['shutdown']); self.assertNotIn('audioOutput', p)
        self.assertTrue(all(r.get('shifted') is False for r in p['inputs'] if r['action'] != 'shift'))
        self.assertEqual({(r['channel'], r['number']) for r in p['inputs'] if r['action'].startswith('cuePreview')}, {(ch, 57) for ch in [1, 3, 5, 7]})
        self.assertEqual({r['number'] for r in p['inputs'] if r.get('pulse')}, {51})
        self.assertTrue(all(r['onValue'] in [1, 3] and r['offValue'] == 0 and r['offUsesNoteOn'] for r in p['outputs']))

    def test_each_native_wire_matches_the_own_qlc_profile(self):
        from apc20 import apc20_profiles
        path = ROOT / 'TestBuilds/r439/upstream/APC20.qxi'
        if not path.exists(): return
        root = ET.parse(path).getroot()
        facts = {int(r.attrib['Number']): r for r in root.findall('{*}Channel')}
        self.assertEqual(len(facts), 97)
        for r in apc20_profiles()[0]['inputs']:
            wire = (r['channel'] << 12) + (128 if r['kind'] == 'note' else 0) + r['number']
            self.assertIn(wire, facts)
            if r['kind'] == 'control' and r['number'] in [7, 14]: self.assertEqual(facts[wire].findtext('{*}Type'), 'Slider')
        grid = {(number >> 12, (number & 127)) for number in facts if 53 <= (number & 127) <= 57 and number & 128}
        self.assertEqual(grid, {(ch, n) for ch in range(8) for n in range(53, 58)})

    def test_own_source_pins_and_definition(self):
        from apc20 import APC20_REFERENCES
        ref = APC20_REFERENCES['Akai APC20']
        catalogue = json.loads((ROOT / 'docs/coordination/controller-catalogue.json').read_text())
        self.assertEqual(next(d for d in catalogue['definitions'] if d['id'] == 'reviewed:apc20-mode2-native')['source'], ref)
        for f in ref['files']:
            p = ROOT / f['cachePath']
            if p.exists(): self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(), f['sha256'])
