"""The own STUDIO4a mapper qualifies held DEL separately from latched modes."""
import hashlib
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path
from cmd_studio4a import studio4a_profiles,STUDIO4A_SOURCES
ROOT=Path(__file__).resolve().parents[2]


class Studio4aClearTests(unittest.TestCase):
    def test_thirty_two_clears_use_the_existing_side_scoped_hold_layer(self):
        p=studio4a_profiles()[0]
        self.assertEqual((len(p['inputs']),len(p['outputs'])),(156,24))
        clears=[r for r in p['inputs'] if r['action'].startswith('clearHotcue')]
        self.assertEqual(len(clears),32)
        for ch,deck in enumerate('abcd'):
            side=ch%2;suffix='A' if deck in 'ac' else 'B'
            for slot in range(1,9):
                clear=next(r for r in clears if r['action']==f'clearHotcue{slot}{suffix}' and r.get('targetDeck')==deck)
                self.assertEqual((clear['kind'],clear['channel'],clear['number'],clear['encoding'],clear['inverted'],clear['shifted'],clear['shiftChannel']),('note',ch,33+32*side+slot,'absolute',False,True,side))
                self.assertFalse(clear.get('releaseOnly'))
                cue=next(r for r in p['inputs'] if r['action']==f'hotcue{slot}{suffix}' and r.get('targetDeck')==deck)
                self.assertEqual((cue['number'],cue['shifted'],cue['shiftChannel']),(clear['number'],False,side))

    def test_own_xml_qualifies_every_pad_and_script_explicitly_qualifies_held_delete(self):
        root=ROOT/'TestBuilds/r169/upstream/res/controllers'
        for name,digest in STUDIO4A_SOURCES:
            path=root/name
            if path.exists():self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(),digest)
        path=root/STUDIO4A_SOURCES[0][0]
        if not path.exists():return
        controls=ET.parse(path).findall('.//control')
        for clear in [r for r in studio4a_profiles()[0]['inputs'] if r['action'].startswith('clearHotcue')]:
            self.assertTrue(any(x.findtext('key')=='BehringerCMDStudio4a.hotcue' and int(x.findtext('status','0'),0)==0x90+clear['channel'] and int(x.findtext('midino','0'),0)==clear['number'] and x.find('options/script-binding') is not None for x in controls))
        script=(root/STUDIO4A_SOURCES[1][0]).read_text()
        self.assertIn('if (BehringerCMDStudio4a.delPushed)',script)
        self.assertIn('"hotcue_"+hotcue+"_clear", 1',script)

    def test_no_clear_feedback_or_new_hardware_mode_writes(self):
        p=studio4a_profiles()[0]
        self.assertEqual((len(p['startup']),len(p['shutdown'])),(8,32))
        self.assertEqual(p['audioOutput'],'masterAndHeadphones')
        self.assertFalse(any(r['action'].startswith('clearHotcue') for r in p['outputs']))
        self.assertNotIn('inputModes',p)
