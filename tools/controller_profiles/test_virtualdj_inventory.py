"""Keep the complete public VirtualDJ inventory separate from implementation claims."""
import hashlib
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class VirtualDJInventoryTests(unittest.TestCase):
    def test_all_published_products_are_accounted_for_without_inventing_profiles(self):
        locked = json.loads((ROOT / 'tools/controller_profiles/sources.lock.json').read_text())
        self.assertTrue('virtualdj' in locked, 'Pin the complete VirtualDJ hardware inventory')
        source = locked['virtualdj']
        self.assertEqual(len(source['rows']), 487)
        self.assertEqual(len({r['url'] for r in source['rows']}), 487)
        self.assertEqual(sum(r['role'] == 'dvs-medium' for r in source['rows']), 2)
        catalogue = json.loads((ROOT / 'docs/coordination/controller-catalogue.json').read_text())
        from sources import canonical
        by = {m['id']: m for m in catalogue['models']}
        for row in source['rows']:
            if row['role'] == 'dvs-medium':
                self.assertNotIn(canonical(row['name']), by)
                continue
            self.assertTrue(canonical(row['name']) in by, row['sourceName'])
            evidence = by[canonical(row['name'])]['comparisonSupport']['virtualDJ']
            self.assertEqual(evidence['sourceName'], row['sourceName'])
            self.assertEqual(evidence['category'], row['category'])
        for name in ['Pioneer DJ DJM-TOUR1', 'Roland DJ-808', 'Novation TWITCH', 'Numark NS7 III']:
            model = by[canonical(name)]
            self.assertEqual(model['implementation'], 'protocol-needed')
            self.assertFalse(model['zeroConfig']['automaticControls'] or model['theoreticalSupport']['complete'])
        soundcards = [by[canonical(r['name'])] for r in source['rows'] if r['category'] == 'Sound cards']
        self.assertEqual(len(soundcards), 18)
        self.assertTrue(all('Audio interface or DVS kit.' in ' '.join(m['gaps']) for m in soundcards if m['implementation'] == 'protocol-needed'))
        self.assertEqual(catalogue['virtualDJRows'], source['rows'])
        self.assertFalse(catalogue['releaseGate']['manufacturerAuditComplete'])

    def test_primary_html_snapshot_retains_all_rows_and_exact_source_hash(self):
        from virtualdj_inventory import read_virtualdj
        locked = json.loads((ROOT / 'tools/controller_profiles/sources.lock.json').read_text())['virtualdj']
        path = ROOT / 'TestBuilds/r392/upstream/virtualdj-hardware.html'
        if path.exists():
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), locked['sha256'])
            self.assertEqual(read_virtualdj(path.read_text()), locked['rows'])

    def test_parser_rejects_incomplete_duplicate_or_unidentified_source_cards(self):
        from virtualdj_inventory import read_virtualdj
        card = '<article class="col hwp_box"><a href="?model=X{0}"><div><b>Example Model {0}</b></div></a></article>'
        header = '<span class="hwp_categoryname">All-in-one</span>'
        sample = header + ''.join(card.format(i) for i in range(487))
        self.assertEqual(len(read_virtualdj(sample)), 487)
        for bad in ['', sample.replace('?model=X0', '?model=X1'), sample.replace('Example Model 0', ''), sample.replace('hwp_categoryname', 'missing-category')]:
            with self.assertRaises(ValueError):
                read_virtualdj(bad)
