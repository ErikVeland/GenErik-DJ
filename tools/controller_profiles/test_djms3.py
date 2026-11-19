"""Check the independently reviewed DJM-S3 mixer contract."""
import hashlib
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class DJMS3Tests(unittest.TestCase):
    def test_s3_has_its_own_manual_default_channel_and_direct_cue_states(self):
        runtime = json.loads((ROOT / "Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json").read_text())
        by = {r["id"]: r for r in runtime["profiles"]}
        self.assertTrue("Pioneer DJM-S3" in by, "Add independent S3 manufacturer facts")
        p = by["Pioneer DJM-S3"]
        self.assertEqual(len(p["inputs"]), 18)
        self.assertFalse(p["autoSelect"] or p["outputs"] or p["startup"] or p["shutdown"])
        self.assertNotIn("audioOutput", p)
        self.assertEqual([(r["action"], r["number"]) for r in p["inputs"] if r["action"].startswith("cueState")], [("cueStateA", 70), ("cueStateB", 71)])
        self.assertTrue(all(r["kind"] == "control" and r["channel"] == 0 and r["encoding"] == "absolute" and not r["inverted"] for r in p["inputs"]))
        self.assertEqual([(r["number"], r["decks"]) for r in p["bankChanges"]], [(n, [d]) for d, ns in [("a", [51, 52, 53]), ("b", [55, 56, 57])] for n in ns])
        self.assertIn("TOGGLE", p["hardwareMode"])
        self.assertNotIn("DJM-450", p["aliases"])

    def test_manufacturer_manual_bytes_remain_pinned(self):
        from djms3 import S3_REFERENCES
        path = ROOT / "TestBuilds/r389/upstream/djm-s3-manual.pdf"
        if path.exists():
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), S3_REFERENCES["Pioneer DJM-S3"]["relatedSources"][0]["sha256"])
