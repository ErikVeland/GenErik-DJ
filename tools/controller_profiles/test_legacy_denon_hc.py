"""Independent legacy Denon tables retain their own channels, mode and LED triggers."""
import hashlib
import json
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
NAMES=['Denon DJ HC1000S','Denon DJ HC4500']

class LegacyDenonHCTests(unittest.TestCase):
    def test_native_cores_bound_configurable_channels_without_sibling_hid_or_audio(self):
        by={p['id']:p for p in json.loads((ROOT/'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']}
        for name,count,outputs,channels in [(NAMES[0],244,48,set(range(4))),(NAMES[1],96,42,set(range(6)))]:
            self.assertTrue(name in by,name);p=by[name]
            self.assertTrue(p['autoSelect']);self.assertEqual((len(p['inputs']),len(p['outputs'])),(count,outputs))
            self.assertEqual((p['startup'],p['shutdown']),([],[]));self.assertNotIn('audioOutput',p)
            self.assertEqual({r['channel'] for r in p['inputs']},channels)
            self.assertEqual({r['targetDeck'] for r in p['inputs'] if r.get('targetDeck')},set('ab'))
            self.assertFalse(any(r['action'].startswith('jog') or r.get('anyChannel',False) for r in p['inputs']))
            self.assertTrue(all(r['number']==74 and r['offNumber']==75 and r['onValue']==r['offValue'] for r in p['outputs']))

    def test_each_primary_document_is_independently_pinned(self):
        from legacy_denon_hc import LEGACY_HC_REFERENCES
        for ref in LEGACY_HC_REFERENCES.values():
            for r in [ref]+ref.get('relatedSources',[]):
                if 'cacheName' not in r:continue
                p=ROOT/'TestBuilds/r415/upstream'/r['cacheName']
                if p.exists():self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(),r['sha256'])
