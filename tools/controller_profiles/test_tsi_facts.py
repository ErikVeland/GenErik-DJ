"""Checks bounded, read-only inspection of the documented TSI frame structure."""
import base64
import struct
import unittest
from pathlib import Path

from tsi_facts import inspect_tsi


def frame(tag,payload):
    return tag.encode()+struct.pack(">I",len(payload))+payload


def string(value):
    return struct.pack(">I",len(value))+value.encode("utf-16-be")


def fixture(mapping_id=9, settings_version=3):
    definition=frame("DCDT",string("Ch01.CC.036")+struct.pack(">IIfII",7,0,127,0,0xffffffff))
    definitions=frame("DDDC",frame("DDCI",struct.pack(">I",1)+definition)+frame("DDCO",struct.pack(">I",0)))
    settings=struct.pack(">IIIIIIIff",settings_version,2,4,0,0,0,0,1.25,0)+bytes(80)
    mapping=frame("CMAI",struct.pack(">III",mapping_id,0,120)+frame("CMAD",settings))
    bindings=frame("DCBM",struct.pack(">I",1)+frame("DCBM",struct.pack(">I",9)+string("Ch01.CC.036")))
    data=frame("DDAT",definitions+frame("DDCB",frame("CMAS",struct.pack(">I",1)+mapping)+bindings))
    blob=frame("DIOM",frame("DIOI",struct.pack(">I",1))+frame("DEVS",struct.pack(">I",1)+frame("DEVI",string("Generic MIDI")+data)))
    return b'<NIXML><TraktorSettings><Entry Name="DeviceIO.Config.Controller" Value="'+base64.b64encode(blob)+b'"/></TraktorSettings></NIXML>'


class TSIFactsTests(unittest.TestCase):
    def test_explicit_inspection_preserves_unassigned_rows_without_inventing_signals(self):
        source=fixture(mapping_id=20,settings_version=4)
        with self.assertRaises(ValueError):inspect_tsi(source)
        rows=inspect_tsi(source,include_unassigned=True)[0]['mappings']
        self.assertEqual(len(rows),1)
        self.assertEqual((rows[0]['signal'],rows[0]['encoderMode'],rows[0]['unassigned']),(None,None,True))
        self.assertEqual(rows[0]['comment'],'')
        self.assertEqual(len(bytes.fromhex(rows[0]['settingsHex'])),116)
        self.assertEqual(rows[0]['conditions'],[[0,0],[0,0]])

    def test_condition_layout_is_unknown_outside_the_reviewed_settings_version(self):
        for version in [0,1,2,3,5,0xffffffff]:
            with self.subTest(version=version):
                row=inspect_tsi(fixture(settings_version=version))[0]['mappings'][0]
                self.assertIsNone(row['conditions'])
                self.assertEqual(row['settingsVersion'],version)
                self.assertEqual(row['signal'],'Ch01.CC.036')
        row=inspect_tsi(fixture(settings_version=4))[0]['mappings'][0]
        self.assertEqual((row['settingsVersion'],row['conditions']),(4,[[0,0],[0,0]]))

    def test_reads_used_binding_and_encoder_format_without_running_or_rewriting_source(self):
        source=fixture()
        result=inspect_tsi(source)
        self.assertEqual(result[0]["name"],"Generic MIDI")
        row=result[0]["mappings"][0]
        self.assertEqual((row["signal"],row["commandID"],row["target"],row["controllerType"],row["encoderMode"]),("Ch01.CC.036",120,0,2,0))
        self.assertEqual(row["rotarySensitivity"],1.25)
        self.assertEqual(source,fixture())

    def test_rejects_missing_ambiguous_oversized_and_malformed_inputs(self):
        for source in [b"<NIXML/>",b"<!DOCTYPE a><NIXML/>",b"x"*(4*1024*1024+1),
                       fixture().replace(b"RElPTQ",b"!!!!TQ"),fixture().replace(b"RElPTQ",b"RElPTw"),
                       fixture().replace(b"</TraktorSettings>",fixture()+b"</TraktorSettings>")]:
            with self.subTest(sourceLength=len(source)):
                for include in [False,True]:
                    with self.assertRaises(ValueError):inspect_tsi(source,include_unassigned=include)

    def test_pinned_factory_beatmix_file_resolves_only_used_bindings(self):
        path=Path(__file__).resolve().parents[2]/"TestBuilds/r378/upstream/Beatmix_V1_(2-Deck)-WIN.tsi"
        if not path.exists():self.skipTest("Ignored factory reference is unavailable")
        devices=inspect_tsi(path.read_bytes())
        rows=devices[0]["mappings"]
        self.assertEqual(len(rows),182)
        self.assertEqual({r["signal"] for r in rows if r["commandID"]==123},{"Ch01.CC.118+Ch01.CC.054","Ch02.CC.118+Ch02.CC.070"})
        self.assertEqual({r["signal"] for r in rows if r["commandID"]==301},{"Ch01.CC.053","Ch02.CC.069"})
        self.assertEqual({r["encoderMode"] for r in rows if r["controllerType"]==2},{0})
        self.assertEqual({r["signal"] for r in rows if r["commandID"]==5},{"Ch05.CC.083"})

    def test_published_legacy_xone_conditions_are_not_interpreted_as_version_four(self):
        root=Path(__file__).resolve().parents[2]/'TestBuilds/r496/upstream/traktor-documents/Native Instruments/Traktor Pro 3/Factory Settings/3.8.0/Default Settings/Controller/Allen & Heath'
        sources=[('01 - Controller - Allen & Heath - Xone 1D.tsi',1,102),
                 ('03 - Controller - Allen & Heath - Xone 4D.tsi',2,202)]
        if not root.exists():self.skipTest('Ignored publisher reference is unavailable')
        for name,version,count in sources:
            rows=inspect_tsi((root/name).read_bytes(),include_unassigned=True)[0]['mappings']
            self.assertEqual(len(rows),count)
            self.assertTrue(all(r['settingsVersion']==version and r['conditions'] is None for r in rows))


if __name__=="__main__":unittest.main()
