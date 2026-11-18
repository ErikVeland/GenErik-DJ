"""Verify documented VCI-300MKII MIDI compatibility without merging model identities."""
import hashlib
import html
import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class VCI300MKIITests(unittest.TestCase):
    def test_mkii_reuses_the_qualified_wire_contract_with_a_distinct_identity(self):
        runtime = json.loads((ROOT / 'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())
        by = {p['id']: p for p in runtime['profiles']}
        self.assertTrue('Vestax VCI-300MKII' in by, 'Add the explicitly compatible MKII core')
        original, mkii = by['Vestax VCI-300'], by['Vestax VCI-300MKII']
        for key in ['inputs', 'outputs', 'startup', 'shutdown']:
            self.assertEqual(mkii[key], original[key])
        self.assertTrue(mkii['autoSelect'])
        self.assertNotEqual(mkii['definition'], original['definition'])
        self.assertNotIn('VCI-300', mkii['aliases'])
        self.assertNotIn('audioOutput', mkii)
        catalogue = json.loads((ROOT / 'docs/coordination/controller-catalogue.json').read_text())
        model = next(m for m in catalogue['models'] if m['name'] == 'Vestax VCI-300MKII')
        self.assertTrue(model['zeroConfig']['automaticControls'])
        self.assertFalse(model['theoreticalSupport']['complete'])

    def test_the_versioned_primary_software_manual_explicitly_qualifies_mkii_mapping_reuse(self):
        from vci300_mkii import MKII_MANUAL_SHA
        path = ROOT / 'TestBuilds/r391/upstream/vestax-vci300-manual.html'
        if path.exists():
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), MKII_MANUAL_SHA)
            text = ' '.join(html.unescape(re.sub('<[^>]+>', ' ', path.read_text())).split())
            self.assertIn('Differences between VCI-300 and VCI-300 MKII', text)
            self.assertIn('There were no changes in the MIDI mapping.', text)
