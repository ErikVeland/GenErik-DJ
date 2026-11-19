"""Both Contour editions require their own primary evidence and inventory rows."""
import hashlib
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class ContourTests(unittest.TestCase):
    def test_both_editions_share_only_the_independently_qualified_default_core(self):
        runtime = json.loads((ROOT / 'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())
        rows = [p for p in runtime['profiles'] if p['id'] == 'Reloop CONTOUR']
        self.assertEqual(len(rows), 1)
        p = rows[0]
        self.assertEqual((len(p['inputs']), len(p['outputs']), len(p['bankChanges'])), (164, 48, 32))
        self.assertTrue(p['autoSelect'])
        self.assertEqual((p['startup'], p['shutdown']), ([], []))
        self.assertFalse(any(r['action'].startswith(('keylock', 'tempo', 'master', 'monitor')) for r in p['inputs']))
        for r in p['inputs']:
            self.assertIn(r['channel'], range(4))
            if r['kind'] == 'note' and not r.get('releaseOnly'):
                self.assertTrue(any(g.get('releaseOnly') and g['channel'] == r['channel'] and g['number'] == r['number']+64 and g['action'] == r['action'] for g in p['inputs']))
        catalogue = json.loads((ROOT / 'docs/coordination/controller-catalogue.json').read_text())
        by = {m['name']: m for m in catalogue['models']}
        for name in ['Reloop Contour Controller Edition', 'Reloop Contour Interface Edition']:
            self.assertTrue(name in by, name)
            self.assertEqual(by[name]['profile'], 'Reloop CONTOUR')
            self.assertTrue(by[name]['isPhysicalModel'])
        self.assertFalse(any(m['name'] == 'Reloop CONTOUR' and m['isPhysicalModel'] for m in catalogue['models']))

    def test_each_manufacturer_guide_is_pinned(self):
        from contour import CONTOUR_REFERENCES
        for source in CONTOUR_REFERENCES['Reloop CONTOUR']['files']:
            path = ROOT / source['cachePath']
            if path.exists(): self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), source['sha256'])
