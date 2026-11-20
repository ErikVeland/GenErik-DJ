"""MPD218 preset1 facts retain actual pad modes and knob ranges."""
import hashlib
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class MPD218Tests(unittest.TestCase):
    def test_independent_automatic_native_preset1_contract(self):
        records = json.loads((ROOT / 'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']
        matches = [p for p in records if p['id'] == 'Akai MPD218']; self.assertEqual(len(matches), 1); p = matches[0]
        self.assertEqual((len(p['inputs']), len(p['outputs']), p['autoSelect'], p['inputProtocol']), (66, 0, True, 'mpd218Chroma'))
        self.assertEqual((p['startup'], p['shutdown']), ([], [])); self.assertNotIn('audioOutput', p)
        pads = [r for r in p['inputs'] if r['kind'] == 'note']; self.assertEqual(len(pads), 48)
        self.assertTrue(all(r['channel'] == 9 and 36 <= r['number'] <= 83 for r in pads))
        self.assertEqual({r['targetDeck'] for r in p['inputs']}, {'a', 'b', 'c'})
        self.assertNotIn('MPD226', p['aliases']); self.assertNotIn('MPD232', p['aliases'])

    def test_all_active_wires_and_modes_match_the_own_factory_preset(self):
        from mpd218 import MPD218_REFERENCES, mpd218_profiles
        ref = MPD218_REFERENCES['Akai MPD218']; catalogue = json.loads((ROOT / 'docs/coordination/controller-catalogue.json').read_text())
        entry = next(d for d in catalogue['definitions'] if d['id'] == 'reviewed:mpd218-chroma10-native')
        self.assertEqual(entry['source'], ref)
        for f in ref['files']:
            path = ROOT / f['cachePath']
            if path.exists(): self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), f['sha256'])
        path = ROOT / ref['files'][1]['cachePath']
        if not path.exists(): return
        data = path.read_bytes(); self.assertEqual(len(data), 549)
        self.assertEqual(data[:8], bytes.fromhex('f0 47 00 34 10 04 1d 01')); self.assertEqual(data[8:16], b'chroma10'); self.assertEqual(data[-1], 247)
        wires = set()
        for index in range(48):
            row = data[20 + 8 * index:28 + 8 * index]
            self.assertEqual((row[0], row[3]), (0, 0)); wires.add(('note', row[1] - 1, row[2]))
        for index in range(18):
            row = data[404 + 8 * index:412 + 8 * index]
            self.assertEqual((row[0], row[3], row[4]), (0, 0, 127)); wires.add(('control', row[1] - 1, row[2]))
        self.assertEqual(wires, {(r['kind'], r['channel'], r['number']) for r in mpd218_profiles()[0]['inputs']})
