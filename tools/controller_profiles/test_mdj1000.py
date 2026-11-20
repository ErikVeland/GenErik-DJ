"""Original MDJ-1000 owner evidence does not establish sibling or V2 compatibility."""
import hashlib
import json
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]


class MDJ1000Tests(unittest.TestCase):
    def profile(self):
        p=next((p for p in json.loads((ROOT/'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles'] if p['id']=='Gemini MDJ-1000'),None)
        self.assertIsNotNone(p);return p

    def test_manual_core_requires_own_channel_and_separate_audio(self):
        p=self.profile();self.assertEqual((p['autoSelect'],p['role'],len(p['inputs'])),(False,'player',58))
        self.assertTrue(all(r['channel']==0 and not r.get('anyChannel') for r in p['inputs']))
        self.assertEqual((p['outputs'],p['startup'],p['shutdown']),([],[],[]));self.assertNotIn('audioOutput',p)
        self.assertIn('MDJ-1000V2',p['excludedAliases']);self.assertIn('MDJ-900',p['excludedAliases'])
        c=json.loads((ROOT/'docs/coordination/controller-catalogue.json').read_text());m=next(m for m in c['models'] if m['name']=='Gemini MDJ-1000')
        self.assertEqual((m['implementation'],m['inputBindingCount']),('partial-midi-profile',58))
        self.assertFalse(m['theoreticalSupport']['complete'])

    def test_filter_tempo_and_fractional_loops_remain_distinct_from_motion(self):
        p=self.profile();active=[r for r in p['inputs'] if not r.get('releaseOnly')]
        self.assertEqual(len(active),32)
        self.assertFalse(any('jog' in r['action'].lower() or r['action']=='shift' for r in p['inputs']))
        self.assertEqual([(r['action'],r['number'],r['inverted']) for r in active if r['kind']=='control'],[('tempoA',1,True),('filterKnobA',4,False)])
        loops=[r for r in active if r['action']=='fixedLoopA']
        self.assertEqual([(r['number'],r['argument']) for r in loops],[(34,2),(35,4),(36,8),(37,16),(30,0.125),(31,0.25),(32,0.5),(33,1)])
        for c in [r for r in active if r['action'].startswith('clearHotcue')]:
            self.assertTrue(any(r.get('releaseOnly') and r['action']==c['action'].replace('clearHotcue','hotcue') and r['number']==c['number'] for r in p['inputs']))
            self.assertTrue(any(r.get('releaseOnly') and r['action']==c['action'] and r['number']==c['number']-4 for r in p['inputs']))
        self.assertTrue(all(not any(k in r for k in ['shifted','shiftChannel','requiredMode','deckBank']) for r in p['inputs']))

    def test_owner_table_hash_limit_is_explicit_and_factory_manual_is_pinned(self):
        from mdj1000 import MDJ1000_REFERENCES
        ref=MDJ1000_REFERENCES['Gemini MDJ-1000']
        self.assertIsNone(ref['sha256']);self.assertIn('not downloaded',ref['review'])
        self.assertIn('133340',ref['url']);self.assertIn('2017',ref['review'])
        manual=ref['relatedSources'][0];path=ROOT/manual['cachePath']
        if path.exists():self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(),manual['sha256'])
