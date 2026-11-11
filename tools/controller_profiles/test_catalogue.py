"""Focused checks for source identity, conversion and catalogue completeness."""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
import xml.etree.ElementTree as ET

from build_catalogue import build
from convert import control_record, convert_xml
from curated import curated_profiles
from fetch_reference import fetch, git_blob_hash
from sources import canonical, split_models

ROOT = Path(__file__).resolve().parents[2]


class ConversionTests(unittest.TestCase):
    def control(self, key="play", group="[Channel3]", extra="", status="0x92", address="11"):
        return ET.fromstring(f"<control><group>{group}</group><key>{key}</key><status>{status}</status><midino>{address}</midino>{extra}</control>")

    def test_four_deck_target(self):
        record, reason = control_record(self.control())
        self.assertIsNone(reason)
        self.assertEqual((record["action"], record["targetDeck"]), ("playA", "c"))

    def test_script_and_unknown_encoding_are_not_guessed(self):
        for option, expected in [("script-binding", "script-behaviour"), ("switch", "unsupported-encoding: switch")]:
            record, reason = control_record(self.control(extra=f"<options><{option}/></options>"))
            self.assertIsNone(record)
            self.assertEqual(reason, expected)

    def test_browser_requires_documented_relative_encoding(self):
        record, reason = control_record(self.control("MoveVertical", "[Library]", status="0xB0"))
        self.assertIsNone(record)
        self.assertEqual(reason, "unspecified-relative-encoding")
        record, _ = control_record(self.control("MoveVertical", "[Library]", "<options><selectknob/></options>", "0xB0"))
        self.assertEqual(record["encoding"], "twosComplement")

    def test_pair_requires_matching_group_and_control(self):
        high = ET.tostring(self.control("volume", "[Channel1]", "<options><fourteen-bit-msb/></options>", "0xB0", "0")).decode()
        low = ET.tostring(self.control("rate", "[Channel1]", "<options><fourteen-bit-lsb/></options>", "0xB0", "32")).decode()
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "fixture.midi.xml"
            path.write_text(f"<root><controller><controls>{high}{low}</controls></controller></root>")
            result = convert_xml(path)
            self.assertEqual(result["inputs"], [])
            self.assertEqual(result["inputRecords"][0]["disposition"], "missing-paired-low-byte")

    def test_conflicting_controls_are_removed_and_all_rows_are_accounted_for(self):
        controls = "".join(ET.tostring(self.control(key), encoding="unicode") for key in ["play", "pfl", "unknown"])
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "fixture.midi.xml"
            path.write_text(f"<root><controller><controls>{controls}</controls></controller></root>")
            result = convert_xml(path)
            self.assertEqual(result["inputs"], [])
            self.assertEqual(len(result["inputRecords"]), 3)
            self.assertEqual(result["inputRecords"][0]["disposition"], "conflicting-input-actions")

    def test_model_identity_preserves_plus_and_hardware_versions(self):
        self.assertNotEqual(canonical("Denon DJ PRIME 4+"), canonical("Denon PRIME 4"))
        self.assertNotEqual(canonical("DDJ-1000"), canonical("DDJ-1000SRT"))
        self.assertEqual(canonical("Vestax VCI-100MKII"), canonical("Vestax VCI-100 mk II"))
        self.assertEqual(canonical("Denon DJ MC4000"), canonical("Denon MC4000"))
        self.assertEqual(len(split_models("Mixars DUO (incl. MKII)")), 2)

    def test_curated_addresses_have_no_conflicts(self):
        for profile in curated_profiles():
            addresses = [(item["kind"], item["channel"], item["number"]) for item in profile["inputs"]]
            self.assertEqual(len(addresses), len(set(addresses)), profile["id"])
            self.assertLessEqual(len(profile["inputs"]), 512)
            self.assertLessEqual(len(profile["outputs"]), 128)

    def test_feedback_range_preserves_reverse_polarity_and_cc_lights(self):
        output = "<output><group>[Channel1]</group><key>play</key><status>0xB0</status><midino>11</midino><minimum>0</minimum><maximum>0.1</maximum><on>127</on><off>1</off></output>"
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "fixture.midi.xml"
            path.write_text(f"<root><controller><outputs>{output}</outputs></controller></root>")
            result = convert_xml(path)
            self.assertEqual(result["outputs"][0]["kind"], "control")
            self.assertEqual(result["outputs"][0]["onValue"], 1)
            self.assertEqual(result["outputs"][0]["offValue"], 127)

    def test_fetch_checks_git_identity_and_cache_boundaries(self):
        data = b"<root/>"
        entry = {"type": "blob", "path": "res/controllers/example.midi.xml", "sha": git_blob_hash(data)}
        with tempfile.TemporaryDirectory() as directory:
            result = fetch({"tree": [entry]}, "a" * 40, Path(directory), lambda _: data)
            self.assertEqual(result["files"][0]["sha256"], hashlib.sha256(data).hexdigest())
            with self.assertRaises(ValueError):
                fetch({"tree": [{**entry, "sha": "0" * 40}]}, "a" * 40, Path(directory), lambda _: data)
            with self.assertRaises(ValueError):
                fetch({"tree": [{**entry, "path": "res/controllers/../../../../escape.xml"}]}, "a" * 40, Path(directory), lambda _: data)


class GeneratedCatalogueTests(unittest.TestCase):
    def test_source_inventory_and_generated_data(self):
        cache = ROOT / "TestBuilds/r169/upstream"
        if not cache.exists():
            self.skipTest("Fetch the locked public reference cache before checking regeneration.")
        catalogue, runtime = build(cache, None)
        self.assertEqual(catalogue, json.loads((ROOT / "docs/coordination/controller-catalogue.json").read_text()))
        self.assertEqual(runtime, json.loads((ROOT / "Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json").read_text()))
        model_ids = {model["id"] for model in catalogue["models"]}
        for row in catalogue["benchmarkRows"]:
            for name in split_models(row["name"]):
                self.assertIn(canonical(name), model_ids)
        for definition in catalogue["definitions"]:
            if definition["sourceInputCount"] is not None:
                self.assertEqual(len(definition["inputRecords"]), definition["sourceInputCount"])
                self.assertEqual(len(definition["outputRecords"]), definition["sourceOutputCount"])
        self.assertTrue(catalogue["releaseGate"]["catalogueComplete"])
        self.assertFalse(catalogue["releaseGate"]["hardwareParityAccepted"])
        self.assertTrue(all(not model["releaseReady"] for model in catalogue["models"]))


if __name__ == "__main__":
    unittest.main()
