"""Manufacturer defaults remain independent from conflicting public presets."""
import hashlib
import json
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
NAMES=['American Audio VERSADECK','Synq DMC-2000','CITRONIC MPX10']

class LegacyUSBPlayersTests(unittest.TestCase):
    def test_primary_default_cores_have_bounded_release_guards_and_owned_lamps(self):
        by={p['id']:p for p in json.loads((ROOT/'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']}
        for name in NAMES:
            self.assertTrue(name in by,name)
            p=by[name]
            self.assertTrue(p['autoSelect'])
            self.assertEqual((len(p['inputs']),sum(r.get('releaseOnly',False) for r in p['inputs'])),(78,30))
            self.assertEqual((len(p['outputs']),p['startup'],p['shutdown']),(16,[],[]))
            self.assertEqual(p['inputProtocol'],'legacyUSBPlayer')
            self.assertNotIn('audioOutput',p)
            self.assertFalse(any(r['action'].startswith(('jog','tempo','sync','shift')) for r in p['inputs']))
            self.assertEqual({r['channel'] for r in p['inputs'] if r.get('targetDeck')=='b'},{2})
            self.assertEqual({r['channel'] for r in p['inputs'] if r['action']=='crossfader'},{1})
            for r in p['outputs']:
                self.assertEqual(r['onValue'],1 if name==NAMES[0] and r['action'].startswith('hotcue') else 127)

    def test_independent_manufacturer_documents_are_pinned(self):
        from legacy_usb_players import LEGACY_USB_REFERENCES
        for name in NAMES:
            r=LEGACY_USB_REFERENCES[name];p=ROOT/f"TestBuilds/{r.get('cacheRequest','r411')}/upstream"/r['cacheName']
            if p.exists():self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(),r['sha256'])

    def test_dmc_native_wires_and_guards_exist_in_its_own_official_tsi(self):
        import re
        from tsi_facts import inspect_tsi
        from legacy_usb_players import legacy_usb_player_profiles
        path=ROOT/'TestBuilds/r411/upstream/dmc2000-basic.tsi'
        if not path.exists():self.skipTest('Optional public source cache is absent')
        tones={'C':0,'C#':1,'D':2,'D#':3,'E':4,'F':5,'F#':6,'G':7,'G#':8,'A':9,'A#':10,'B':11};wires=set()
        for d in inspect_tsi(path.read_bytes()):
            for r in d['mappings']:
                m=re.fullmatch(r'Ch(\d+)\.Note\.([A-G]#?)(-?\d+)',r['signal'])
                if m:wires.add((r['direction'],'note',int(m[1])-1,tones[m[2]]+12*(int(m[3])+1)))
                m=re.fullmatch(r'Ch(\d+)\.CC\.(\d+)',r['signal'])
                if m:wires.add((r['direction'],'control',int(m[1])-1,int(m[2])))
        p=next(p for p in legacy_usb_player_profiles() if p['id']==NAMES[1])
        # The basic TSI does not map every manufacturer control. Check its independently overlapping subset.
        for r in p['inputs']:
            if r['kind']=='note' and r['number'] in [1,2,3,4,8,9,10,11,29,31,32,34,35]:
                self.assertIn((0,r['kind'],r['channel'],r['number']),wires)
