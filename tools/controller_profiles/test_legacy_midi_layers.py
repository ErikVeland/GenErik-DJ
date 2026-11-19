"""Separate manufacturer MIDI layers retain their own targets and wire addresses."""
import hashlib
import json
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
NAMES=['Denon DJ X1600','Synq PCM-1']

class LegacyMIDILayerTests(unittest.TestCase):
    def test_manual_subsets_do_not_inherit_sibling_or_hardware_audio_contracts(self):
        by={p['id']:p for p in json.loads((ROOT/'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']}
        for name,count in zip(NAMES,[54,50]):
            self.assertTrue(name in by,name);p=by[name]
            self.assertFalse(p['autoSelect']);self.assertEqual(len(p['inputs']),count)
            self.assertEqual((p['outputs'],p['startup'],p['shutdown']),([],[],[]));self.assertNotIn('audioOutput',p)
            self.assertFalse(any(r['action'].startswith('jog') for r in p['inputs']))
        p=by[NAMES[0]];self.assertTrue(all(r['channel']==0 for r in p['inputs']))
        self.assertEqual({r['targetDeck'] for r in p['inputs'] if r.get('targetDeck')},set('abcd'))
        self.assertEqual(len(p['bankChanges']),14)
        p=by[NAMES[1]];self.assertEqual({r['number'] for r in p['inputs'] if r['action'].startswith('high')},{19})
        self.assertFalse(any(r['action'] in ['crossfader','master'] or r['action'].startswith('gain') for r in p['inputs']))

    def test_each_primary_definition_is_independently_pinned(self):
        from legacy_midi_layers import LEGACY_LAYER_REFERENCES
        for ref in LEGACY_LAYER_REFERENCES.values():
            p=ROOT/'TestBuilds/r418/upstream'/ref['cacheName']
            if p.exists():self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(),ref['sha256'])

    def test_pcm1_wires_match_only_its_own_used_factory_bindings(self):
        from tsi_facts import inspect_tsi
        from legacy_midi_layers import legacy_layer_profiles
        path=ROOT/'TestBuilds/r418/upstream/Traktor Settings for PCM1.tsi'
        if not path.exists():self.skipTest('Ignored primary factory source is unavailable')
        rows=inspect_tsi(path.read_bytes())[0]['mappings'];self.assertEqual(len(rows),156)
        inputs=[r for r in rows if r['direction']==0];self.assertEqual(len(inputs),94)
        wires={r['signal'] for r in inputs};p=next(p for p in legacy_layer_profiles() if p['id']==NAMES[1])
        notes=['C','C#','D','D#','E','F','F#','G','G#','A','A#','B']
        for r in p['inputs']:
            n=r['number'];suffix=f'CC.{n:03}' if r['kind']=='control' else f'Note.{notes[n%12]}{n//12-1}'
            self.assertIn(f"Ch{r['channel']+1:02}.{suffix}",wires)
