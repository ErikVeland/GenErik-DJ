"""Orbit uses the published factory template without writing a stored preset."""
import hashlib
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class OrbitTests(unittest.TestCase):
    def test_automatic_native_pad_layout_keeps_unqualified_controls_inactive(self):
        records = json.loads((ROOT / 'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']
        matches = [p for p in records if p['id'] == 'Numark Orbit']; self.assertEqual(len(matches), 1); p = matches[0]
        self.assertEqual((len(p['inputs']), len(p['outputs']), p['autoSelect'], p['inputProtocol']), (64, 0, True, 'orbit'))
        self.assertEqual((p['startup'], p['shutdown']), ([], [])); self.assertNotIn('audioOutput', p)
        self.assertEqual({r['channel'] for r in p['inputs']}, {0, 1, 2, 3})
        self.assertTrue(all(r['kind'] == 'note' and 36 <= r['number'] <= 51 for r in p['inputs']))
        self.assertEqual(len([r for r in p['inputs'] if r['action'].startswith('hotcue')]), 32)
        self.assertNotIn('USB Audio Device', p['aliases'])

    def test_each_pad_wire_and_momentary_mode_exists_in_the_own_factory_template(self):
        from orbit import ORBIT_REFERENCES, orbit_profiles
        ref = ORBIT_REFERENCES['Numark Orbit']; catalogue = json.loads((ROOT / 'docs/coordination/controller-catalogue.json').read_text())
        entry = next(d for d in catalogue['definitions'] if d['id'] == 'reviewed:orbit-factory-native-pads')
        self.assertEqual(entry['source'], ref)
        for f in ref['files']:
            path = ROOT / f['cachePath']
            if path.exists(): self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), f['sha256'])
        path = ROOT / ref['files'][1]['cachePath']
        if not path.exists(): return
        data = json.loads(path.read_text())['pattrstorage']['slots']['1']['data']; wires = set()
        for bank in ['', '[1]', '[2]', '[3]']:
            for pad in [''] + [f'[{n}]' for n in range(1, 16)]:
                prefix = f'AllBanks::ABank{bank}::AllPads::APad{pad}::'
                self.assertEqual(data[prefix + 'umenu'], [0])
                wires.add((data[prefix + 'number[3]'][0] - 1, data[prefix + 'number[2]'][0]))
        self.assertEqual(wires, {(r['channel'], r['number']) for r in orbit_profiles()[0]['inputs']})
