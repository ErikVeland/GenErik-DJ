"""Mixars QUATTRO uses independent owner input facts without importing its broken map."""
import hashlib
import json
import plistlib
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class MixarsQuattroTests(unittest.TestCase):
    def test_manual_performance_only_contract(self):
        rows = json.loads((ROOT / 'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']
        p = next(p for p in rows if p['id'] == 'Mixars QUATTRO')
        self.assertEqual((len(p['inputs']), p['autoSelect'], p['role']), (109, False, 'accessory'))
        self.assertEqual((p['outputs'], p['startup'], p['shutdown']), ([], [], []))
        self.assertNotIn('audioOutput', p)
        self.assertFalse(any(r['action'].startswith(('cuePreview', 'level', 'gain', 'high', 'mid', 'low', 'crossfader', 'cueState')) for r in p['inputs']))
        self.assertTrue(all(r.get('shifted') is False for r in p['inputs'] if r['action'] != 'shift'))
        self.assertEqual({r['channel']: r['shiftInput'] for r in p['inputs'] if r['action'] == 'shift'}, {0: 0, 1: 1, 2: 0, 3: 1})

    def test_every_wire_and_assignment_matches_unmodified_source_input(self):
        from mixars_quattro import mixars_quattro_profiles
        path = ROOT / 'TestBuilds/r442/upstream/quattro-owner.djayMidiMapping'
        if not path.exists(): return
        with self.assertRaises(ValueError): plistlib.loads(path.read_bytes())
        tree = ET.fromstring(path.read_bytes()); removed = []
        for d in tree.iter('dict'):
            children = list(d)
            for i, child in enumerate(children):
                if child.tag == 'key' and (i + 1 == len(children) or children[i + 1].tag == 'key'):
                    self.assertEqual(child.text, 'output'); removed.append(child.text); d.remove(child)
        self.assertEqual(removed, ['output'] * 4)
        source = plistlib.loads(ET.tostring(tree))
        self.assertEqual((len(source['controls']), source['endpointName'], source['editor']), (229, 'Mixars Quattro', 'djay Pro AI-3.1.9'))
        facts = [r for r in source['controls'] if r.get('modifier') is not True]
        wires = {(r['midiChannel'], r['midiData'], r['midiMessageType']) for r in facts}
        all_wires = {(r['midiChannel'], r['midiData'], r['midiMessageType']) for r in source['controls']}
        for r in mixars_quattro_profiles()[0]['inputs']:
            wire = (r['channel'], r['number'], 1 if r['kind'] == 'note' else 3)
            self.assertIn(wire, all_wires if r.get('releaseOnly') else wires)
        for deck, ch in zip('abcd', range(4, 8)):
            for slot, n in enumerate([96, 100, 97, 101, 98, 102, 99, 103], 1):
                row = next(r for r in facts if r['keyPath'] == f'turntable{ord(deck) - 96}.cueOrJumpIfAlreadySet{slot}')
                self.assertEqual((row['midiChannel'], row['midiData']), (ch, n))

    def test_source_pins_and_definition(self):
        from mixars_quattro import MIXARS_QUATTRO_REFERENCES
        ref = MIXARS_QUATTRO_REFERENCES['Mixars QUATTRO']
        c = json.loads((ROOT / 'docs/coordination/controller-catalogue.json').read_text())
        self.assertEqual(next(d for d in c['definitions'] if d['id'] == 'reviewed:mixars-quattro-owner')['source'], ref)
        for f in ref['files']:
            p = ROOT / f['cachePath']
            if p.exists(): self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(), f['sha256'])
