"""TOUR1 keeps its own primary headphone bus and selector reset contract."""
import hashlib
import json
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
NAME='Pioneer DJM-TOUR1'

class DJMTour1Tests(unittest.TestCase):
    def test_own_manual_mixer_and_source_selectors_do_not_inherit_other_buses(self):
        by={p['id']:p for p in json.loads((ROOT/'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']}
        self.assertTrue(NAME in by,NAME);p=by[NAME]
        self.assertFalse(p['autoSelect']);self.assertEqual(len(p['inputs']),32)
        self.assertEqual((p['outputs'],p['startup'],p['shutdown']),([],[],[]))
        self.assertNotIn('audioOutput',p);self.assertEqual(len(p['bankChanges']),24)
        self.assertEqual({r['number'] for r in p['inputs'] if r['action'].startswith('cueState')},{70,71,72,73})
        self.assertTrue(all(r['kind']=='control' and r['channel']==0 for r in p['inputs']))
        self.assertFalse(any(r['number'] in [114,126,127] for r in p['inputs']))

    def test_independent_manufacturer_pdf_bytes_are_pinned(self):
        from djm_tour1 import TOUR1_REFERENCES
        p=ROOT/'TestBuilds/r412/upstream/djm-tour1-midi.pdf'
        if p.exists():self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(),TOUR1_REFERENCES[NAME]['sha256'])
