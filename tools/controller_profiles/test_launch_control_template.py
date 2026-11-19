"""Original Launch Control reads configured User templates without template writes."""
import hashlib
import json
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
NAME='Novation Launch Control'

class LaunchControlTemplateTests(unittest.TestCase):
    def test_native_template_reader_has_no_preset_or_feedback_writes(self):
        by={p['id']:p for p in json.loads((ROOT/'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']}
        self.assertTrue(NAME in by,NAME)
        p=by[NAME]
        self.assertEqual((len(p['inputs']),len(p['outputs'])),(40,0))
        self.assertTrue(p['autoSelect'])
        self.assertEqual(p['inputProtocol'],'launchControlTemplate')
        self.assertEqual(p['startup'],[[240,0,32,41,2,10,119,0,247],[240,0,32,41,2,10,121,0,247]])
        self.assertEqual(p['shutdown'],[])
        self.assertNotIn('audioOutput',p)
        self.assertEqual({r['targetDeck'] for r in p['inputs'] if r['action'].startswith('cuePreview')},set('abcd'))

    def test_independent_manufacturer_document_and_editor_are_pinned(self):
        from launch_control_template import LAUNCH_CONTROL_TEMPLATE_REFERENCES
        ref=LAUNCH_CONTROL_TEMPLATE_REFERENCES[NAME]
        for path,digest in [('TestBuilds/r405/upstream/launch-control-programmer.pdf',ref['sha256']),('TestBuilds/r406/upstream/launch-control-editor.dmg',ref['editorSHA256']),('TestBuilds/r406/upstream/editor.js',ref['editorMemberSHA256'])]:
            cache=ROOT/path
            if cache.exists():self.assertEqual(hashlib.sha256(cache.read_bytes()).hexdigest(),digest)
