"""Separate NDX800/900 public sources qualify a bounded normal player subset."""
import hashlib
import json
import unittest
import xml.etree.ElementTree as E
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class NDXLegacyPlayerTests(unittest.TestCase):
    def test_separate_automatic_players_keep_only_unambiguous_normal_controls(self):
        profiles = json.loads((ROOT / 'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']
        by = {p['id']: p for p in profiles}
        for name in ['Numark NDX800', 'Numark NDX900']:
            self.assertTrue(name in by, name); p = by[name]
            self.assertEqual((len(p['inputs']), len(p['outputs']), p['autoSelect'], p['role']), (10, 0, True, 'player'))
            self.assertEqual((p['startup'], p['shutdown']), ([], []))
            self.assertTrue(all(r.get('anyChannel') and r['channel'] == 0 for r in p['inputs']))
            self.assertEqual(next(r['number'] for r in p['inputs'] if r['action'] == 'cuePreviewA'), 56)
            self.assertFalse(any(r['action'].startswith(('hotcue', 'jog', 'sync', 'keylock', 'level', 'pause')) for r in p['inputs']))
            self.assertNotIn('audioOutput', p)
            self.assertEqual(len(p.get('bankChanges', [])), 0 if name.endswith('800') else 1)

    def test_native_wires_and_mode_resets_exist_in_each_own_definition(self):
        from ndx_legacy_players import ndx_legacy_profiles, NDX_LEGACY_REFERENCES
        for p in ndx_legacy_profiles():
            path = ROOT / NDX_LEGACY_REFERENCES[p['id']]['files'][0]['cachePath']
            if not path.exists(): continue
            wires = set()
            for row in E.parse(path).getroot():
                r = {c.tag: c.text for c in row}
                if r.get('control_group') != 'INPUT': continue
                status = int(r['midichan']) & 240; number = int(r['control_midino'])
                if status == 224: wires.add(('pitch', 0))
                elif status in [144, 176] and 0 < number < 128:
                    wires.add(('note' if status == 144 else 'control', number))
            for row in p['inputs']: self.assertIn((row['kind'], row['number']), wires)
            for row in p.get('bankChanges', []): self.assertIn(('note', row['number']), wires)

    def test_each_definition_has_its_own_hashed_wire_and_manufacturer_sources(self):
        from ndx_legacy_players import NDX_LEGACY_REFERENCES
        catalogue = json.loads((ROOT / 'docs/coordination/controller-catalogue.json').read_text())
        by = {d['name']: d for d in catalogue['definitions'] if d['id'].startswith('reviewed:ndx-legacy-')}
        for name, ref in NDX_LEGACY_REFERENCES.items():
            self.assertTrue(name in by, name); self.assertEqual(by[name]['source'], ref)
            for source in ref['files']:
                path = ROOT / source['cachePath']
                if path.exists(): self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), source['sha256'])
