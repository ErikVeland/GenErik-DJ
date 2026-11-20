"""DJ-707M facts remain separate from direct iPad transport claims."""
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class DJ707MTests(unittest.TestCase):
    def test_manual_bridge_core_and_unknown_pad_modes(self):
        rows=json.loads((ROOT/'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']
        p=next((p for p in rows if p['id']=='Roland DJ-707M'),None)
        self.assertIsNotNone(p)
        self.assertEqual((p['autoSelect'],len(p['inputs']),p['outputs'],p['startup'],p['shutdown']),(False,107,[],[],[]))
        self.assertNotIn('audioOutput',p)
        self.assertEqual(len(p['inputModes']),4)
        for ch,mode in enumerate(p['inputModes'],4):
            self.assertEqual((mode['channel'],mode['numbers']),(ch,list(range(12))))
            self.assertNotIn('initial',mode)
        pads=[r for r in p['inputs'] if r.get('requiredMode') is not None]
        self.assertEqual(len(pads),32)
        self.assertTrue(all(r['requiredMode']==0 and r['shifted'] is False and 20<=r['number']<=27 for r in pads))
        self.assertFalse(any(r['encoding']=='paired14Bit' or r['action'] in ['tempoA','tempoB','jogA','jogB'] for r in p['inputs']))
        self.assertIn('bridge',p['hardwareMode'])

    def test_independent_source_pin(self):
        from roland_dj707m import DJ707M_REFERENCES
        import hashlib
        for f in DJ707M_REFERENCES['Roland DJ-707M']['files']:
            p=ROOT/f['cachePath']
            if p.exists(): self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(),f['sha256'])
