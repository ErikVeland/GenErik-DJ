"""Qualify the recovered own-model mapping without motor or USB identity claims."""
import base64
import hashlib
import json
import struct
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]


class TwelveMK2Tests(unittest.TestCase):
    def profile(self):
        rows=json.loads((ROOT/'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']
        p=next((p for p in rows if p['id']=='Rane TWELVE MKII'),None)
        self.assertIsNotNone(p,'Recovered own-model MIDI subset is missing')
        return p

    def test_manual_accessory_has_only_qualified_inputs_and_no_hardware_writes(self):
        p=self.profile()
        self.assertEqual((p['autoSelect'],p['role'],len(p['inputs'])),(False,'accessory',124))
        self.assertEqual((p['outputs'],p['startup'],p['shutdown']),([],[],[]))
        for key in ['audioOutput','inputModes','inputProtocol']:self.assertNotIn(key,p)
        expected=[]
        for ch,deck in enumerate('abcd'):
            suffix='A' if deck in 'ac' else 'B'
            expected.extend([(f'load{suffix}',ch,2,'note',deck,False),(f'seek{suffix}',ch,102,'control',deck,False)])
            for slot in range(8):
                expected.append((f'hotcue{slot+1}{suffix}',ch+4,20+slot,'note',deck,False))
                if slot:
                    expected.extend([(f'clearHotcue{slot+1}{suffix}',ch+4,28+slot,'note',deck,False),
                        (f'hotcue{slot+1}{suffix}',ch+4,28+slot,'note',deck,True),
                        (f'clearHotcue{slot+1}{suffix}',ch+4,20+slot,'note',deck,True)])
        actual=[(r['action'],r['channel'],r['number'],r['kind'],r['targetDeck'],r.get('releaseOnly',False)) for r in p['inputs']]
        self.assertCountEqual(actual,expected)
        self.assertTrue(all(r['encoding']=='absolute' and not r['inverted'] and not r.get('anyChannel') for r in p['inputs']))
        self.assertTrue(all(r.get('layerIndependent') for r in p['inputs'] if r['action'].startswith(('hotcue','clearHotcue'))))
        self.assertNotIn('TWELVE',p['aliases'])

    def test_recovered_mapping_digest_conditions_slots_and_deliberately_unassigned_clears(self):
        self.profile()
        path=ROOT/'TestBuilds/r495/upstream/unpacked/Rane - Rane Twelve MK2.tsi'
        if not path.exists():self.skipTest('Ignored source reference is unavailable')
        source=path.read_bytes()
        self.assertEqual(hashlib.sha256(source).hexdigest(),'637741b3bf0d53c18d232bd670d178be374018a3199dd3593c44d43cc0623126')
        archive=ROOT/'TestBuilds/r495/upstream/Rane-Twelve-MK2-NI.zip'
        if archive.exists():
            self.assertEqual(base64.b32encode(hashlib.sha1(archive.read_bytes()).digest()).decode(),'4QNUUXW577K76KCCPJD3SYZWY5WRCXRK')
        from tsi_facts import inspect_tsi
        with self.assertRaises(ValueError):inspect_tsi(source)
        rows=inspect_tsi(source,include_unassigned=True)[0]['mappings']
        self.assertEqual(len(rows),326)
        unused=[r for r in rows if r['unassigned']]
        self.assertEqual({r['bindingID'] for r in unused},{20,94,170,246})
        self.assertTrue(all(r['signal'] is None and r['commandID']==2331 and r['comment']=='not mapped to avoid beat grid deletion' for r in unused))
        selected=[r for r in rows if r['direction']==0 and not r['unassigned'] and r['commandID'] in [3076,103,2328,2331]]
        self.assertEqual(len(selected),68)
        self.assertTrue(all(r['conditions']==[[0,0],[0,0]] and r['inverted']==0 for r in selected))
        for ch,deck in enumerate('abcd'):
            subset=[r for r in selected if r['target']==ch]
            self.assertEqual({r['signal'] for r in subset if r['commandID']==3076},{f'Ch{ch+1:02}.Note.D-1'})
            self.assertEqual({r['signal'] for r in subset if r['commandID']==103},{f'Ch{ch+1:02}.CC.102'})
            for cmd,slots in [(2328,range(8)),(2331,range(1,8))]:
                matches=[r for r in subset if r['commandID']==cmd]
                self.assertEqual({struct.unpack_from('>I',bytes.fromhex(r['settingsHex']),44)[0] for r in matches},set(slots))
                for r in matches:
                    slot=struct.unpack_from('>I',bytes.fromhex(r['settingsHex']),44)[0]
                    n=(20 if cmd==2328 else 28)+slot
                    note=['C','C#','D','D#','E','F','F#','G','G#','A','A#','B'][n%12]+str(n//12-1)
                    self.assertEqual(r['signal'],f'Ch{ch+5:02}.Note.{note}')
