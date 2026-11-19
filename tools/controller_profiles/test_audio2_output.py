"""Audio output qualification must not invent a MIDI or DVS controller."""
import hashlib
import json
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]


class Audio2OutputTests(unittest.TestCase):
    def test_documented_mk2_output_subset_keeps_control_gaps_open(self):
        c=json.loads((ROOT/'docs/coordination/controller-catalogue.json').read_text())
        m=next(m for m in c['models'] if m['name']=='Native Instruments TRAKTOR AUDIO 2')
        self.assertEqual(m['role'],'audio-output-interface')
        self.assertEqual(m['audioOutputSupport']['recognisedName'],'Traktor Audio 2 MK2')
        self.assertTrue(m['audioRouting'].startswith('Automatic'))
        self.assertTrue(m['theoreticalSupport']['criteria']['audioRoutingImplemented'])
        self.assertFalse(m['zeroConfig']['automaticControls'])
        self.assertFalse(m['theoreticalSupport']['complete'])
        self.assertNotIn('profile',m)
        r=json.loads((ROOT/'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())
        self.assertFalse(any(p['id']==m['name'] for p in r['profiles']))
        self.assertTrue(any('encoders' in gap for gap in m['gaps']))

    def test_own_manufacturer_source_pin(self):
        from audio2_output import AUDIO2_OUTPUT
        f=AUDIO2_OUTPUT['source']['files'][0];p=ROOT/f['cachePath']
        if p.exists():self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(),f['sha256'])
