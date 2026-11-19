"""Independent CMD modules keep their own channels, encoders and native targets."""
import hashlib
import json
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
NAMES=['Behringer CMD PL-1','Behringer CMD DC-1','Behringer CMD LC-1','Behringer CMD DV-1']

class CMDModularTests(unittest.TestCase):
    def test_automatic_default_cores_keep_own_channel_and_feedback_contracts(self):
        by={p['id']:p for p in json.loads((ROOT/'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']}
        for name,count,outputs,channels in zip(NAMES,[104,34,40,36],[48,16,20,0],[set(range(4)),{5},{7},{6}]):
            self.assertTrue(name in by,name);p=by[name]
            self.assertEqual((p['autoSelect'],len(p['inputs']),len(p['outputs'])),(name!=NAMES[3],count,outputs))
            self.assertEqual({r['channel'] for r in p['inputs']},channels)
            self.assertEqual((p['startup'],p['shutdown']),([],[]));self.assertNotIn('audioOutput',p)
            self.assertEqual({r['targetDeck'] for r in p['inputs'] if r.get('targetDeck')},set('abc') if name==NAMES[3] else set('abcd'))
            self.assertFalse(any(r['action'].startswith('tempo') for r in p['inputs']))
        p=by[NAMES[0]];self.assertTrue(all(r.get('anyPositive') and 'onValue' not in r and r['decks']==list('abcd') for r in p['bankChanges']))
        self.assertTrue(all(r['argument']==400 for r in p['inputs'] if r['action'] in ['jogA','jogB']))
        self.assertEqual({r['offValue'] for r in by[NAMES[2]]['outputs']},{127})

    def test_pinned_source_files_are_read_only_reference_facts(self):
        from cmd_modular import CMD_REFERENCES
        for ref in CMD_REFERENCES.values():
            for r in ref['files']:
                p=ROOT/'TestBuilds/r420/upstream'/r['cacheName']
                if p.exists():self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(),r['sha256'])
