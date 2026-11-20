"""Own DAP D2 appendix keeps Cue Stop separate from held Set Cue."""
import hashlib
import json
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]


class DAPD2Tests(unittest.TestCase):
    def test_manual_core_uses_thirty_three_unique_channel_independent_inputs(self):
        profiles=json.loads((ROOT/'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']
        p=next((p for p in profiles if p['id']=='DAP KONTROL D2'),None);self.assertIsNotNone(p)
        self.assertEqual((p['autoSelect'],len(p['inputs']),p['outputs'],p['startup'],p['shutdown']),(False,33,[],[],[]))
        self.assertNotIn('role',p);self.assertNotIn('audioOutput',p)
        self.assertEqual(len({r['number'] for r in p['inputs']}),33);self.assertEqual(len({r['action'] for r in p['inputs']}),33)
        self.assertTrue(all(r['anyChannel'] and r['channel']==0 and r['encoding']=='absolute' and not r['inverted'] for r in p['inputs']))
        self.assertFalse(any(r['action'].startswith(('jog','tempo','hotcue','loopUpA','reloopA')) or r['action'] in ['crossfader','master','monitor'] for r in p['inputs']))

    def test_own_hexadecimal_addresses_and_the_distinct_cue_roles(self):
        profiles=json.loads((ROOT/'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']
        p=next((p for p in profiles if p['id']=='DAP KONTROL D2'),None);self.assertIsNotNone(p)
        notes={r['action']:r['number'] for r in p['inputs'] if r['kind']=='note'}
        self.assertEqual(notes,{'playA':0x43,'playB':0x4C,'cuePreviewA':0x3B,'cuePreviewB':0x44,'cueStopA':0x33,'cueStopB':0x3C,'syncA':0x40,'syncB':0x47,'keylockA':0x38,'keylockB':0x3F,'loadA':0x4B,'loadB':0x34,'cueA':0x55,'cueB':0x56,'pitchBendDownA':0x79,'pitchBendUpA':0x78,'pitchBendDownB':0x68,'pitchBendUpB':0x67,'loopDownA':0x72,'loopDownB':0x61,'loopUpB':0x60,'reloopB':0x5F})
        self.assertEqual({r['action']:r['number'] for r in p['inputs'] if r['kind']=='control'},{'gainA':0x0D,'gainB':0x0E,'highA':0x10,'highB':0x11,'midA':0x12,'midB':0x13,'lowA':0x14,'lowB':0x15,'levelA':0x08,'levelB':0x09,'cueMix':0x20})

    def test_own_manufacturer_manual_pin_is_independent_of_abma4(self):
        from dap_d2 import DAP_D2_REFERENCES
        ref=DAP_D2_REFERENCES['DAP KONTROL D2']
        self.assertTrue(ref['url'].startswith('https://www.highlite.com/'))
        for f in ref['files']:
            p=ROOT/f['cachePath']
            if p.exists():self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(),f['sha256'])
