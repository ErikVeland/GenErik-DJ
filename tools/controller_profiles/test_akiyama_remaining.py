"""Keep independent Akiyama source subsets manual and disputed controls inactive."""
import json
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
NAMES=['Akiyama Pulsar','Akiyama Tempus','Akiyama Syncron']

class AkiyamaRemainingTests(unittest.TestCase):
    def test_manual_subsets_do_not_advertise_automatic_setup(self):
        by={p['id']:p for p in json.loads((ROOT/'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']}
        for name,count in zip(NAMES,[45,45,11]):
            self.assertTrue(name in by,name)
            p=by[name]
            self.assertFalse(p['autoSelect'])
            self.assertEqual(len(p['inputs']),count)
            self.assertEqual(p['outputs'],[])
            self.assertEqual(p['startup'],[])
            self.assertEqual(p['shutdown'],[])
            self.assertNotIn('audioOutput',p)
            self.assertTrue(all(r['number']<128 for r in p['inputs']))
        self.assertTrue(all(r['kind']=='control' for r in by[NAMES[-1]]['inputs']))
        self.assertFalse(any(r['action'].startswith(('jog','tempo')) for name in NAMES for r in by[name]['inputs']))

    def test_independent_public_factory_files_and_common_syncron_facts_are_pinned(self):
        import hashlib
        from akiyama_remaining import AKIYAMA_REMAINING_REFERENCES
        for name,model in zip(NAMES,['PULSAR','TEMPUS','SYNCRON']):
            ref=AKIYAMA_REMAINING_REFERENCES[name]
            p=ROOT/'TestBuilds/r388/upstream/documents/Devices'/('AKIYAMA '+model+'.xml')
            if p.exists():self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(),ref['members'][0]['sha256'])
        self.assertEqual(len(AKIYAMA_REMAINING_REFERENCES[NAMES[-1]]['disputedInputs']),3)
