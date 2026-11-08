import json
from pathlib import Path
import tempfile
import unittest

from analysis_measurements import distribution, load_records, summarise


def attempt(identity, source, wall, outcome="success"):
    return {"format": "generik.analysis-measurement/v1", "attemptID": identity,
            "deviceModel": "iPad7,3", "appBuild": "136", "pass": "matching", "source": source,
            "outcome": outcome, "wallSeconds": wall, "durationSeconds": 60, "contentSHA256": "a" * 64}


class AnalysisMeasurementReportTests(unittest.TestCase):
    def test_reuse_failure_and_device_are_separate(self):
        records = [attempt("one", "fresh", 60), attempt("two", "saved", 0.01),
                   attempt("three", "fresh", 2, "cancelled"), attempt("four", "fresh", 120)]
        report = summarise(records)
        self.assertEqual(len(report["groups"]), 3)
        fresh = report["groups"][0]
        self.assertEqual(fresh["wallSeconds"]["p50"], 90)
        self.assertEqual(fresh["realTimeFactor"]["p50"], 1.5)
        self.assertEqual(fresh["uniqueAudioHashes"], 1)
        records[-1]["deviceModel"] = "host"
        self.assertEqual(len(summarise(records)["groups"]), 4)

    def test_percentiles_and_missing_values(self):
        self.assertEqual(distribution([None, float("nan")]), {"count": 0})
        values = distribution(range(1, 101))
        self.assertEqual((values["p50"], values["p90"], values["p95"]), (50.5, 90, 95))

    def test_saved_traktor_and_new_audio_preparation_are_separate(self):
        saved = attempt("saved", "traktor", 0.01)
        imported = attempt("imported", "traktor", 20)
        saved["cacheHits"] = ["savedMatching"]
        imported["cacheHits"] = ["traktorReference"]
        imported["sourceHashComputed"] = True
        groups = summarise([saved, imported])["groups"]
        self.assertEqual(len(groups), 2)
        self.assertEqual(groups[0]["cachePath"], ["savedMatching"])

    def test_duplicate_exports_and_truncated_attempts_are_reported(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "log.jsonl"
            line = json.dumps(attempt("one", "fresh", 60)) + "\n"
            path.write_text(line + line + '{"format":')
            records, warnings = load_records([path])
        self.assertEqual(len(records), 1)
        self.assertEqual(len(warnings), 2)

    def test_existing_corpus_matches_hashes_without_claiming_accuracy(self):
        manifest = {"format": "tdj1.analysis-benchmark/v1", "corpus": "synthetic",
                    "tracks": [{"sha256": "a" * 64}, {"sha256": "b" * 64}]}
        report = summarise([attempt("one", "fresh", 60)], manifest)
        self.assertEqual(report["coverage"]["successfulAudioHashes"], 1)
        self.assertEqual(report["coverage"]["unmeasuredAudioHashes"], ["b" * 64])
        self.assertNotIn("referenceCorpusPassed", report)


if __name__ == "__main__":
    unittest.main()
