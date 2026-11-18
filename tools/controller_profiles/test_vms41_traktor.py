"""Check the independently recovered Traktor-edition mixer subset."""
import hashlib
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class VMS41TraktorTests(unittest.TestCase):
    def test_distinct_manual_mixer_uses_only_the_manufacturer_cc_table(self):
        runtime = json.loads((ROOT / "Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json").read_text())
        by = {item["id"]: item for item in runtime["profiles"]}
        name = "American Audio VMS4.1 Traktor"
        self.assertTrue(name in by, "Add the independently qualified Traktor-edition mixer subset")
        item = by[name]
        self.assertEqual(len(item["inputs"]), 24)
        self.assertFalse(item["autoSelect"] or item["outputs"] or item["startup"] or item["shutdown"])
        self.assertNotIn("audioOutput", item)
        self.assertTrue(all(row["channel"] == 0 and row["kind"] == "control" and row["encoding"] == "absolute" and not row["inverted"] for row in item["inputs"]))
        self.assertEqual([(r["number"], r["targetDeck"]) for r in item["inputs"] if r["action"] in {"levelA", "levelB"}], list(zip([4, 9, 14, 19], "abcd")))
        self.assertEqual({r["action"]: r["number"] for r in item["inputs"] if "targetDeck" not in r}, {"master": 28, "crossfader": 31, "cueMix": 34, "monitor": 35})
        self.assertNotIn("VMS4", item["aliases"])

    def test_ignored_primary_table_and_manual_retain_their_reviewed_bytes(self):
        for name, digest in [("vms41-traktor-midi.pdf", "dc207f113d1735899a769ba18536994a98f6578eeaa1af189358d817c1f8703c"),
                             ("vms41-traktor-manual.pdf", "9f55cc053272c38369833b18a53d20bc0385ad4fecc12807f212d1d3d656833e")]:
            path = ROOT / "TestBuilds/r387/upstream" / name
            if path.exists():
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), digest)
