"""JB Systems recipes follow their own manufacturer-distributed Traktor files."""
import hashlib
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class JBKontrolTests(unittest.TestCase):
    def test_independent_manual_core_rejects_sibling_cue_and_feedback_assumptions(self):
        by = {p['id']: p for p in json.loads((ROOT / 'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']}
        for model in [2, 3]:
            name = f'JB Systems DJ KONTROL{model}'; self.assertTrue(name in by, name); p = by[name]
            self.assertEqual((len(p['inputs']), len(p['outputs']), p['autoSelect']), (25, 0, False))
            self.assertEqual((p['startup'], p['shutdown']), ([], [])); self.assertNotIn('audioOutput', p)
            self.assertTrue(all(r['channel'] == 0 for r in p['inputs']))
            self.assertFalse(any(r['action'].startswith(('cuePreview', 'hotcue', 'sync', 'keylock', 'jog', 'wheelJog', 'pitchBend', 'monitor')) for r in p['inputs']))
            self.assertTrue(all(r['inverted'] for r in p['inputs'] if r['action'].startswith('tempo') or r['action'] == 'crossfader'))

    def test_each_active_role_and_direction_exists_in_its_own_primary_tsi(self):
        from jb_kontrol import JB_REFERENCES, jb_kontrol_profiles
        from tsi_facts import inspect_tsi
        commands = {'play': 100, 'load': 3076, 'cue': 119, 'loopIn': 2392, 'loopOut': 2393, 'level': 102, 'gain': 117, 'high': 303, 'mid': 302, 'low': 301, 'tempo': 123, 'crossfader': 5, 'cueMix': 17, 'browse': 3200}
        catalogue = json.loads((ROOT / 'docs/coordination/controller-catalogue.json').read_text())
        by = {d['name']: d for d in catalogue['definitions'] if d['id'].startswith('reviewed:jb-kontrol-')}
        for p in jb_kontrol_profiles():
            ref = JB_REFERENCES[p['id']]; self.assertTrue(p['id'] in by, p['id']); self.assertEqual(by[p['id']]['source'], ref)
            for f in ref['files']:
                path = ROOT / f['cachePath']
                if path.exists(): self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), f['sha256'])
            path = ROOT / ref['files'][1]['cachePath']
            if not path.exists(): continue
            rows = inspect_tsi(path.read_bytes())[0]['mappings']
            for binding in p['inputs']:
                a = binding['action']; action = a[:-1] if a[-1:] in ['A', 'B'] else a
                n = binding['number']; signal = f'Ch01.CC.{n:03}' if binding['kind'] == 'control' else 'Ch01.Note.' + ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'][n % 12] + str(n // 12 - 1)
                matches = [r for r in rows if r['direction'] == 0 and r['signal'] == signal and r['commandID'] == commands[action] and r['target'] == (1 if binding.get('targetDeck') == 'b' else 0)]
                self.assertEqual(len(matches), 1, (p['id'], action, signal))
                self.assertEqual(matches[0]['inverted'], int(binding['inverted']))
                if action == 'browse': self.assertEqual(matches[0]['encoderMode'], 1)
