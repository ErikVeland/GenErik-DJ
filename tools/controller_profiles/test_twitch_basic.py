"""Check the published Twitch Basic mode without advanced-mode guesses."""
import hashlib
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class TwitchBasicTests(unittest.TestCase):
    def test_basic_mode_has_banked_loads_and_fixed_four_deck_wires(self):
        by = {p['id']: p for p in json.loads((ROOT/'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']}
        self.assertTrue('Novation Twitch' in by, 'Add the published independent Twitch Basic MIDI contract')
        p = by['Novation Twitch']
        self.assertEqual((len(p['inputs']), len(p['outputs'])), (139, 44))
        self.assertTrue(p['autoSelect'])
        loads = [r for r in p['inputs'] if r['action'].startswith('load')]
        self.assertEqual([(r['channel'], r['number'], r['deckBank']) for r in loads], [(7,82,0),(7,83,1)])
        for deck in 'abcd':
            rows = [r for r in p['inputs'] if r.get('targetDeck') == deck and r['action'].startswith('jogTouch')]
            self.assertEqual([(r['channel'],r['number'],r['encoding']) for r in rows], [(7+'abcd'.index(deck),71,'absolute')])
        self.assertNotIn('audioOutput', p)

    def test_primary_reference_and_mode_reset_are_bounded(self):
        from twitch_basic import TWITCH_REFERENCES, twitch_basic_profiles
        ref = TWITCH_REFERENCES['Novation Twitch']
        cached = ROOT/'TestBuilds/r400/upstream/twitch-programmers-reference.pdf'
        if cached.exists():
            self.assertEqual(hashlib.sha256(cached.read_bytes()).hexdigest(),ref['sha256'])
        p = twitch_basic_profiles()[0]
        self.assertEqual(p['startup'], [[0xB7,0,0]])
        self.assertEqual(p['shutdown'][-1], [0xB7,0,0])
        self.assertEqual(len(p['shutdown']),45)
        self.assertTrue(all(m[0] in range(0x97,0x9B) and m[2]==0 for m in p['shutdown'][:-1]))
        self.assertFalse(any(r['action'].startswith('load') for r in p['outputs']))

    def test_basic_controls_do_not_inherit_advanced_or_audio_writes(self):
        from twitch_basic import twitch_basic_profiles
        p = twitch_basic_profiles()[0]
        self.assertEqual({r['argument'] for r in p['inputs'] if r['action'].startswith(('jogA','jogB'))},{127})
        self.assertTrue(all(r['requiresTouch'] for r in p['inputs'] if r['action'].startswith(('jogA','jogB'))))
        self.assertEqual({r['onValue'] for r in p['outputs']},{16,79,127})
        self.assertFalse(any(r['action'] in ['master','monitor','cueMix'] for r in p['inputs']))
        self.assertEqual(len(p['bankChanges']),22)
        self.assertIn('calibration',' '.join(p['gaps']))
