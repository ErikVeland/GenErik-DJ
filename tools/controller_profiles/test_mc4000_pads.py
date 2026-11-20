"""The own factory chart qualifies MC4000 pad roles and resolves bend conflicts."""
import hashlib
import unittest
from pathlib import Path
from denon import denon_profiles,denon_references
ROOT=Path(__file__).resolve().parents[2]


class MC4000PadTests(unittest.TestCase):
    def test_four_pad_pairs_per_deck_have_both_release_aliases(self):
        p=denon_profiles()[0]
        self.assertEqual((len(p['inputs']),len(p['outputs'])),(91,18))
        for channel,deck in enumerate('ab'):
            suffix=deck.upper()
            for slot in range(1,5):
                for prefix,number,negative in [('hotcue',19+slot,False),('clearHotcue',27+slot,False),('hotcue',27+slot,True),('clearHotcue',19+slot,True)]:
                    rows=[r for r in p['inputs'] if r['action']==f'{prefix}{slot}{suffix}' and r['channel']==channel+4 and r['number']==number and bool(r.get('releaseOnly'))==negative]
                    self.assertEqual(len(rows),1)
                    self.assertEqual(rows[0]['targetDeck'],deck)
                    self.assertFalse(any(k in rows[0] for k in ['shifted','shiftChannel','requiredMode','deckBank']))

    def test_factory_bend_plus_does_not_collide_with_keylock(self):
        p=denon_profiles()[0]
        for channel,deck in enumerate('ab'):
            for name,number,negative in [('pitchBendDown',12,False),('pitchBendUp',11,False),('pitchBendDown',32,True),('pitchBendUp',33,True),('cuePreview',5,True)]:
                rows=[r for r in p['inputs'] if r['action']==name+deck.upper() and r['channel']==channel and r['number']==number and bool(r.get('releaseOnly'))==negative]
                self.assertEqual(len(rows),1)
            self.assertEqual([r['action'] for r in p['inputs'] if r['kind']=='note' and r['channel']==channel and r['number']==13],['keylock'+deck.upper()])
        self.assertIn('pitch-bend-plus',denon_references()['Denon MC4000']['review'])

    def test_pad_leds_use_factory_blue_one_and_zero_off(self):
        p=denon_profiles()[0];leds=[r for r in p['outputs'] if r['action'].startswith('hotcue')]
        self.assertEqual(len(leds),8)
        self.assertEqual({(r['channel'],r['number']) for r in leds},{(c,n) for c in [4,5] for n in range(20,24)})
        self.assertTrue(all((r['onValue'],r['offValue'],r['offUsesNoteOn'])==(1,0,True) for r in leds))
        path=ROOT/'TestBuilds/r193/manufacturer/MC4000.pdf'
        if path.exists():self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(),denon_references()['Denon MC4000']['sha256'])
