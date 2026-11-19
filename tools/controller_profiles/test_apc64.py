"""APC64 follows its own primary integration channels and mode contract."""
import hashlib
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class APC64Tests(unittest.TestCase):
    def test_independent_session_contract(self):
        rows = json.loads((ROOT / 'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']
        p = next(p for p in rows if p['id'] == 'Akai APC64')
        self.assertEqual((len(p['inputs']), len(p['outputs']), p['autoSelect'], p['inputProtocol']), (73, 52, True, 'apc64'))
        self.assertEqual({r['number'] for r in p['inputs'] if r['kind'] == 'note' and r['channel'] == 6}, set(range(64)))
        self.assertEqual({(r['channel'], r['number']) for r in p['inputs'] if r['kind'] == 'pitch'}, {(ch, 0) for ch in range(8)})
        self.assertTrue(all(r['channel'] == 6 and r['onValue'] in [5, 13, 21] and r['offValue'] == 0 for r in p['outputs']))
        self.assertEqual(p['startup'][-1], [240, 126, 127, 6, 1, 247])
        self.assertEqual(p['startupAbort'], [[240, 71, 0, 83, 28, 0, 1, 0, 247]])
        self.assertNotIn('audioOutput', p)

    def test_own_primary_integration_pins(self):
        from apc64 import APC64_REFERENCES
        ref = APC64_REFERENCES['Akai APC64']
        catalogue = json.loads((ROOT / 'docs/coordination/controller-catalogue.json').read_text())
        self.assertEqual(next(d for d in catalogue['definitions'] if d['id'] == 'reviewed:apc64-session-native')['source'], ref)
        for f in ref['files']:
            p = ROOT / f['cachePath']
            if p.exists(): self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(), f['sha256'])
