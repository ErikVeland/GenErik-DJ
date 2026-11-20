"""The SRT own factory pad channels differ from the original DDJ-1000."""
import json
import unittest
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]


class SRTPadChannelTests(unittest.TestCase):
    def test_every_srt_hotcue_uses_its_own_consecutive_deck_channel(self):
        profiles = json.loads((ROOT / 'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']
        p = next(p for p in profiles if p['id'] == 'Pioneer DDJ-1000SRT')
        pads = [r for r in p['inputs'] if r['action'].startswith('hotcue') and not r.get('releaseOnly')]
        self.assertEqual(len(pads), 32)
        self.assertEqual({(r['channel'], r['number'], r['targetDeck']) for r in pads}, {(7+i, n, deck) for i, deck in enumerate('abcd') for n in range(8)})
