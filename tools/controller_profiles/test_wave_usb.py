"""Retain independent Wave USB modes without speculative ring setup writes."""
import hashlib
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class WaveUSBTests(unittest.TestCase):
    def test_wave_uses_its_own_composed_modifier_and_contact_contract(self):
        by={p['id']:p for p in json.loads((ROOT/'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']}
        self.assertTrue('Hercules DJControlWave' in by,'Add the independent manufacturer Wave USB contract')
        p=by['Hercules DJControlWave']
        self.assertEqual((len(p['inputs']),len(p['outputs'])),(42,14))
        self.assertTrue(p['autoSelect'])
        self.assertNotIn('audioOutput',p)
        self.assertEqual([r['number'] for r in p['inputs'] if r['action']=='shift'],[16,34])
        self.assertTrue(all('shiftChannel' not in r for r in p['inputs']))
        self.assertEqual([(r['number'],r['shifted']) for r in p['inputs'] if r['action'].startswith('load')],[(13,True),(31,True)])
        self.assertEqual({r['argument'] for r in p['inputs'] if r['action'].startswith(('jogA','jogB','wheelJog'))},{512})
        self.assertEqual([r['number'] for r in p['inputs'] if r['action'].startswith('tempo')],[2,3])
        self.assertTrue(all(r['inverted'] and r['layerIndependent'] for r in p['inputs'] if r['action'].startswith('tempo')))

    def test_manufacturer_archives_and_members_are_independently_pinned(self):
        from wave_usb import WAVE_REFERENCES
        ref=WAVE_REFERENCES['Hercules DJControlWave']
        for source in [ref]+ref['relatedSources']:
            if 'cacheName' not in source:continue
            p=ROOT/'TestBuilds/r399/upstream'/source['cacheName']
            if p.exists():self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(),source['sha256'])
        self.assertIn('720',ref['review'])

    def test_no_audio_generic_alias_or_unqualified_sysex_is_added(self):
        from wave_usb import wave_usb_profiles
        p=wave_usb_profiles()[0]
        self.assertEqual(len(p['startup']),14)
        self.assertEqual(p['startup'],p['shutdown'])
        self.assertTrue(all(m[0]==0x90 and m[2]==0 for m in p['startup']+p['shutdown']))
        self.assertTrue(all(0<=r['number']<48 for r in p['outputs']))
        self.assertNotIn('Universal DJ',p['aliases'])
        self.assertEqual(len(p['bankChanges']),2)
        self.assertTrue(all('releaseShiftChannels' not in r for r in p['bankChanges']))
        self.assertIn('Bluetooth',' '.join(p['gaps']))
