"""Legacy Launch Control XL has an independently pinned configured-template format."""
import hashlib
import json
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
NAME='Novation Launch Control XL'

class LaunchControlXLTemplateTests(unittest.TestCase):
    def test_xl_uses_its_own_read_contract_and_physical_layout(self):
        by={p['id']:p for p in json.loads((ROOT/'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']}
        self.assertTrue(NAME in by,NAME)
        p=by[NAME]
        self.assertEqual((len(p['inputs']),len(p['outputs'])),(60,0))
        self.assertTrue(p['autoSelect'])
        self.assertEqual(p['inputProtocol'],'launchControlXLTemplate')
        self.assertEqual(p['startup'],[[240,0,32,41,2,17,119,0,247],[240,0,32,41,2,17,121,0,247]])
        self.assertEqual(p['shutdown'],[])
        self.assertNotIn('audioOutput',p)
        self.assertEqual({r['targetDeck'] for r in p['inputs'] if r['action'].startswith('cuePreview')},set('abcd'))
        self.assertEqual(sum(r['kind']=='control' for r in p['inputs']),32)

    def test_xl_primary_schema_and_guide_have_independent_pins(self):
        from launch_control_xl_template import LAUNCH_CONTROL_XL_TEMPLATE_REFERENCES
        ref=LAUNCH_CONTROL_XL_TEMPLATE_REFERENCES[NAME]
        for path,digest in [('TestBuilds/r405/upstream/launch-control-xl-programmer.pdf',ref['sha256']),('TestBuilds/r407/upstream/components-main.js',ref['componentsSHA256'])]:
            p=ROOT/path
            if p.exists():self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(),digest)
