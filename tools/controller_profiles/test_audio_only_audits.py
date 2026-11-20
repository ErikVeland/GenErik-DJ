"""An external audio mixer must not become an invented MIDI profile."""
import hashlib
import json
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]


class AudioOnlyAuditTests(unittest.TestCase):
    def test_external_mixers_report_audio_work_without_midi_or_acceptance(self):
        c=json.loads((ROOT/'docs/coordination/controller-catalogue.json').read_text())
        for name in ['Reloop PTB-2','Allen & Heath Xone:23C']:
            m=next(m for m in c['models'] if m['name']==name)
            self.assertEqual(m['role'],'external-audio-mixer')
            self.assertEqual(m['controlProtocol']['kind'],'none')
            self.assertEqual(m['audioRequirements']['usbInputs'],4)
            self.assertEqual(m['audioRequirements']['usbOutputs'],4)
            self.assertEqual(m['audioRequirements']['mixing'],'external')
            self.assertFalse(m['zeroConfig']['automaticControls'] or m['theoreticalSupport']['complete'] or m['releaseReady'])
            self.assertNotIn('profile',m);self.assertNotIn('audioOutputSupport',m)
            self.assertFalse(m['theoreticalSupport']['criteria']['audioRoutingImplemented'])
            self.assertIn('external deck-A/deck-B',m['audioRouting'])
            self.assertTrue(any('No MIDI controller mapping applies' in gap for gap in m['gaps']))
            self.assertFalse(any('Manufacturer protocol work is required' in gap for gap in m['gaps']))
            runtime=json.loads((ROOT/'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())
            self.assertFalse(any(p['id']==m['name'] for p in runtime['profiles']))

    def test_original_manufacturer_manual_pin(self):
        from audio_only_audits import AUDIO_ONLY_AUDITS
        for ref in AUDIO_ONLY_AUDITS.values():
            f=ref['source']['files'][0];p=ROOT/f['cachePath']
            if p.exists():self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(),f['sha256'])
