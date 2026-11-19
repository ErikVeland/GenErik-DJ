"""Qualify independent grid and lifecycle contracts for three Launchpad generations."""
import hashlib
import json
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
NAMES=['Novation Launchpad X','Novation Launchpad Pro MK3','Novation Launchpad Pro']


class LaunchpadProgrammerTests(unittest.TestCase):
    def test_native_quadrants_use_all_grid_notes_without_sibling_modes(self):
        by={p['id']:p for p in json.loads((ROOT/'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']}
        for name in NAMES:
            self.assertTrue(name in by,name)
            p=by[name]
            self.assertEqual((len(p['inputs']),len(p['outputs'])),(64,52))
            self.assertEqual(p['role'],'accessory')
            self.assertEqual(p['autoSelect'],name!=NAMES[2])
            self.assertEqual({r['number'] for r in p['inputs']},{11+10*y+x for y in range(8) for x in range(8)})
            self.assertEqual({r['targetDeck'] for r in p['inputs']},set('abcd'))
            self.assertNotIn('audioOutput',p)

    def test_primary_programmer_guides_are_separately_pinned(self):
        from launchpad_programmer import PROGRAMMER_REFERENCES
        self.assertEqual(set(PROGRAMMER_REFERENCES),set(NAMES))
        for ref in PROGRAMMER_REFERENCES.values():
            cached=ROOT/'TestBuilds/r402/upstream'/ref['cacheName']
            if cached.exists():self.assertEqual(hashlib.sha256(cached.read_bytes()).hexdigest(),ref['sha256'])

    def test_automatic_mode_and_clear_packets_stay_bounded_and_model_specific(self):
        from launchpad_programmer import programmer_profiles
        by={p['id']:p for p in programmer_profiles()}
        for name,model in zip(NAMES[:2],[12,14]):
            p=by[name]
            self.assertEqual(p['startup'][0],[240,0,32,41,2,model,14,1,247])
            self.assertEqual(p['shutdown'][-1],[240,0,32,41,2,model,14,0,247])
            self.assertEqual(len(p['startup'])+len(p['shutdown']),6)
            self.assertEqual(p['startupAbort'],[p['shutdown'][-1]])
            for packet in p['startup'][1:]+p['shutdown'][:-1]:
                self.assertEqual(packet[:7],[240,0,32,41,2,model,3])
                self.assertLessEqual(len(packet),128)
                self.assertEqual(len(packet),104)
                self.assertTrue(all(packet[i]==0 and packet[i+2]==0 for i in range(7,len(packet)-1,3)))
            self.assertTrue(all('DAW' not in alias and 'DIN' not in alias for alias in p['portAliases']))
        self.assertEqual(by[NAMES[2]]['startup'],[])
        self.assertEqual(by[NAMES[2]]['shutdown'],[])
