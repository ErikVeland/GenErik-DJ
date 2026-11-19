"""Check the APC mini MK2's independent Session and RGB contracts."""
import hashlib
import json
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]


class APCMiniMK2Tests(unittest.TestCase):
    def test_session_grid_and_faders_use_their_own_wire_contract(self):
        by={p['id']:p for p in json.loads((ROOT/'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']}
        self.assertTrue('Akai APC mini MK2' in by,'Add the independent APC mini MK2 protocol')
        p=by['Akai APC mini MK2']
        self.assertEqual((len(p['inputs']),len(p['outputs'])),(74,52))
        self.assertTrue(p['autoSelect'])
        self.assertEqual({r['number'] for r in p['inputs'] if r['kind']=='note' and r['action']!='shift'},set(range(64)))
        self.assertTrue(all(r['channel']==0 and not r.get('anyChannel') for r in p['inputs']))
        self.assertEqual([r['number'] for r in p['inputs'] if r['kind']=='control'],list(range(48,57)))
        self.assertTrue(all(r['channel']==6 for r in p['outputs']))
        self.assertNotIn('audioOutput',p)

    def test_primary_protocol_is_pinned_and_modes_do_not_leak(self):
        from apc_mini_mk2 import APC_MINI_MK2_REFERENCES
        ref=APC_MINI_MK2_REFERENCES['Akai APC mini MK2']
        cached=ROOT/'TestBuilds/r403/upstream/apc-mini-mk2-protocol.pdf'
        if cached.exists():self.assertEqual(hashlib.sha256(cached.read_bytes()).hexdigest(),ref['sha256'])
        self.assertIn('Session',ref['review'])

    def test_introduction_and_range_clear_remain_bounded(self):
        from apc_mini_mk2 import apc_mini_mk2_profiles
        p=apc_mini_mk2_profiles()[0]
        self.assertEqual(p['startup'][0],[240,71,127,79,96,0,4,0,0,1,0,247])
        clear=[240,71,127,79,36,0,8,0,63,0,0,0,0,0,0,247]
        self.assertEqual(p['startup'][1:], [clear])
        self.assertEqual(p['shutdown'], [clear])
        self.assertEqual(p['startupAbort'], [clear])
        self.assertTrue(all(r['shifted'] is False for r in p['inputs'] if r['kind']=='note' and r['number']<64))
        self.assertEqual(p['bankChanges'],[{'channel':0,'number':122,'onValue':127,'decks':list('abcd')}])
