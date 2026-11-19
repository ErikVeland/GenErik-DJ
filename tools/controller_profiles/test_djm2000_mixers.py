"""Keep both2000 manufacturer charts independent of touchscreen MIDI zones."""
import hashlib
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class DJM2000Tests(unittest.TestCase):
    def test_independent_models_have_only_reviewed_zone1_mixer_fields(self):
        by = {p['id']: p for p in json.loads((ROOT / 'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']}
        for name in ['Pioneer DJM-2000', 'Pioneer DJM-2000NXS']:
            self.assertTrue(name in by, 'Add independent2000 manufacturer facts')
            p = by[name]
            self.assertEqual(len(p['inputs']), 32)
            self.assertFalse(p['autoSelect'] or p['outputs'] or p['startup'] or p['shutdown'])
            self.assertNotIn('bankChanges', p)
            self.assertNotIn('audioOutput', p)
            self.assertTrue(all(r['kind'] == 'control' and r['channel'] == 0 and r['encoding'] == 'absolute' for r in p['inputs']))
            self.assertEqual([(r['targetDeck'], r['number']) for r in p['inputs'] if r['action'].startswith('cueState')], list(zip('abcd', [70, 71, 72, 73])))
            self.assertFalse({13, 45, 110, 111, 112, 113, 114, 115}.intersection(r['number'] for r in p['inputs']))

    def test_model_references_keep_zones_and_audio_limits_explicit(self):
        from djm2000_mixers import djm2000_profiles, DJM2000_REFERENCES
        for p in djm2000_profiles():
            self.assertIn('Zone1', p['hardwareMode'])
            self.assertIn('Zone2', ' '.join(p['gaps']))
            self.assertNotIn('DJM-TOUR1', p['aliases'])
            self.assertIn('review', DJM2000_REFERENCES[p['id']])
        self.assertNotEqual(DJM2000_REFERENCES['Pioneer DJM-2000']['url'], DJM2000_REFERENCES['Pioneer DJM-2000NXS']['url'])

    def test_recovered_manual_bytes_match_each_independent_pin(self):
        from djm2000_mixers import DJM2000_REFERENCES
        for ref in DJM2000_REFERENCES.values():
            p = ROOT / 'TestBuilds/r395/upstream' / ref['cacheName']
            if p.exists():
                self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(), ref['sha256'])
