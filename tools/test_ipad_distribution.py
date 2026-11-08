import json
from pathlib import Path
import plistlib
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import ipad_test


class DistributionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.local = self.root / "TestBuilds/ipad"
        self.records = self.root / "docs/testing/builds"
        self.archive = self.local / "145/GenErikDJ.xcarchive"
        self.archive.mkdir(parents=True)
        (self.archive / "evidence").write_text("signed archive")
        for name, value in [("ROOT", self.root), ("LOCAL", self.local), ("RECORDS", self.records)]:
            active = patch.object(ipad_test, name, value)
            active.start()
            self.addCleanup(active.stop)
        self.record = dict(build=145, archive=str(self.archive.relative_to(self.root)),
                           archiveSHA256=ipad_test.digest(self.archive.rglob("*"), self.archive), state="archived")
        ipad_test.write(self.records / "145.json", self.record)

    def test_export_failure_retains_archive_and_attempt_history(self):
        with patch.object(ipad_test, "run", side_effect=subprocess.CalledProcessError(1, "xcodebuild")):
            for _ in range(2):
                with self.assertRaises(subprocess.CalledProcessError):
                    ipad_test.export_testflight({"team": "TEAM"}, 145)
        saved = json.loads((self.records / "145.json").read_text())
        self.assertEqual(saved["state"], "export-failed")
        self.assertEqual(len(saved["distributionAttempts"]), 2)
        self.assertNotEqual(saved["distributionAttempts"][0]["log"], saved["distributionAttempts"][1]["log"])
        self.assertEqual(ipad_test.digest(self.archive.rglob("*"), self.archive), self.record["archiveSHA256"])

    def test_export_keeps_build_number_and_uses_production_cloudkit(self):
        def export(args, **kwargs):
            destination = Path(args[args.index("-exportPath") + 1])
            destination.mkdir()
            (destination / "GenErikDJ.ipa").write_bytes(b"test package")
        with patch.object(ipad_test, "run", side_effect=export):
            ipad_test.export_testflight({"team": "TEAM"}, 145)
        options = plistlib.loads((self.archive.parent / "export-1.plist").read_bytes())
        self.assertFalse(options["manageAppVersionAndBuildNumber"])
        self.assertEqual(options["iCloudContainerEnvironment"], "Production")
        self.assertEqual(options["destination"], "export")
        self.assertEqual(json.loads((self.records / "145.json").read_text())["state"], "exported")

    def test_changed_archive_stops_before_export(self):
        (self.archive / "evidence").write_text("changed")
        with patch.object(ipad_test, "run") as run:
            with self.assertRaises(ValueError):
                ipad_test.export_testflight({"team": "TEAM"}, 145)
            run.assert_not_called()

    def test_release_requires_clean_main(self):
        for branch, dirty in [("feature/change\n", ""), ("main\n", " M source.swift")]:
            with patch.object(ipad_test.subprocess, "check_output", side_effect=[branch, dirty]):
                with self.assertRaises(ValueError):
                    ipad_test.release_source()


if __name__ == "__main__":
    unittest.main()
