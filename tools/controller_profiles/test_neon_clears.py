"""Own NEON first-layer pad wires qualify clearing without inheriting other modes."""
import hashlib
import unittest
from pathlib import Path
from neon import neon_profiles,NEON_REFERENCES
ROOT=Path(__file__).resolve().parents[2]


class NEONClearTests(unittest.TestCase):
    def test_thirty_two_clears_keep_factory_deck_channels_and_both_aliases(self):
        p=neon_profiles()[0]
        self.assertEqual(len(p['inputs']),160)
        self.assertEqual((p['role'],p['autoSelect']),('accessory',True))
        for index,deck in enumerate('abcd'):
            suffix='A' if deck in 'ac' else 'B'
            for slot in range(1,9):
                for action,n,negative in [(f'clearHotcue{slot}{suffix}',47+slot,False),(f'clearHotcue{slot}{suffix}',15+slot,True),(f'hotcue{slot}{suffix}',47+slot,True)]:
                    found=[r for r in p['inputs'] if r['action']==action and r['channel']==index+7 and r['number']==n and r.get('targetDeck')==deck and bool(r.get('releaseOnly'))==negative]
                    self.assertEqual(len(found),1)
                clear=next(r for r in p['inputs'] if r['action']==f'clearHotcue{slot}{suffix}' and r.get('targetDeck')==deck and not r.get('releaseOnly'))
                self.assertFalse(any(k in clear for k in ['shifted','shiftChannel','requiredMode','deckBank']))

    def test_modes_setup_and_factory_source_hashes_remain_explicit(self):
        p=neon_profiles()[0];ref=NEON_REFERENCES[p['id']]
        self.assertEqual(p['startup'],[[240,10,0,247]])
        self.assertEqual((p['outputs'],p['shutdown']),([],[]));self.assertNotIn('audioOutput',p)
        self.assertEqual(len(p['bankChanges']),4)
        self.assertFalse(any(r['kind']!='note' or r['action'] in ['loadA','loadB','syncA','syncB','browse'] for r in p['inputs']))
        for name,r in [('NEON-MIDI.pdf',ref),('NEON-Guide.pdf',ref['relatedSources'][0])]:
            path=ROOT/'TestBuilds/r228/manufacturer'/name
            if path.exists():self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(),r['sha256'])
