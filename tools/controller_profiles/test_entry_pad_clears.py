"""Entry-level clear layouts retain each own factory wire assignments."""
import hashlib
import json
import unittest
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]


class EntryPadClearTests(unittest.TestCase):
    def test_each_distinct_factory_layout_has_sixteen_clears_and_both_negative_aliases(self):
        profiles = json.loads((ROOT / 'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']
        for name, channels, offset, count in [('Pioneer DDJ-200', [8, 10], 0, 95), ('Pioneer DDJ-RB', [7, 8], 8, 114)]:
            p = next(p for p in profiles if p['id'] == name)
            clears = [r for r in p['inputs'] if r['action'].startswith('clearHotcue') and not r.get('releaseOnly')]
            self.assertEqual({(r['channel'], r['number'], r['targetDeck'], r['action']) for r in clears}, {(ch, n + offset, deck, f'clearHotcue{n + 1}{deck.upper()}') for ch, deck in zip(channels, 'ab') for n in range(8)}, name)
            self.assertEqual(len(p['inputs']), count)
            for clear in clears:
                cues = [r for r in p['inputs'] if r['action'] == clear['action'].replace('clearHotcue', 'hotcue') and r.get('targetDeck') == clear['targetDeck'] and not r.get('releaseOnly')]
                self.assertEqual(len(cues), 1)
                for action, wire in [(cues[0]['action'], clear), (clear['action'], cues[0])]:
                    guards = [r for r in p['inputs'] if r['action'] == action and r.get('targetDeck') == clear['targetDeck'] and r['channel'] == wire['channel'] and r['number'] == wire['number'] and r.get('releaseOnly')]
                    self.assertEqual(len(guards), 1)
                    self.assertFalse(set(guards[0]) & {'shifted', 'shiftChannel', 'requiredMode', 'deckBank'})

    def test_own_numeric_tables_keep_their_reviewed_hashes(self):
        from entry import entry_references
        for name in ['Pioneer DDJ-200', 'Pioneer DDJ-RB']:
            path = ROOT / f'TestBuilds/r181/manufacturer/{name.split(" ", 1)[1]}.pdf'
            if path.exists():
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), entry_references()[name]['sha256'])
