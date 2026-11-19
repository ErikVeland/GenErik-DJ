"""Check independent public ProMixer mapping facts without importing its software."""
import hashlib
import json
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class ProMixerPublicTests(unittest.TestCase):
    def test_afx_and_edge_are_distinct_manual_profiles_without_source_code_or_hardware_writes(self):
        runtime = json.loads((ROOT / "Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json").read_text())
        by = {r["id"]: r for r in runtime["profiles"]}
        for name, count in [("Akai Pro AFX", 44), ("Numark Mixtrack Edge", 51)]:
            self.assertTrue(name in by, "Add the independently recovered public MIDI subset")
            p = by[name]
            self.assertEqual(len(p["inputs"]), count)
            self.assertFalse(p["autoSelect"] or p["outputs"] or p["startup"] or p["shutdown"])
            self.assertNotIn("audioOutput", p)
            self.assertTrue(all(0 <= row["channel"] < 16 and 0 <= row["number"] < 128 for row in p["inputs"]))
            self.assertFalse(any(row["action"] in {"jogA", "jogB", "jogTouchA", "jogTouchB", "tempoA", "tempoB"} for row in p["inputs"]))

    def test_every_native_wire_exists_in_the_pinned_visible_mapping_documents(self):
        runtime = json.loads((ROOT / "Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json").read_text())
        by = {r["id"]: r for r in runtime["profiles"]}
        sources = [("Akai Pro AFX", "AKAI AFX Mode 1.xml", "1e99bbd92f883ab727986aab19902298e1ecdcbf2b79c26d4296bd5d46f247ca"),
                   ("Akai Pro AFX", "AKAI AFX Mode 2.xml", "5d2e6e53fa046801a37708b8cd60087dbf83f02997eda8e3e8b045b50bb0ccd2"),
                   ("Numark Mixtrack Edge", "NUMARK MIXTRACK-EDGE.xml", "8384c6959823ec9572cc36fe1a8db31aac98892a6de6a4549c7dba475ead411e")]
        for name, member, digest in sources:
            path = ROOT / "TestBuilds/r388/upstream/documents/Devices" / member
            if not path.exists():
                continue
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), digest)
            self.assertTrue(name in by)
            wires = set()
            for node in ET.fromstring(path.read_bytes()):
                row = {v.tag: v.text for v in node}
                if row.get("control_group") != "INPUT":
                    continue
                status, number = int(row["midichan"]), int(row["control_midino"])
                if 0 <= number < 128 and status >> 4 in {9, 11}:
                    wires.add(("note" if status >> 4 == 9 else "control", status & 15, number))
            self.assertTrue(all((r["kind"], r["channel"], r["number"]) in wires for r in by[name]["inputs"]))

    def test_installer_bytes_remain_pinned_as_research_only(self):
        path = ROOT / "TestBuilds/r388/upstream/DJProMixer_3.0_Setup.exe"
        if path.exists():
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), "0557173bb5cb8bce866bbd439bd10140d8c281fd550486541dc4ddfff46edbec")
