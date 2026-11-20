"""Primary Xone axis contracts keep map, driver and note-number limits explicit."""
import hashlib
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class LegacyXoneAxesTests(unittest.TestCase):
    def test_each_model_uses_only_its_own_confirmed_map2_axes(self):
        records = json.loads((ROOT / 'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']
        by = {p['id']: p for p in records}
        for model, count, levels in [('1D', 18, [19, 18, 17, 16]), ('2D', 19, [31, 30, 29, 28]), ('4D', 35, [19, 18, 17, 16, 31, 30, 29, 28])]:
            name = f'Allen & Heath XONE {model}'
            self.assertTrue(name in by, name); p = by[name]
            self.assertEqual((len(p['inputs']), len(p['outputs']), p['autoSelect']), (count, 0, False))
            self.assertEqual((p['startup'], p['shutdown']), ([], []))
            self.assertTrue(all(r['kind'] == 'control' and r['channel'] == 15 for r in p['inputs']))
            self.assertEqual([r['number'] for r in p['inputs'] if r['action'].startswith('level')], levels)
            self.assertFalse(any(r['action'].startswith(('play', 'cue', 'jog', 'tempo', 'hotcue')) for r in p['inputs']))
            self.assertNotIn('audioOutput', p)

    def test_all_three_primary_guides_are_pinned_independently(self):
        from legacy_xone_axes import XONE_AXIS_REFERENCES
        catalogue = json.loads((ROOT / 'docs/coordination/controller-catalogue.json').read_text())
        by = {d['name']: d for d in catalogue['definitions'] if d['id'].startswith('manufacturer:xone-axes-')}
        for name, ref in XONE_AXIS_REFERENCES.items():
            self.assertTrue(name in by, name); self.assertEqual(by[name]['source'], ref)
            path = ROOT / ref['cachePath']
            if path.exists(): self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), ref['sha256'])
