"""Optional steady lamps retain each model's own explicit output addresses."""
import json
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]


class ReviewedLegacyLampTests(unittest.TestCase):
    def test_all_sixty_eight_lamps_have_bounded_note_values_and_implemented_actions(self):
        rows=json.loads((ROOT/'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']
        for name,count in [('DJ-Tech DRAGON TWO',32),('DJ-Tech 4MIX',28),('Gemini GMX',8)]:
            p=next(p for p in rows if p['id']==name);self.assertEqual(len(p['outputs']),count)
            self.assertFalse(p['autoSelect']);self.assertEqual((p['startup'],p['shutdown']),([],[]))
            self.assertEqual(len({(r['channel'],r['number']) for r in p['outputs']}),count)
            for r in p['outputs']:
                self.assertEqual((r['kind'],r['onValue'],r['offValue'],r['offUsesNoteOn']),('note',127,0,True))
                self.assertTrue(any(i['action']==r['action'] and i.get('targetDeck')==r.get('targetDeck') and i['channel']==r['channel'] and i['number']==r['number'] and not i.get('releaseOnly') for i in p['inputs']))
                self.assertTrue(r['action'].startswith(('play','cuePreview','sync','keylock','cueA','cueB','hotcue')))

    def test_every_output_is_in_its_own_model_definition(self):
        from djtech_factory_legacy import DJTECH_LEGACY_REFERENCES
        rows=json.loads((ROOT/'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']
        for name,ref in DJTECH_LEGACY_REFERENCES.items():
            p=next(p for p in rows if p['id']==name);path=ROOT/ref['definitionCache']
            if not path.exists():continue
            leds={(int(n.get('channel')),int(n.get('note'),16),int(n.get('deck'))) for n in ET.parse(path).getroot().findall('led') if n.get('channel') is not None and n.get('note') is not None and n.get('deck') is not None}
            for r in p['outputs']:self.assertIn((r['channel'],r['number'],'abcd'.index(r['targetDeck'])+1),leds)
        path=ROOT/'TestBuilds/r471/upstream/gmx.midi.xml'
        if path.exists():
            outputs={(int(n.findtext('status'),16)&15,int(n.findtext('midino')),n.findtext('key')) for n in ET.parse(path).findall('.//outputs/output')}
            p=next(p for p in rows if p['id']=='Gemini GMX')
            for r in p['outputs']:
                key={'play':'play_indicator','cuePreview':'cue_indicator','cue':'pfl','keylock':'keylock'}[r['action'][:-1]]
                self.assertIn((r['channel'],r['number'],key),outputs)
