"""VCI-380 uses the own manufacturer table and explicit pad-mode ownership."""
import hashlib
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class VCI380Tests(unittest.TestCase):
    def test_own_bounded_automatic_core(self):
        rows = json.loads((ROOT / 'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']
        p = next(p for p in rows if p['id'] == 'Vestax VCI-380')
        self.assertEqual((len(p['inputs']), p['autoSelect'], p['outputs'], p['startup'], p['shutdown']), (44, True, [], [], []))
        self.assertNotIn('audioOutput', p)
        self.assertEqual(p['inputModes'], [{'channel': ch, 'numbers': [56, 57, 58, 59], 'invalidatingSelectors': [{'channel': ch + 2, 'number': 56}]} for ch in [7, 8]])
        for ch in [7, 8]:
            inputs = [r for r in p['inputs'] if r['channel'] == ch]
            self.assertEqual({r['number'] for r in inputs if r['action'].startswith('hotcue')}, set(range(60, 68)))
            self.assertTrue(all(r['requiredMode'] == 56 and r['shiftChannel'] == ch and r['shifted'] is False for r in inputs if r['action'].startswith('hotcue')))
            self.assertEqual({r['number'] for r in inputs if r['kind'] == 'control'}, {7, 9, 70, 71, 72} | ({8, 88} if ch == 7 else set()))
        self.assertFalse(any(r['kind'] == 'control' and r['number'] in [13, 45, 69, 85, 86, 87, 91] for r in p['inputs']))
        self.assertEqual({r['action'] for r in p['inputs'] if r['number'] == 10 and r['channel'] in [7, 8]}, {'cueStateA', 'cueStateB'})

    def test_own_source_pins_and_definition(self):
        from vci380 import VCI380_REFERENCES
        ref = VCI380_REFERENCES['Vestax VCI-380']
        catalogue = json.loads((ROOT / 'docs/coordination/controller-catalogue.json').read_text())
        self.assertEqual(next(d for d in catalogue['definitions'] if d['id'] == 'reviewed:vci380-manufacturer-core')['source'], ref)
        for f in ref['files']:
            p = ROOT / f['cachePath']
            if p.exists(): self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(), f['sha256'])
