"""Explicit owner clear wires extend existing negative guards without guessing modes."""
import copy
import hashlib
import json
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
EXPECTED={'Hercules DJControl Compact':8,'Hercules DJControl Inpulse 200':8,'Hercules DJControl Inpulse 300':16,'Hercules DJControl MIX':8,'Hercules DJControl Starlight':8,'Korg KAOSS DJ':6,'Korg KAOSS DJ (Audioless)':6,'MixVibes U-Mix Control 2':12,'MixVibes U-Mix Control Pro 2':8,'Novation Dicer':10,'Reloop Beatmix 2/4 MK2':16,'Stanton DJC.4':16,'Vestax VCI-100MKII':8}


class ReviewedHotcueClearTests(unittest.TestCase):
    def profiles(self):
        return {p['id']:p for p in json.loads((ROOT/'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']}

    def test_one_hundred_thirty_explicit_clears_keep_existing_negative_guards(self):
        rows=self.profiles()
        for name,count in EXPECTED.items():
            p=rows[name];clears=[r for r in p['inputs'] if r['action'].startswith('clearHotcue') and not r.get('releaseOnly')]
            self.assertEqual(len(clears),count,name)
            for c in clears:
                self.assertEqual((c['kind'],c['encoding'],c['inverted']),('note','absolute',False))
                self.assertFalse(any(k in c for k in ['shifted','shiftChannel','releaseOnly','requiredMode','deckBank']))
                activate=c['action'].replace('clearHotcue','hotcue')
                self.assertTrue(any(r['action']==activate and r.get('releaseOnly') and r['channel']==c['channel'] and r['number']==c['number'] and r.get('targetDeck')==c.get('targetDeck') for r in p['inputs']))
            self.assertFalse(any(r['action'].startswith('clearHotcue') for r in p['outputs']))

    def test_every_clear_has_a_hash_pinned_own_model_normal_note_on_row(self):
        from reviewed_hotcue_clears import CLEAR_REFERENCES
        rows=self.profiles()
        self.assertEqual(set(CLEAR_REFERENCES),set(EXPECTED))
        for name,ref in CLEAR_REFERENCES.items():
            path=ROOT/'TestBuilds/r169/upstream'/ref['path']
            if not path.exists():continue
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(),ref['sha256'])
            controls=ET.parse(path).findall('.//control')
            for c in (r for r in rows[name]['inputs'] if r['action'].startswith('clearHotcue') and not r.get('releaseOnly')):
                slot=int(c['action'][11:-1]);group='[Channel'+str('abcd'.index(c['targetDeck'])+1)+']'
                found=[x for x in controls if x.findtext('group')==group and x.findtext('key')==f'hotcue_{slot}_clear' and int(x.findtext('status','0'),0)==0x90+c['channel'] and int(x.findtext('midino','0'),0)==c['number']]
                self.assertTrue(found,(name,c))
                self.assertTrue(any(not {y.tag.lower() for y in (x.find('options') or [])}-{'normal'} for x in found))
                alias=next(r for r in rows[name]['inputs'] if r['action']==c['action'] and r.get('targetDeck')==c['targetDeck'] and r.get('releaseOnly'))
                normal=[x for x in controls if x.findtext('group')==group and x.findtext('key')==f'hotcue_{slot}_activate' and int(x.findtext('status','0'),0)==0x90+alias['channel'] and int(x.findtext('midino','0'),0)==alias['number']]
                self.assertTrue(any(not {y.tag.lower() for y in (x.find('options') or [])}-{'normal'} for x in normal))

    def test_extension_rejects_missing_guard_and_positive_wire_collision(self):
        from reviewed_hotcue_clears import apply_reviewed_hotcue_clears
        rows=self.profiles();base=[{**p,'inputs':[r for r in p['inputs'] if not r['action'].startswith('clearHotcue')]} for p in rows.values()]
        p=next(p for p in base if p['id']=='Novation Dicer');guard=next(r for r in p['inputs'] if r['action']=='hotcue1A' and r.get('releaseOnly'))
        for conflict in [False,True]:
            changed=copy.deepcopy(base);item=next(p for p in changed if p['id']=='Novation Dicer')
            if conflict:item['inputs'].append({k:v for k,v in guard.items() if k not in ['releaseOnly','shifted','shiftChannel']})
            else:item['inputs'].remove(guard)
            with self.assertRaises(ValueError):apply_reviewed_hotcue_clears(changed)

    def test_clear_rearms_from_its_own_activation_negative_wire(self):
        for name in EXPECTED:
            p=self.profiles()[name]
            for clear in [r for r in p['inputs'] if r['action'].startswith('clearHotcue') and not r.get('releaseOnly')]:
                cues=[r for r in p['inputs'] if r['action']==clear['action'].replace('clearHotcue','hotcue') and r.get('targetDeck')==clear.get('targetDeck') and not r.get('releaseOnly') and r.get('shifted')!=True]
                self.assertEqual(len(cues),1)
                cue=cues[0]
                aliases=[r for r in p['inputs'] if r['action']==clear['action'] and r.get('targetDeck')==clear.get('targetDeck') and r.get('releaseOnly') and r['kind']=='note' and r['channel']==cue['channel'] and r['number']==cue['number']]
                self.assertEqual(len(aliases),1,(name,clear))
