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


def fixture():
    definition=frame("DCDT",string("Ch01.CC.036")+struct.pack(">IIfII",7,0,127,0,0xffffffff))
    definitions=frame("DDDC",frame("DDCI",struct.pack(">I",1)+definition)+frame("DDCO",struct.pack(">I",0)))
    settings=struct.pack(">IIIIIIIff",3,2,4,0,0,0,0,1.25,0)+bytes(80)
    mapping=frame("CMAI",struct.pack(">III",9,0,120)+frame("CMAD",settings))
    bindings=frame("DCBM",struct.pack(">I",1)+frame("DCBM",struct.pack(">I",9)+string("Ch01.CC.036")))
    data=frame("DDAT",definitions+frame("DDCB",frame("CMAS",struct.pack(">I",1)+mapping)+bindings))
    blob=frame("DIOM",frame("DIOI",struct.pack(">I",1))+frame("DEVS",struct.pack(">I",1)+frame("DEVI",string("Generic MIDI")+data)))
    return b'<NIXML><TraktorSettings><Entry Name="DeviceIO.Config.Controller" Value="'+base64.b64encode(blob)+b'"/></TraktorSettings></NIXML>'


class TSIFactsTests(unittest.TestCase):
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
                with self.assertRaises(ValueError):inspect_tsi(source)

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


if __name__=="__main__":unittest.main()
