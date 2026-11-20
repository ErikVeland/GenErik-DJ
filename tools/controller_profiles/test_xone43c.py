"""Xone:43C keeps its own fader and Cue-state bytes."""
import hashlib
import json
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]


class Xone43CTests(unittest.TestCase):
    def test_default_channel_manual_faders_and_direct_cue_states(self):
        rows=json.loads((ROOT/'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']
        p=next((p for p in rows if p['id']=='Allen & Heath XONE 43C'),None);self.assertIsNotNone(p)
        self.assertFalse(p['autoSelect']);self.assertEqual(len(p['inputs']),8)
        self.assertEqual((p['outputs'],p['startup'],p['shutdown']),([],[],[]));self.assertNotIn('audioOutput',p)
        for ch,deck in enumerate('abcd'):
            own=[r for r in p['inputs'] if r.get('targetDeck')==deck]
            self.assertEqual({(r['action'],r['kind'],r['number']) for r in own},{('level'+('A' if ch%2==0 else 'B'),'control',ch),('cueState'+('A' if ch%2==0 else 'B'),'note',[77,57,37,17][ch])})
        self.assertTrue(all(r['channel']==15 and not r.get('anyChannel') and not r.get('inverted') for r in p['inputs']))
        self.assertFalse(p.get('bankChanges'))
        c=json.loads((ROOT/'docs/coordination/controller-catalogue.json').read_text());m=next(m for m in c['models'] if m['name']==p['id'])
        self.assertEqual(m['implementation'],'partial-midi-profile');self.assertNotIn('controlProtocol',m)
        self.assertFalse(m['zeroConfig']['automaticControls'] or m['theoreticalSupport']['complete'])

    def test_original_manufacturer_source_pin(self):
        from xone43c import XONE43C_REFERENCES
        ref=XONE43C_REFERENCES['Allen & Heath XONE 43C'];p=ROOT/ref['files'][0]['cachePath']
        if p.exists():self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(),ref['sha256'])
