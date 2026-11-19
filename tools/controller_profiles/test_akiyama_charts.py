"""Retain independent Akiyama table facts without filling chart conflicts."""
import hashlib
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class AkiyamaChartTests(unittest.TestCase):
    def test_three_models_have_independent_manual_chart_controls(self):
        by={p['id']:p for p in json.loads((ROOT/'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']}
        for name,count in [('Akiyama Quattro',98),('Akiyama Quark SC',200),('Akiyama TTWO',125)]:
            self.assertTrue(name in by,name)
            p=by[name]
            self.assertEqual(len(p['inputs']),count)
            self.assertFalse(p['autoSelect'])
            self.assertEqual((p['startup'],p['shutdown'],p['outputs']),([],[],[]))
            self.assertEqual({r['targetDeck'] for r in p['inputs'] if 'targetDeck' in r},set('abcd'))
            self.assertNotIn('audioOutput',p)

    def test_model_specific_primary_manuals_are_pinned(self):
        from akiyama_charts import AKIYAMA_REFERENCES
        self.assertEqual(len(AKIYAMA_REFERENCES),3)
        self.assertEqual(len({r['sha256'] for r in AKIYAMA_REFERENCES.values()}),3)
        for ref in AKIYAMA_REFERENCES.values():
            cached=ROOT/'TestBuilds/r401/upstream'/ref['cacheName']
            if cached.exists():self.assertEqual(hashlib.sha256(cached.read_bytes()).hexdigest(),ref['sha256'])

    def test_disputed_pitch_jog_and_feedback_facts_are_not_guessed(self):
        from akiyama_charts import akiyama_chart_profiles
        by={p['id']:p for p in akiyama_chart_profiles()}
        for p in by.values():
            self.assertFalse(any(r['action'].startswith(('jog','wheelJog')) for r in p['inputs']))
            self.assertTrue(all(0<=r['number']<128 for r in p['inputs']))
            self.assertIn('calibration',' '.join(p['gaps']))
        self.assertEqual([r['number'] for r in by['Akiyama TTWO']['inputs'] if r['action'].startswith('tempo')],[])
        self.assertFalse(any(r['action']=='crossfader' for r in by['Akiyama TTWO']['inputs']))
        self.assertEqual({r['number'] for r in by['Akiyama Quark SC']['inputs'] if r['action'].startswith('tempo')},{56,120})
