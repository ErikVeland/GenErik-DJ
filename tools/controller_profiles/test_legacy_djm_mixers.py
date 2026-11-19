"""Check independently reviewed legacy DJM mixer inputs and source boundaries."""
import hashlib
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
NAMES = ['Pioneer DJM-900NXS', 'Pioneer DJM-850', 'Pioneer DJM-750MK2']


class LegacyDJMMixerTests(unittest.TestCase):
    def test_three_independent_manual_profiles_retain_only_the_reviewed_mixer_core(self):
        runtime = json.loads((ROOT / 'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())
        by = {p['id']: p for p in runtime['profiles']}
        for name in NAMES:
            self.assertTrue(name in by, 'Add the independently reviewed legacy DJM table')
            p = by[name]
            self.assertEqual(len(p['inputs']), 32)
            self.assertFalse(p['autoSelect'] or p['outputs'] or p['startup'] or p['shutdown'])
            self.assertNotIn('audioOutput', p)
            self.assertTrue(all(r['kind'] == 'control' and r['channel'] == 0 and r['encoding'] == 'absolute' and not r['inverted'] for r in p['inputs']))
            self.assertEqual([(r['targetDeck'], r['number']) for r in p['inputs'] if r['action'].startswith('cueState')], list(zip('abcd', range(70, 74))))
            self.assertIn('Toggle', p['hardwareMode'])
            self.assertNotIn('DJM-900SRT', p['aliases'])
        self.assertNotIn('bankChanges', by[NAMES[0]])
        self.assertNotIn('bankChanges', by[NAMES[1]])
        self.assertEqual([(r['number'], r['decks']) for r in by[NAMES[2]]['bankChanges']], [(n, [d]) for d, ns in [('a', [51, 52, 53, 67]), ('b', [55, 56, 57, 69]), ('c', [59, 60, 61, 71]), ('d', [63, 64, 65, 73])] for n in ns])

    def test_850_decimal_and_nxs_hex_tables_agree_on_the_explicit_strip_fields(self):
        from legacy_djm_mixers import legacy_djm_mixer_profiles
        expected = [[1, 2, 3, 4, 5, 17, 70], [6, 7, 8, 9, 10, 18, 71], [12, 14, 15, 21, 22, 19, 72], [80, 81, 92, 82, 83, 20, 73]]
        for p in legacy_djm_mixer_profiles():
            for deck, numbers in zip('abcd', expected):
                self.assertEqual([r['number'] for r in p['inputs'] if r.get('targetDeck') == deck], numbers)
            self.assertEqual([(r['action'], r['number']) for r in p['inputs'] if 'targetDeck' not in r], [('crossfader', 11), ('master', 24), ('monitor', 26), ('cueMix', 27)])

    def test_each_model_has_its_own_pinned_manufacturer_document(self):
        from legacy_djm_mixers import LEGACY_DJM_REFERENCES
        self.assertEqual(set(LEGACY_DJM_REFERENCES), set(NAMES))
        for ref in LEGACY_DJM_REFERENCES.values():
            p = ROOT / 'TestBuilds/r393/upstream' / ref['cacheName']
            if p.exists():
                self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(), ref['sha256'])
