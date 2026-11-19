"""Check independently transcribed dock-controller MIDI facts."""
import hashlib
import json
import plistlib
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class LegacyDjayDockTests(unittest.TestCase):
    def test_dock_profiles_remain_manual_without_private_transport_or_audio_claims(self):
        runtime = json.loads((ROOT / 'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())
        by = {p['id']: p for p in runtime['profiles']}
        catalogue = json.loads((ROOT / 'docs/coordination/controller-catalogue.json').read_text())
        models = {m['name']: m for m in catalogue['models']}
        for name in ['Ion iDJ2GO', 'Philips M1X-DJ']:
            self.assertTrue(name in by, 'Add independent dock-controller MIDI facts')
            p = by[name]
            self.assertEqual(len(p['inputs']), 21)
            self.assertFalse(p['autoSelect'] or p['outputs'] or p['startup'] or p['shutdown'])
            self.assertNotIn('audioOutput', p)
            self.assertFalse(any(r['action'].startswith(('jog', 'wheelJog', 'browse')) for r in p['inputs']))
            self.assertIn('exposed MIDI', models[name]['connection'])
            self.assertFalse(models[name]['theoreticalSupport']['complete'])
        self.assertEqual([(r['action'], r['number']) for r in by['Ion iDJ2GO']['inputs'] if r['action'].startswith('cuePreview')], [('cuePreviewA', 51), ('cuePreviewB', 60)])
        philips = by['Philips M1X-DJ']['inputs']
        self.assertEqual([(r['action'], r['number']) for r in philips if r['action'].startswith(('cueSet', 'cueGoto'))], [('cueSetA', 3), ('cueGotoA', 2), ('cueSetB', 3), ('cueGotoB', 2)])
        self.assertFalse(any(r['inverted'] for r in philips))

    def test_native_wires_are_present_in_the_individual_pinned_factory_documents(self):
        from legacy_djay_docks import DOCK_REFERENCES
        runtime = json.loads((ROOT / 'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())
        by = {p['id']: p for p in runtime['profiles']}
        base = ROOT / 'TestBuilds/r390/upstream/djay-documents'
        for name, ref in DOCK_REFERENCES.items():
            self.assertTrue(name in by)
            member = ref['members'][0]
            path = base / Path(member['path']).name
            if not path.exists():
                continue
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), member['sha256'])
            source = plistlib.loads(path.read_bytes())
            wires = {('note' if c['midiMessageType'] == 1 else 'control', c['midiChannel'], c['midiData']) for c in source['controls'] if c['midiMessageType'] in {1, 3}}
            self.assertTrue(all((r['kind'], r['channel'], r['number']) in wires for r in by[name]['inputs']))
            for row in by[name]['inputs']:
                raw = next(c for c in source['controls'] if ('note' if c['midiMessageType'] == 1 else 'control', c['midiChannel'], c['midiData']) == (row['kind'], row['channel'], row['number']))
                self.assertEqual(row['inverted'], raw.get('flipped', False))
