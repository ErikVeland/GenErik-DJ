"""Beyond Music definitions retain model-specific Cue and monitor contracts."""
import hashlib
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class BMICoreTests(unittest.TestCase):
    def test_manual_models_do_not_inherit_cue_or_monitor_from_each_other(self):
        by = {p['id']: p for p in json.loads((ROOT / 'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']}
        for model, count, lamps in [(1, 55, 12), (3, 58, 14)]:
            name = f'BeyondMusic (BMI) ABMA{model}'; self.assertTrue(name in by, name); p = by[name]
            self.assertEqual((len(p['inputs']), len(p['outputs']), p['autoSelect']), (count, lamps, False))
            self.assertEqual((p['startup'], p['shutdown']), ([], [])); self.assertNotIn('audioOutput', p)
            self.assertTrue(all(r['channel'] == 0 for r in p['inputs'] + p['outputs']))
            self.assertEqual(any(r['action'].startswith('cuePreview') for r in p['inputs']), model == 3)
            self.assertEqual(any(r['action'] == 'monitor' for r in p['inputs']), model == 3)
            self.assertFalse(any(r['action'].startswith(('jogTouch', 'seek', 'filterKnob')) for r in p['inputs']))
            self.assertNotIn('ABMA USBAUDIO', p['aliases'])

    def test_separate_source_members_and_hashes_reach_catalogue(self):
        from bmi_cores import BMI_REFERENCES, bmi_profiles
        catalogue = json.loads((ROOT / 'docs/coordination/controller-catalogue.json').read_text())
        by = {d['name']: d for d in catalogue['definitions'] if d['id'].startswith('reviewed:bmi-')}
        for p in bmi_profiles():
            ref = BMI_REFERENCES[p['id']]; self.assertTrue(p['id'] in by, p['id']); self.assertEqual(by[p['id']]['source'], ref)
            path = ROOT / ref['files'][0]['cachePath']
            if path.exists():
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), ref['files'][0]['sha256'])
                handler = path.read_text().split('function messageReceived', 1)[1].split('function notificationReceived', 1)[0]
                controls, notes = handler.split('case 0x90:', 1)
                for row in p['inputs']:
                    text = controls if row['kind'] == 'control' else notes
                    self.assertIn(f'case 0x{row["number"]:02X}:', text)
