"""Own G4V owner chart qualifies a fixed four-strip manual mixer subset."""
import hashlib
import json
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]


class G4VMixerTests(unittest.TestCase):
    def test_manual_mixer_preserves_all_twenty_four_independent_addresses(self):
        rows=json.loads((ROOT/'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']
        p=next((p for p in rows if p['id']=='Gemini G4V'),None);self.assertIsNotNone(p)
        self.assertFalse(p['autoSelect']);self.assertEqual(p['role'],'accessory');self.assertEqual(len(p['inputs']),24)
        self.assertEqual((p['outputs'],p['startup'],p['shutdown']),([],[],[]));self.assertNotIn('audioOutput',p)
        expected={}
        for index,deck in enumerate('abcd'):
            for action,base in [('gain',1),('high',9),('mid',5),('low',13),('filterKnob',17),('level',21)]:
                expected[(deck,action+('A' if deck in 'ac' else 'B'))]=base+index
        self.assertEqual({(r['targetDeck'],r['action']):r['number'] for r in p['inputs']},expected)
        self.assertEqual({r['number'] for r in p['inputs']},set(range(1,25)))
        self.assertTrue(all(r['channel']==3 and r['kind']=='control' and r['encoding']=='absolute' and not r['inverted'] and not r.get('anyChannel') and 'lowNumber' not in r for r in p['inputs']))
        self.assertNotIn('G2V',p['aliases']);self.assertNotIn('G2V Audio',p['aliases']);self.assertFalse(p.get('bankChanges') or p.get('inputModes'))
        c=json.loads((ROOT/'docs/coordination/controller-catalogue.json').read_text());m=next(m for m in c['models'] if m['name']=='Gemini G4V')
        self.assertEqual(m['implementation'],'partial-midi-profile');self.assertFalse(m['zeroConfig']['automaticControls'] or m['theoreticalSupport']['complete'])

    def test_owner_chart_and_original_mapping_remain_hash_locked(self):
        from g4v_mixer import G4V_MIXER_REFERENCES
        for f in G4V_MIXER_REFERENCES['Gemini G4V']['files']:
            p=ROOT/f['cachePath']
            if p.exists():self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(),f['sha256'])
