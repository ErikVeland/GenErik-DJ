"""Recovered documents retain independent identity, wire and activation limits."""
import hashlib
import json
import unittest
import xml.etree.ElementTree as E
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
NAMES=['Numark NVII','Denon DJ PRIME GO+','American Audio DP2']

class UltraMixerRecoveredTests(unittest.TestCase):
    def test_each_core_keeps_its_own_bounded_identity_and_activation(self):
        by={p['id']:p for p in json.loads((ROOT/'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']}
        for name,count,outputs,automatic in zip(NAMES,[77,45,108],[0,0,18],[False,False,True]):
            self.assertTrue(name in by,name);p=by[name]
            self.assertEqual((len(p['inputs']),len(p['outputs']),p['autoSelect']),(count,outputs,automatic))
            self.assertEqual((p['startup'],p['shutdown']),([],[]));self.assertNotIn('audioOutput',p)
            self.assertFalse(any(r['action'].startswith('jog') or r.get('anyChannel',False) for r in p['inputs']))
        p=by[NAMES[0]];self.assertFalse(any(r['action'].startswith('tempo') for r in p['inputs']))
        p=by[NAMES[1]];self.assertFalse(any(r['action'].startswith(('tempo','monitor','cueMix','master')) for r in p['inputs']))
        p=by[NAMES[2]];self.assertEqual({r['number'] for r in p['inputs'] if r['action'].startswith('high')},{20})
        self.assertFalse(any(r['action'].startswith(('mid','gain')) for r in p['inputs']))

    def test_native_wires_exist_in_each_independent_pinned_definition(self):
        from ultramixer_recovered import RECOVERED_REFERENCES,recovered_profiles
        by={p['id']:p for p in recovered_profiles()}
        for name,ref in RECOVERED_REFERENCES.items():
            path=ROOT/'TestBuilds/r416/upstream'/ref['cacheMember']
            if not path.exists():continue
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(),ref['memberSHA256'])
            root=E.parse(path).getroot();wires=set()
            if root.tag=='midimap':
                for row in root.findall('./midiinputmap/midiinput'):
                    if row.get('command') not in ['144','176']:continue
                    for ch in row.get('channel','').split(','):wires.add(('note' if row.get('command')=='144' else 'control',int(ch),int(row.get('data1'))))
            else:
                for row in root:
                    if row.tag in ['button','slider','encoder']:wires.add(('note' if row.tag=='button' else 'control',int(row.get('channel')),int(row.get('note',row.get('cc')),16)))
            for row in by[name]['inputs']:self.assertIn((row['kind'],row['channel'],row['number']),wires)
