"""Retain independent legacy Pioneer transport and three-layer release facts."""
import hashlib
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class LegacyPioneerTransportTests(unittest.TestCase):
    def profiles(self):
        return {p['id']: p for p in json.loads((ROOT / 'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']}

    def test_t1_layers_keep_cue_release_and_independent_dual_crossfader_limits(self):
        by = self.profiles()
        self.assertTrue('Pioneer DJM-T1' in by, 'Add the independently documented T1')
        p = by['Pioneer DJM-T1']
        self.assertFalse(p['autoSelect'])
        self.assertEqual((len(p['inputs']), len(p['outputs'])), (60, 14))
        self.assertFalse(p['startup'] or p['shutdown'])
        self.assertEqual(p['startup'], p['shutdown'])
        self.assertNotIn('audioOutput', p)
        self.assertTrue(all(r['channel'] == 0 for r in p['inputs'] + p['outputs']))
        self.assertEqual({r['number'] for r in p['inputs'] if r.get('releaseOnly')}, {75, 76, 125, 126})
        self.assertFalse(any(r['action'] == 'crossfader' for r in p['inputs']))
        for deck, ns in [('a', [13, 77, 89]), ('b', [14, 78, 90])]:
            self.assertEqual([r['number'] for r in p['inputs'] if r['action'].startswith('gain') and r.get('targetDeck') == deck], ns)

    def test_mep_has_its_own_default_channel_loading_and_absolute_speed_contract(self):
        by = self.profiles()
        self.assertTrue('Pioneer MEP-7000' in by, 'Add the independent MEP table')
        p = by['Pioneer MEP-7000']
        self.assertTrue(p['autoSelect'])
        self.assertEqual(len(p['inputs']), 26)
        self.assertFalse(p['outputs'] or p['startup'] or p['shutdown'])
        self.assertNotIn('audioOutput', p)
        self.assertEqual([(r['channel'],r['number'],r['targetDeck']) for r in p['inputs'] if r['action'].startswith('load')], [(0,52,'a'),(0,53,'b')])
        self.assertEqual([(r['channel'],r['number'],r['encoding']) for r in p['inputs'] if r['action'].startswith('jog') and r['kind']=='control'], [(0,16,'cdjPlatterSpeed'),(1,16,'cdjPlatterSpeed')])
        self.assertEqual([(r['channel'],r['number'],r['encoding']) for r in p['inputs'] if r['action'].startswith('tempo')], [(0,29,'cdjTempo'),(1,29,'cdjTempo')])
        self.assertNotIn('SEP-C1', p['aliases'])

    def test_model_specific_manufacturer_manual_bytes_remain_pinned(self):
        from legacy_pioneer_transport import LEGACY_PIONEER_TRANSPORT_REFERENCES
        for ref in LEGACY_PIONEER_TRANSPORT_REFERENCES.values():
            p = ROOT / 'TestBuilds/r396/upstream' / ref['cacheName']
            if p.exists():
                self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(), ref['sha256'])
