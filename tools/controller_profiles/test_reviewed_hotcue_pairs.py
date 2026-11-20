"""Own-model Hot Cue pairs require exact activation proof and bounded negative guards."""
import copy
import hashlib
import json
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
EXPECTED={'Pioneer DDJ-SB3':32,'Reloop Terminal Mix 2/4':32,'Hercules DJControl Jogvision':16}


class ReviewedHotcuePairTests(unittest.TestCase):
    def profiles(self):
        return {p['id']:p for p in json.loads((ROOT/'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']}

    def test_eighty_explicit_clears_have_both_negative_aliases(self):
        for name,count in EXPECTED.items():
            p=self.profiles()[name];clears=[r for r in p['inputs'] if r['action'].startswith('clearHotcue') and not r.get('releaseOnly')]
            self.assertEqual(len(clears),count,name)
            for c in clears:
                act=c['action'].replace('clearHotcue','hotcue')
                cues=[r for r in p['inputs'] if r['action']==act and r.get('targetDeck')==c['targetDeck'] and not r.get('releaseOnly')]
                self.assertEqual(len(cues),1)
                cue=cues[0]
                for action,wire in [(act,c),(c['action'],cue)]:
                    guards=[r for r in p['inputs'] if r['action']==action and r.get('targetDeck')==c['targetDeck'] and r.get('releaseOnly') and r['kind']==wire['kind'] and r['channel']==wire['channel'] and r['number']==wire['number']]
                    self.assertEqual(len(guards),1)
                    self.assertFalse(any(k in guards[0] for k in ['shifted','shiftChannel','requiredMode','deckBank']))
                self.assertFalse(any(k in c for k in ['shifted','shiftChannel','requiredMode','deckBank']))
                self.assertEqual((c['kind'],c['encoding'],c['inverted']),('note','absolute',False))
            self.assertFalse(any(r['action'].startswith('clearHotcue') for r in p['outputs']))

    def test_each_pair_matches_hash_pinned_own_model_normal_rows(self):
        from reviewed_hotcue_pairs import PAIR_REFERENCES,PAIRED_CLEAR_INPUTS
        for name,ref in PAIR_REFERENCES.items():
            path=ROOT/'TestBuilds/r169/upstream'/ref['path']
            if not path.exists():continue
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(),ref['sha256'])
            controls=ET.parse(path).findall('.//control')
            for cc,cn,ac,an,slot,deck in PAIRED_CLEAR_INPUTS[name]:
                group='[Channel'+str('abcd'.index(deck)+1)+']'
                for operation,ch,num in [('activate',ac,an),('clear',cc,cn)]:
                    found=[x for x in controls if x.findtext('group')==group and x.findtext('key')==f'hotcue_{slot}_{operation}' and int(x.findtext('status','0'),0)==0x90+ch and int(x.findtext('midino','0'),0)==num]
                    self.assertTrue(found,(name,slot,deck,operation))
                    self.assertTrue(any(not {y.tag.lower() for y in (x.find('options') or [])}-{'normal'} for x in found))

    def test_pair_extension_rejects_collision_or_missing_activation_proof(self):
        from reviewed_hotcue_pairs import apply_reviewed_hotcue_pairs,PAIRED_CLEAR_INPUTS
        rows=self.profiles();base=[]
        for p in rows.values():
            p=copy.deepcopy(p)
            if p['id'] in EXPECTED:p['inputs']=p['inputs'][:-3*EXPECTED[p['id']]]
            base.append(p)
        cc,cn,ac,an,slot,deck=PAIRED_CLEAR_INPUTS['Pioneer DDJ-SB3'][0]
        for conflict in [False,True]:
            changed=copy.deepcopy(base);p=next(p for p in changed if p['id']=='Pioneer DDJ-SB3')
            cue=next(r for r in p['inputs'] if r['action']=='hotcue1A' and r.get('targetDeck')==deck and not r.get('releaseOnly'))
            if conflict:p['inputs'].append({**cue,'channel':cc,'number':cn})
            else:cue['number']=127
            with self.assertRaises(ValueError):apply_reviewed_hotcue_pairs(changed)
