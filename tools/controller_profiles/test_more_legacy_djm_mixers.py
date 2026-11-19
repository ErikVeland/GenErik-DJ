"""Retain independent SRT ownership, original750 controls and250MK2 evidence limits."""
import hashlib
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class MoreLegacyDJMTests(unittest.TestCase):
    def test_distinct_manual_models_keep_their_own_strip_layouts_and_input_counts(self):
        runtime = json.loads((ROOT / 'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())
        by = {p['id']: p for p in runtime['profiles']}
        for name, count in [('Pioneer DJM-900SRT', 32), ('Pioneer DJM-750', 28), ('Pioneer DJM-250MK2', 18)]:
            self.assertTrue(name in by, 'Add independent manufacturer model facts')
            p = by[name]
            self.assertEqual(len(p['inputs']), count)
            self.assertFalse(p['autoSelect'] or p['outputs'] or p['startup'] or p['shutdown'])
            self.assertNotIn('audioOutput', p)
            self.assertTrue(all(r['kind'] == 'control' and r['channel'] == 0 and r['encoding'] == 'absolute' for r in p['inputs']))
        self.assertEqual([(r['targetDeck'], r['number']) for r in by['Pioneer DJM-900SRT']['inputs'] if r['action'].startswith('cueState')], list(zip('cabd', [70, 71, 72, 73])))
        self.assertFalse(any(r['action'].startswith('filterKnob') for r in by['Pioneer DJM-750']['inputs']))
        self.assertNotIn('bankChanges', by['Pioneer DJM-750'])
        self.assertEqual({r['targetDeck'] for r in by['Pioneer DJM-250MK2']['inputs'] if 'targetDeck' in r}, {'a', 'b'})
        self.assertEqual([(r['number'], r['decks']) for r in by['Pioneer DJM-900SRT']['bankChanges']], [(n, [d]) for d, start in zip('cabd', [50, 54, 58, 62]) for n in range(start, start + 4)])
        self.assertEqual([(r['number'], r['decks']) for r in by['Pioneer DJM-250MK2']['bankChanges']], [(n, [d]) for d, ns in [('a', [51, 52, 53]), ('b', [55, 56, 57])] for n in ns])

    def test_source_boundaries_do_not_turn_shared_fields_into_sibling_aliases(self):
        from more_legacy_djm_mixers import more_legacy_djm_profiles, MORE_LEGACY_DJM_REFERENCES
        for p in more_legacy_djm_profiles():
            self.assertEqual({r['number'] for r in p['inputs'] if r['action'].startswith('cueState')}, {70, 71} if p['id'].endswith('250MK2') else {70, 71, 72, 73})
            self.assertTrue('DJM-750MK2' not in p['aliases'])
            ref = MORE_LEGACY_DJM_REFERENCES[p['id']]
            self.assertIn('review', ref)
        ref = MORE_LEGACY_DJM_REFERENCES['Pioneer DJM-250MK2']
        self.assertNotIn('sha256', ref)
        self.assertIn('cached', ref['evidenceLimit'].lower())
        self.assertIn('unavailable', ref['evidenceLimit'].lower())

    def test_available_manufacturer_manual_bytes_remain_independently_pinned(self):
        from more_legacy_djm_mixers import MORE_LEGACY_DJM_REFERENCES
        for ref in MORE_LEGACY_DJM_REFERENCES.values():
            for document in [ref] + ref.get('relatedSources', []):
                if 'cacheName' not in document:
                    continue
                p = ROOT / 'TestBuilds/r394/upstream' / document['cacheName']
                if p.exists():
                    self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(), document['sha256'])
