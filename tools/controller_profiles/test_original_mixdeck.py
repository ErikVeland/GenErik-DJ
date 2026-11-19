"""The original MIXDECK retains its own manual deck-only MIDI contract."""
import hashlib
import json
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
NAME='Numark MixDeck'

class OriginalMixdeckTests(unittest.TestCase):
    def test_original_deck_only_subset_is_manual_and_has_no_inherited_calibration(self):
        by={p['id']:p for p in json.loads((ROOT/'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']}
        self.assertTrue(NAME in by,NAME)
        p=by[NAME]
        self.assertEqual(len(p['inputs']),32)
        self.assertFalse(p['autoSelect'])
        self.assertEqual((p['outputs'],p['startup'],p['shutdown']),([],[],[]))
        self.assertNotIn('audioOutput',p)
        self.assertFalse(any(r['action'].startswith(('jog','tempo','gain','level')) for r in p['inputs']))
        self.assertEqual({r['argument'] for r in p['inputs'] if r['action'].startswith('toggleFixedLoop')},{1,4,8})
        self.assertEqual({r['number'] for r in p['inputs'] if r['action'].startswith('cueSet')},{57})

    def test_original_manufacturer_and_factory_sources_are_pinned(self):
        from original_mixdeck import ORIGINAL_MIXDECK_REFERENCES
        ref=ORIGINAL_MIXDECK_REFERENCES[NAME]
        for path,digest in [('TestBuilds/r409/upstream/mixdeck-guide-v1.6.pdf',ref['sha256']),('TestBuilds/r388/upstream/documents/Devices/NUMARK MIXDECK.xml',ref['mappingMemberSHA256'])]:
            p=ROOT/path
            if p.exists():self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(),digest)
