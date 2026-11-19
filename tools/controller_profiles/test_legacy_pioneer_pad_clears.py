"""Each older four-deck Pioneer clear layout requires its own factory source."""
import hashlib
import json
import unittest
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
COUNTS = {'Pioneer DDJ-SX': 235, 'Pioneer DDJ-RX': 244, 'Pioneer DDJ-RZ': 250, 'Pioneer DDJ-RZX': 249}


class LegacyPioneerPadClearTests(unittest.TestCase):
    def test_every_own_model_has_thirty_two_clears_and_paired_negatives(self):
        profiles = json.loads((ROOT / 'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']
        for name, count in COUNTS.items():
            p = next(p for p in profiles if p['id'] == name)
            clears = [r for r in p['inputs'] if r['action'].startswith('clearHotcue') and not r.get('releaseOnly')]
            self.assertEqual({(r['channel'], r['number'], r['targetDeck'], r['action']) for r in clears}, {(7+i, n+8, deck, f"clearHotcue{n+1}{'A' if deck in 'ac' else 'B'}") for i, deck in enumerate('abcd') for n in range(8)}, name)
            self.assertEqual(len(p['inputs']), count)
            for clear in clears:
                self.assertFalse(set(clear) & {'shifted', 'shiftChannel', 'requiredMode', 'deckBank'})
                for action, number in [(clear['action'].replace('clearHotcue', 'hotcue'), clear['number']), (clear['action'], clear['number']-8)]:
                    guards = [r for r in p['inputs'] if r['action'] == action and r.get('targetDeck') == clear['targetDeck'] and r['channel'] == clear['channel'] and r['number'] == number and r.get('releaseOnly')]
                    self.assertEqual(len(guards), 1)
                    self.assertFalse(set(guards[0]) & {'shifted', 'shiftChannel', 'requiredMode', 'deckBank'})

    def test_every_own_table_keeps_its_reviewed_hash(self):
        from ddj_family import ddj_references
        for name in COUNTS:
            path = ROOT / f'TestBuilds/r179/manufacturer/{name.split(" ", 1)[1]}.pdf'
            if path.exists():
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), ddj_references()[name]['sha256'])
