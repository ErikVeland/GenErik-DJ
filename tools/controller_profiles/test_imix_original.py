"""Original i-Mix normal controls use intact own-model publisher data."""
import hashlib
import json
import unittest
import xml.etree.ElementTree as E
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]


class OriginalIMixTests(unittest.TestCase):
    def test_manual_two_deck_core_has_no_inferred_modes_or_feedback(self):
        rows=json.loads((ROOT/'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']
        p=next((p for p in rows if p['id']=='DJ-Tech I-MIX'),None);self.assertIsNotNone(p)
        self.assertFalse(p['autoSelect']);self.assertEqual(len(p['inputs']),31)
        self.assertEqual((p['outputs'],p['startup'],p['shutdown']),([],[],[]));self.assertNotIn('audioOutput',p)
        self.assertTrue(all(r['channel']==0 and not r.get('anyChannel') for r in p['inputs']))
        self.assertFalse(p.get('bankChanges'))
        self.assertFalse(any(r['action'].startswith(('sync','keylock','tempo','jog','hotcue')) for r in p['inputs']))
        self.assertEqual({r['number'] for r in p['inputs'] if r['action']=='crossfader'},{65})
        self.assertEqual({r['number'] for r in p['inputs'] if r.get('pulse')},{80,81,82,83})

    def test_intact_prefix_qualifies_every_active_wire_without_repairing_source(self):
        source=ROOT/'TestBuilds/r465/upstream/djdecks-data/devices/djtech_imix.xml'
        if not source.exists():self.skipTest('Public upstream cache is optional')
        s=source.read_text();prefix,sep,_=s.partition('<tabs>');self.assertTrue(sep)
        r=E.fromstring(prefix+'</device>')
        self.assertEqual(r.findtext('descriptor/model'),'i-Mix')
        self.assertEqual(r.findtext('descriptor/input_endpoint_name'),'DJ-Tech i-Mix')
        self.assertEqual(r.findtext('name'),'DJ-Tech Kontrol One')
        rows=json.loads((ROOT/'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']
        p=next(p for p in rows if p['id']=='DJ-Tech I-MIX')
        expected=[]
        roles={'Pause':'play','Cue':'cuePreview','Loop_SetIn':'loopIn','Loop_SetOut':'loopOut','Loop_Reloop':'reloop','PitchBend_Down':'pitchBendDown','PitchBend_Up':'pitchBendUp','Volume_Cue':'cue'}
        for x in r:
            action=roles.get(x.findtext('VALUE'))
            if action:
                for suffix,deck,wire in [('A','a','BYTES'),('B','b','BYTES2')]:
                    down=x.findtext(wire+'_DOWN').split();up=x.findtext(wire+'_UP').split()
                    self.assertEqual((down[0],down[2],up[0],up[2]),('90','7F','90','00'))
                    expected.append((action+suffix,'note',0,int(down[1],16),deck,False))
            if x.findtext('TYPE')=='Slider':
                role={'eq_low':'low','eq_mid':'mid','eq_high':'high','amp_set':'gain'}.get(x.findtext('VALUESPECIFIER'))
                if x.findtext('VALUE')=='Volume_Player':role='level'
                if role:
                    for suffix,deck,wire in [('A','a','BYTES'),('B','b','BYTES2')]:
                        b=x.findtext(wire).split();self.assertEqual((b[0],b[2]),('B0','VV'))
                        expected.append((role+suffix,'control',0,int(b[1],16),deck,False))
                elif x.findtext('VALUE')=='Crossfader':expected.append(('crossfader','control',0,int(x.findtext('BYTES').split()[1],16),None,False))
            scroll={'pl_active_scrolldown':'browseNext','pl_active_scrollup':'browsePrevious'}.get(x.findtext('VALUESPECIFIER'))
            if scroll:
                self.assertEqual(x.findtext('PLAYER'),'0')
                for wire in ['BYTES_DOWN','BYTES2_DOWN']:
                    b=x.findtext(wire).split();expected.append((scroll,'note',0,int(b[1],16),None,True))
        observed=[(x['action'],x['kind'],x['channel'],x['number'],x.get('targetDeck'),x.get('pulse',False)) for x in p['inputs']]
        self.assertCountEqual(observed,expected)

    def test_source_archive_and_members_retain_separate_pins(self):
        from imix_original import IMIX_ORIGINAL_REFERENCES
        for f in IMIX_ORIGINAL_REFERENCES['DJ-Tech I-MIX']['files']:
            p=ROOT/f['cachePath']
            if p.exists():self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(),f['sha256'])
