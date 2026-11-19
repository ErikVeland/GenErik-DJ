"""Independent legacy cores preserve manufacturer corrections and mode limits."""
import hashlib
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class LegacyPCDJCoresTests(unittest.TestCase):
    def test_bounded_manual_cores_keep_independent_identity(self):
        profiles = json.loads((ROOT / 'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']
        by = {p['id']: p for p in profiles}
        for name, count, lamps in [('Numark 4TRAK', 142, 32), ('M-Audio Xponent', 96, 14)]:
            self.assertTrue(name in by, name)
            p = by[name]
            self.assertEqual((len(p['inputs']), len(p['outputs'])), (count, lamps))
            self.assertFalse(p['autoSelect'])
            self.assertEqual((p['startup'], p['shutdown']), ([], []))
            self.assertNotIn('audioOutput', p)
        x = by['M-Audio Xponent']
        self.assertEqual({r['number'] for r in x['inputs'] if r['action'] == 'shift'}, {44})
        self.assertFalse(any(r['kind'] == 'note' and r['number'] in [18, 19] for r in x['inputs']))
        jogs = [r for r in x['inputs'] if r['action'].startswith('jog') and r['kind'] == 'control']
        self.assertEqual(len(jogs), 2)
        self.assertTrue(all(r['argument'] == 300 and r['requiresTouch'] for r in jogs))

    def test_pinned_sources_and_catalogue_provenance(self):
        from legacy_pcdj_cores import LEGACY_PCDJ_REFERENCES
        catalogue = json.loads((ROOT / 'docs/coordination/controller-catalogue.json').read_text())
        definitions = {d['name']: d for d in catalogue['definitions'] if d['id'].startswith('reviewed:legacy-pcdj-')}
        for name, ref in LEGACY_PCDJ_REFERENCES.items():
            self.assertTrue(name in definitions, name)
            self.assertEqual(definitions[name]['source'], ref)
            for source in ref['files']:
                path = ROOT / source['cachePath']
                if path.exists():
                    self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), source['sha256'])

    def test_recent_native_cores_retain_their_detailed_source_records(self):
        from ultramixer_recovered import RECOVERED_REFERENCES
        from denon_legacy_players import DENON_PLAYER_REFERENCES
        from legacy_midi_layers import LEGACY_LAYER_REFERENCES
        from legacy_rane import LEGACY_RANE_REFERENCES
        from cmd_modular import CMD_REFERENCES
        refs = RECOVERED_REFERENCES | DENON_PLAYER_REFERENCES | LEGACY_LAYER_REFERENCES | LEGACY_RANE_REFERENCES | CMD_REFERENCES
        catalogue = json.loads((ROOT / 'docs/coordination/controller-catalogue.json').read_text())
        by = {d['name']: d for d in catalogue['definitions'] if d['name'] in refs}
        for name, ref in refs.items():
            self.assertTrue(name in by, name)
            self.assertEqual(by[name]['source'], ref)
