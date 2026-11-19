"""Retain reconciled Universal DJ facts without inheriting older table errors."""
import hashlib
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class UniversalDJTests(unittest.TestCase):
    def test_current_factory_consensus_keeps_independent_mixer_and_pitch_pairs(self):
        by = {p['id']:p for p in json.loads((ROOT / 'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']}
        self.assertTrue('Hercules Universal DJ' in by,'Add independently reconciled Universal DJ USB facts')
        p=by['Hercules Universal DJ']
        self.assertTrue(p['autoSelect'])
        self.assertEqual((len(p['inputs']),len(p['outputs'])),(111,30))
        self.assertEqual(len(p['startup']),30)
        self.assertEqual(p['startup'],p['shutdown'])
        self.assertNotIn('audioOutput',p)
        self.assertEqual([(r['number'],r.get('lowNumber'),r['targetDeck'],r['inverted']) for r in p['inputs'] if r['action'].startswith('tempo')],[(1,33,'a',True),(55,71,'a',True),(2,34,'b',True),(56,72,'b',True)])
        for deck,ns in [('a',[57,59,60,61]),('b',[58,62,63,64])]:
            self.assertEqual([r['number'] for r in p['inputs'] if r.get('targetDeck')==deck and r['action'].startswith(('level','high','mid','low'))],ns)
        self.assertEqual({r['argument'] for r in p['inputs'] if r['action'].startswith(('jogA','jogB','wheelJog'))},{512})

    def test_reviewed_sources_remain_pinned_without_licence_or_code_reuse(self):
        from universal_dj import UNIVERSAL_REFERENCES
        ref=UNIVERSAL_REFERENCES['Hercules Universal DJ']
        for source in [ref]+ref['relatedSources']:
            if 'cacheName' not in source:continue
            p=ROOT/'TestBuilds/r398/upstream'/source['cacheName']
            if p.exists():self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(),source['sha256'])
        self.assertIn('conflict',ref['review'].lower())
        self.assertIn('128',ref['review'])

    def test_core_keeps_usb_mode_and_two_deck_limits_explicit(self):
        from universal_dj import universal_dj_profiles
        p=universal_dj_profiles()[0]
        self.assertIn('DJHERCULESMIX Universal DJ',p['aliases'])
        self.assertNotIn('Périphérique MIDI USB',p['aliases'])
        self.assertNotIn('DJControlWave',p['aliases'])
        self.assertEqual({r['targetDeck'] for r in p['inputs'] if 'targetDeck' in r},{'a','b'})
        self.assertEqual(len(p['bankChanges']),2)
        self.assertTrue(all(0<=b<128 for m in p['startup']+p['shutdown'] for b in m[1:]))
        self.assertTrue(all(m[0]==0x90 or m[0]==0x91 for m in p['startup']+p['shutdown']))
        self.assertIn('Bluetooth',' '.join(p['gaps']))
