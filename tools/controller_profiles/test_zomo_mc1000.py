"""MC-1000 uses reviewed four-deck wires and inactive cross-layer release guards."""
import hashlib
import json
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
NAME='Zomo MC-1000'

class ZomoMC1000Tests(unittest.TestCase):
    def test_native_core_keeps_load_banks_and_unsupported_modes_inactive(self):
        by={p['id']:p for p in json.loads((ROOT/'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']}
        self.assertTrue(NAME in by,NAME)
        p=by[NAME]
        self.assertTrue(p['autoSelect'])
        self.assertEqual((len(p['inputs']),sum(r.get('releaseOnly',False) for r in p['inputs'])),(138,96))
        self.assertEqual((p['outputs'],p['startup'],p['shutdown']),([],[],[]))
        self.assertNotIn('audioOutput',p)
        self.assertEqual(p['inputProtocol'],'mc1000')
        self.assertFalse(any(r['action'].startswith(('load','cuePreview','jog','pitchBend')) for r in p['inputs']))
        self.assertEqual({r['targetDeck'] for r in p['inputs'] if r['action'].startswith('play')},set('abcd'))
        self.assertFalse(any(r.get('anyChannel',False) for r in p['inputs']))

    def test_primary_manufacturer_mapping_and_manual_are_pinned(self):
        from zomo_mc1000 import ZOMO_REFERENCES
        r=ZOMO_REFERENCES[NAME]
        for path,digest in [('TestBuilds/r409/upstream/zomo-factory.zip',r['sha256']),('TestBuilds/r409/upstream/zomo-factory.tsi',r['memberSHA256']),('TestBuilds/r409/upstream/zomo-manual.pdf',r['manualSHA256'])]:
            p=ROOT/path
            if p.exists():self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(),digest)

    def test_every_native_note_and_filter_context_wire_exists_in_the_primary_tsi(self):
        import re
        from tsi_facts import inspect_tsi
        from zomo_mc1000 import zomo_mc1000_profiles
        path=ROOT/'TestBuilds/r409/upstream/zomo-factory.tsi'
        if not path.exists():self.skipTest('Optional public source cache is absent')
        notes={'C':0,'C#':1,'D':2,'D#':3,'E':4,'F':5,'F#':6,'G':7,'G#':8,'A':9,'A#':10,'B':11}
        wires=set()
        for device in inspect_tsi(path.read_bytes()):
            for row in device['mappings']:
                if row['direction']!=0:continue
                match=re.fullmatch(r'Ch(\d+)\.Note\.([A-G]#?)(-?\d+)',row['signal'])
                if match:wires.add(('note',int(match[1])-1,notes[match[2]]+12*(int(match[3])+1)))
                match=re.fullmatch(r'Ch(\d+)\.CC\.(\d+)',row['signal'])
                if match:wires.add(('control',int(match[1])-1,int(match[2])))
        for row in zomo_mc1000_profiles()[0]['inputs']:self.assertIn((row['kind'],row['channel'],row['number']),wires)
        for channel in range(4):
            for number in [68,96]:self.assertIn(('control',channel,number),wires)
