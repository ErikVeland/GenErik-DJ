"""Qualify independent current Launch Control DAW interfaces and lifecycle."""
import json
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
NAMES=['Novation Launch Control 3','Novation LaunchControl XL3']

class LaunchControlDAWTests(unittest.TestCase):
    def test_independent_models_have_strict_daw_ports_and_native_targets(self):
        by={p['id']:p for p in json.loads((ROOT/'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']}
        for name,counts in zip(NAMES,[(25,24),(54,36)]):
            self.assertTrue(name in by,name)
            p=by[name]
            self.assertEqual((len(p['inputs']),len(p['outputs'])),counts)
            self.assertTrue(p['autoSelect'])
            self.assertEqual(p['inputProtocol'],'launchControlDAW')
            self.assertEqual(p['role'],'accessory')
            self.assertTrue(all('DAW' in alias.upper() for alias in p['portAliases']))
            self.assertEqual({r['channel'] for r in p['inputs']},{0,6,15})
            self.assertEqual({r['targetDeck'] for r in p['inputs'] if r['action'].startswith('cuePreview')},set('abcd'))
            self.assertNotIn('audioOutput',p)

    def test_each_guide_product_has_its_own_temporary_mode_and_abort(self):
        from launch_control_daw import launch_control_daw_profiles
        for p,product,rows in zip(launch_control_daw_profiles(),[22,21],[2,3]):
            self.assertEqual(p['startup'][0],[240,0,32,41,2,product,2,127,247])
            self.assertEqual(p['startup'][1],[182,30,2])
            self.assertTrue(all([182,n,0] in p['startup'] for n in [69,72]+([73] if rows==3 else [])))
            self.assertEqual(p['shutdown'][-1],[240,0,32,41,2,product,2,0,247])
            self.assertEqual(p['startupAbort'],[p['shutdown'][-1]])
            self.assertLessEqual(len(p['startup'])+len(p['shutdown'])+len(p['startupAbort']),64)
            self.assertTrue(all(len(m)<=128 for m in p['startup']+p['shutdown']))

    def test_sources_pin_distinct_primary_bytes(self):
        import hashlib
        from launch_control_daw import LAUNCH_CONTROL_DAW_REFERENCES
        for name,filename in zip(NAMES,['launch-control-3-programmer.pdf','launch-control-xl3-programmer.pdf']):
            path=ROOT/'TestBuilds/r405/upstream'/filename
            if path.exists():self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(),LAUNCH_CONTROL_DAW_REFERENCES[name]['sha256'])
