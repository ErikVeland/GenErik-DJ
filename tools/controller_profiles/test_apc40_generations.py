"""Keep original and MKII APC40 protocols separate from native app functions."""
import hashlib
import json
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
NAMES=['Akai APC40 MKII','Akai APC40']


class APC40GenerationTests(unittest.TestCase):
    def test_independent_generations_use_bounded_native_controls(self):
        by={p['id']:p for p in json.loads((ROOT/'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']}
        for name,count in zip(NAMES,[114,113]):
            self.assertTrue(name in by,name)
            p=by[name]
            self.assertEqual((len(p['inputs']),len(p['outputs'])),(count,68))
            self.assertTrue(p['autoSelect'])
            self.assertTrue(p['unbankedGlobalInputs'])
            self.assertEqual(sum(r['kind']=='control' for r in p['outputs']),16)
            self.assertEqual(len(p['bankChanges']),16)
            self.assertEqual({r['channel'] for r in p['bankChanges']},set(range(16)))
            self.assertNotIn('audioOutput',p)
        old=by[NAMES[1]]
        self.assertEqual({(r['channel'],r['number']) for r in old['inputs'] if r['action'].startswith('cuePreview')},{(1,57),(3,57),(5,57),(7,57)})
        self.assertEqual({r['number'] for r in by[NAMES[0]]['inputs'] if r['action'].startswith('cuePreview')},{33,35,37,39})

    def test_primary_manufacturer_protocols_are_pinned_independently(self):
        from apc40_generations import APC40_REFERENCES
        for name,path in [(NAMES[0],'TestBuilds/r403/upstream/apc40-mk2-protocol.pdf'),(NAMES[1],'TestBuilds/r404/upstream/apc40-original-protocol.pdf')]:
            cached=ROOT/path
            if cached.exists():self.assertEqual(hashlib.sha256(cached.read_bytes()).hexdigest(),APC40_REFERENCES[name]['sha256'])

    def test_each_model_selects_its_own_momentary_mode_and_restores_generic(self):
        from apc40_generations import apc40_profiles
        by={p['id']:p for p in apc40_profiles()}
        for name,product in zip(NAMES,[41,115]):
            p=by[name]
            self.assertEqual(p['startup'],[[240,71,127,product,96,0,4,65,0,1,0,247]])
            self.assertEqual(p['shutdown'][-1],[240,71,127,product,96,0,4,64,0,1,0,247])
            self.assertEqual(p['startupAbort'],[p['shutdown'][-1]])
            self.assertEqual(len(p['shutdown']),53)
            self.assertTrue(all(m[0] in range(0x80,0x88) and m[2]==0 for m in p['shutdown'][:-1]))
            self.assertEqual({r['encoding'] for r in p['inputs'] if r['action']=='monitor'},{'twosComplement'})
            self.assertEqual(len(p['startup'])+len(p['shutdown'])+len(p['startupAbort']),55)
