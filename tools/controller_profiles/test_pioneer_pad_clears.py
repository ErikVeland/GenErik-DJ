"""Four-deck clear pairs require each own manufacturer table and native activation layout."""
import copy
import hashlib
import json
import unittest
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]


class PioneerPadClearTests(unittest.TestCase):
    def test_each_model_has_all_thirty_two_factory_clear_wires_and_both_negatives(self):
        profiles = json.loads((ROOT / 'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']
        for name, count in [('DDJ-FLX10', 241), ('DDJ-1000', 221)]:
            p = next(p for p in profiles if p['id'] == name)
            clears = [r for r in p['inputs'] if r['action'].startswith('clearHotcue') and not r.get('releaseOnly')]
            expected = {(8 + 2 * i, slot, deck, f"clearHotcue{slot + 1}{'A' if deck in 'ac' else 'B'}") for i, deck in enumerate('abcd') for slot in range(8)}
            self.assertEqual({(r['channel'], r['number'], r['targetDeck'], r['action']) for r in clears}, expected, name)
            self.assertEqual(len(p['inputs']), count)
            for clear in clears:
                self.assertFalse(set(clear) & {'shifted', 'shiftChannel', 'requiredMode', 'deckBank'})
                for action, channel in [(clear['action'].replace('clearHotcue', 'hotcue'), clear['channel']), (clear['action'], clear['channel'] - 1)]:
                    guards = [r for r in p['inputs'] if r['action'] == action and r.get('targetDeck') == clear['targetDeck'] and r['channel'] == channel and r['number'] == clear['number'] and r.get('releaseOnly')]
                    self.assertEqual(len(guards), 1)
                    self.assertFalse(set(guards[0]) & {'shifted', 'shiftChannel', 'requiredMode', 'deckBank'})

    def test_own_numeric_tables_and_role_diagrams_keep_reviewed_hashes(self):
        from ddj1000 import DDJ1000_REFERENCES
        from flx10 import FLX10_REFERENCES
        for folder, name, ref in [('r214', 'DDJ-FLX10', FLX10_REFERENCES['DDJ-FLX10']), ('r215', 'DDJ-1000', DDJ1000_REFERENCES['DDJ-1000'])]:
            for suffix, digest in [('', ref['sha256']), ('-diagram', ref['relatedSources'][0]['sha256'])]:
                path = ROOT / f'TestBuilds/{folder}/manufacturer/{name}{suffix}.pdf'
                if path.exists():
                    self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), digest)

    def test_extension_rejects_unknown_model_missing_cue_or_positive_collision(self):
        from pioneer_pad_clears import add_pioneer_pad_clears
        profiles = json.loads((ROOT / 'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']
        p = copy.deepcopy(next(p for p in profiles if p['id'] == 'DDJ-1000'))
        p['inputs'] = p['inputs'][:125]
        variants = []
        bad = copy.deepcopy(p); bad['id'] = 'DDJ-1000SRT'; variants.append(bad)
        bad = copy.deepcopy(p); bad['inputs'] = [r for r in bad['inputs'] if not (r['action'] == 'hotcue1A' and r.get('targetDeck') == 'a')]; variants.append(bad)
        bad = copy.deepcopy(p); bad['inputs'].append({**p['inputs'][0], 'kind': 'note', 'channel': 8, 'number': 0}); variants.append(bad)
        for bad in variants:
            with self.assertRaises(ValueError):
                add_pioneer_pad_clears(bad)
