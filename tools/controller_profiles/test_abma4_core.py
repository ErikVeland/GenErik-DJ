"""Publisher-paired manual cores keep the documented channel-independent callback."""
import hashlib
import json
import re
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
NAMES=['BeyondMusic (BMI) ABMA4','JB Systems DJ KONTROL1']


class ABMA4CoreTests(unittest.TestCase):
    def test_both_manual_cores_use_unique_normal_actions_and_wires(self):
        rows=json.loads((ROOT/'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']
        for name in NAMES:
            p=next((p for p in rows if p['id']==name),None);self.assertIsNotNone(p,name)
            self.assertFalse(p['autoSelect']);self.assertNotIn('role',p);self.assertEqual(len(p['inputs']),33)
            self.assertEqual((p['outputs'],p['startup'],p['shutdown']),([],[],[]));self.assertNotIn('audioOutput',p)
            self.assertFalse(p.get('inputModes') or p.get('bankChanges'))
            self.assertEqual(len({x['number'] for x in p['inputs']}),33)
            self.assertEqual(len({x['action'] for x in p['inputs']}),33)
            self.assertTrue(all(x.get('anyChannel') and x['channel']==0 and x['encoding']=='absolute' for x in p['inputs']))
            self.assertEqual([x['action'] for x in p['inputs'] if x['inverted']],['crossfader'])
            self.assertFalse(any(x['action'].startswith(('hotcue','jog','tempo','loopIn','loopOut','reloop')) for x in p['inputs']))
        c=json.loads((ROOT/'docs/coordination/controller-catalogue.json').read_text())
        for name in NAMES:
            m=next(m for m in c['models'] if m['name']==name)
            self.assertFalse(m['zeroConfig']['automaticControls'] or m['theoreticalSupport']['complete'])
            self.assertEqual(m['implementation'],'partial-midi-profile')

    def test_every_active_wire_matches_the_explicit_publisher_callback(self):
        source=ROOT/'TestBuilds/r466/upstream/pcdj-controllers/Applications/DEX4.app/Contents/Resources/controllers/Beyond__Abm4.js'
        if not source.exists():self.skipTest('Public archive cache is optional')
        s=source.read_text();self.assertIn("return 'midi';",s)
        self.assertIn("'Abama 4' - JBSystems DJ-kontrol 1 (no audio)",s)
        self.assertIn('return 0x0014;',s);self.assertIn('return 0x0804;',s)
        callback=s.split('function messageReceived(',1)[1].split('return !messageNotProcessed;',1)[0]
        self.assertNotRegex(callback,r'(if|switch)\s*\(\s*channel\b')
        for action,source_action,nums in [
            ('play','deckPlayPause',[67,76]),('cuePreview','deckCue',[51,60]),
            ('sync','deckSync',[64,71]),('keylock','deckKeyLock',[56,63]),('load','deckLBLoad',[75,52]),
            ('cue','deckMonitor',[85,86]),('pitchBendDown','deckBendDown',[121,104]),
            ('pitchBendUp','deckBendUp',[120,103]),('loopDown','deckLoopLess',[114,97]),('loopUp','deckLoopMore',[113,96]),
            ('level','setDeckVolume',[8,9]),('gain','setDeckGain',[13,14]),
            ('high','setDeckEqHigh',[16,17]),('mid','setDeckEqMid',[18,19]),('low','setDeckEqLow',[20,21]),
        ]:
            for deck,n in enumerate(nums):
                self.assertRegex(callback,rf"case 0x{n:02X}:\s*call\('{source_action}', {deck}, data2\)")
        self.assertIn("case 0x0A: call('setCrossfader', 0x7F-data2)",callback)
        self.assertIn("case 0x20: call('setCuePgmMix', data2)",callback)
        self.assertIn("case 0x22: call('setMonitorGain', data2)",callback)
        rows=json.loads((ROOT/'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']
        a=next(x for x in rows if x['id']==NAMES[0]);b=next(x for x in rows if x['id']==NAMES[1])
        self.assertEqual(a['inputs'],b['inputs'])

    def test_publisher_archive_and_controller_member_pins(self):
        from abma4_core import ABMA4_CORE_REFERENCES
        ref=ABMA4_CORE_REFERENCES[NAMES[0]]
        for f in ref['files']:
            p=ROOT/f['cachePath']
            if p.exists():self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(),f['sha256'])
