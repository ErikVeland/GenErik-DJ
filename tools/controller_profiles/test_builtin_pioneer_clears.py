"""Each built-in Pioneer clear pair has its own pinned normal Note-On source rows."""
import hashlib
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]


class BuiltinPioneerClearTests(unittest.TestCase):
    def test_both_own_models_qualify_every_normal_and_clear_pad_wire(self):
        for name,digest in [('Pioneer-DDJ-FLX4.midi.xml','7d84a58391b71a9c3540fd4a3b675db93faa1c7bb7a862e891cf6ba259e97c98'),('Pioneer-DDJ-400.midi.xml','97eae1632fb273c0d818901cb6ec10b094268d595eb31ebc8c31050bc3513ac7')]:
            path=ROOT/'TestBuilds/r169/upstream/res/controllers'/name
            if not path.exists():continue
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(),digest)
            controls=ET.parse(path).findall('.//control')
            for deck in [1,2]:
                for slot in range(1,9):
                    for operation,channel in [('activate',5+2*deck),('clear',6+2*deck)]:
                        found=[x for x in controls if x.findtext('group')==f'[Channel{deck}]' and x.findtext('key')==f'hotcue_{slot}_{operation}' and int(x.findtext('status','0'),0)==0x90+channel and int(x.findtext('midino','0'),0)==slot-1]
                        self.assertTrue(found,(name,deck,slot,operation))
                        self.assertTrue(any(not {y.tag.lower() for y in (x.find('options') or [])}-{'normal'} for x in found))
        pdf=ROOT/'TestBuilds/r486/upstream/ddj400-midi.pdf'
        if pdf.exists():self.assertEqual(hashlib.sha256(pdf.read_bytes()).hexdigest(),'c20990e3368511f6e0c0738a21489857e5daa6d805072412c71c4a5e46bb986a')

    def test_flx2_own_factory_table_and_hardware_roles_keep_the_reviewed_hashes(self):
        sources = [
            ('TestBuilds/r164/flx2.pdf', 'cccd405d9470382b58ab5d4e421678288448e1209e127d40c60f5228590b0e21'),
            ('TestBuilds/r487/upstream/flx2-hardware-diagram.pdf', '10619159f70bb5a4ae80090cb753726788351d058d87988d1b3c165ad134a716'),
        ]
        for name, digest in sources:
            path = ROOT / name
            if path.exists():
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), digest)
