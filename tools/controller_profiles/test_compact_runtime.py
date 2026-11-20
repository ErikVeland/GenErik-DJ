"""Bundled compact records must retain every reviewed protocol value."""
import json
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]


class CompactRuntimeTests(unittest.TestCase):
    def test_generated_bundle_round_trips_every_reviewed_recipe(self):
        from compact_runtime import INPUT_KEYS, compact_runtime
        full=json.loads((ROOT/'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())
        path=ROOT/'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.compact.json'
        self.assertTrue(path.exists())
        bundled=json.loads(path.read_text())
        self.assertEqual(bundled,compact_runtime(full))
        inverse={v:k for k,v in INPUT_KEYS.items()}
        expanded=[]
        for p in bundled['profiles']:
            p=dict(p);rows=[]
            for r in p['inputs']:
                r={inverse.get(k,k):v for k,v in r.items()}
                for key,value in [('kind','note'),('encoding','absolute'),('inverted',False)]:r.setdefault(key,value)
                rows.append(r)
            p['inputs']=rows;expanded.append(p)
        reviewed=[{k:v for k,v in p.items() if k not in {'definition','gaps','hardwareMode'}} for p in full['profiles']]
        self.assertEqual(expanded,reviewed)
        self.assertLess(path.stat().st_size,3*1024*1024)

    def test_unknown_input_fields_cannot_be_dropped(self):
        from compact_runtime import compact_runtime
        with self.assertRaises(ValueError):compact_runtime({'schemaVersion':1,'profiles':[{'inputs':[{'futureControl':True}]}]})
