#!/usr/bin/env python3
"""Summarise analysis attempts without mixing reuse, fresh work or failures."""
import argparse
from collections import defaultdict
import json
import math
from pathlib import Path
import statistics


def distribution(values):
    values = sorted(x for x in values if x is not None and math.isfinite(x) and x >= 0)
    if not values:
        return {"count": 0}
    return {
        "count": len(values),
        "p50": statistics.median(values),
        "p90": values[math.ceil(len(values) * 0.90) - 1],
        "p95": values[math.ceil(len(values) * 0.95) - 1],
        "maximum": values[-1],
    }


def load_records(paths):
    records, seen, warnings = [], set(), []
    for path in paths:
        for number, line in enumerate(path.read_text().splitlines(), 1):
            if not line.strip():
                continue
            try:
                record = json.loads(line)
                if record["format"] != "generik.analysis-measurement/v1":
                    raise ValueError("unsupported measurement format")
                attempt = record["attemptID"]
                if not isinstance(attempt, str) or not attempt:
                    raise ValueError("missing attempt ID")
                wall = record["wallSeconds"]
                if not isinstance(wall, (float, int)) or not math.isfinite(wall) or wall < 0:
                    raise ValueError("invalid wall time")
                if attempt in seen:
                    warnings.append(f"{path}:{number}: duplicate attempt excluded")
                    continue
                seen.add(attempt)
                records.append(record)
            except (ValueError, KeyError, TypeError) as error:
                warnings.append(f"{path}:{number}: excluded invalid record: {error}")
    return records, warnings


def summarise(records, manifest=None):
    coverage = None
    if manifest is not None:
        if manifest.get("format") != "tdj1.analysis-benchmark/v1":
            raise ValueError("Use the existing analysis benchmark manifest format.")
        hashes = {track["sha256"] for track in manifest["tracks"]}
        if not hashes or any(len(value) != 64 or any(c not in "0123456789abcdef" for c in value) for value in hashes):
            raise ValueError("The manifest needs exact SHA-256 audio identities.")
        records = [record for record in records if record.get("contentSHA256") in hashes]
        measured = {record["contentSHA256"] for record in records if record["outcome"] == "success"}
        coverage = {
            "corpus": manifest["corpus"], "referenceBuild": manifest.get("referenceBuild"),
            "expectedAudioHashes": len(hashes), "successfulAudioHashes": len(measured),
            "unmeasuredAudioHashes": sorted(hashes - measured),
        }
    fields = ("deviceModel", "appBuild", "requestedConfigurationID", "configurationID", "modelID",
              "structureVersion", "pass", "source", "outcome", "sourceHashComputed")
    groups = defaultdict(list)
    for record in records:
        groups[(*[record.get(field) for field in fields], tuple(sorted(record.get("cacheHits", []))))].append(record)
    summaries = []
    for key, attempts in groups.items():
        ratios = [r["wallSeconds"] / r["durationSeconds"] for r in attempts
                  if isinstance(r.get("durationSeconds"), (int, float))
                  and math.isfinite(r["durationSeconds"]) and r["durationSeconds"] > 0]
        stages = sorted({stage for r in attempts for stage in r.get("stageSeconds", {})})
        counters = sorted({counter for r in attempts for counter in r.get("counters", {})})
        summary = dict(zip(fields, key))
        summary["cachePath"] = list(key[-1])
        summary.update(
            attempts=len(attempts),
            uniqueAudioHashes=len({r["contentSHA256"] for r in attempts if r.get("contentSHA256")}),
            wallSeconds=distribution([r["wallSeconds"] for r in attempts]),
            realTimeFactor=distribution(ratios),
            secondsPerAudioMinute=distribution([value * 60 for value in ratios]),
            processCPUSeconds=distribution([r.get("processCPUSeconds") for r in attempts]),
            processLifetimePeakRSSBytes=max((r["processLifetimePeakRSSBytes"] for r in attempts
                                            if r.get("processLifetimePeakRSSBytes") is not None), default=None),
            cancellationResponseSeconds=distribution([r.get("cancellationResponseSeconds") for r in attempts]),
            stageSeconds={stage: distribution([r.get("stageSeconds", {}).get(stage) for r in attempts])
                          for stage in stages},
            counters={counter: sum(r.get("counters", {}).get(counter, 0) for r in attempts) for counter in counters},
            cacheHits={hit: sum(hit in r.get("cacheHits", []) for r in attempts)
                       for hit in sorted({hit for r in attempts for hit in r.get("cacheHits", [])})},
            thermalStates=sorted({r.get(field) or "unknown" for r in attempts for field in ("thermalStart", "thermalEnd")}),
        )
        summaries.append(summary)
    return {
        "format": "generik.analysis-performance-report/v1", "attempts": len(records), "coverage": coverage,
        "groups": summaries,
        "limits": [
            "This report does not assess accuracy or Traktor speed parity.",
            "CPU time includes all app threads. Peak RSS is the process lifetime peak, not an isolated job peak.",
            "Byte counters cover named operations only. Decoder and model physical I/O are not measured.",
            "Decode includes streaming rhythm and harmonic features. Key finalization excludes that shared work.",
            "Stages can overlap. Do not add nested stage times to calculate total time.",
            "Failure and cancellation groups contain incomplete work. Do not compare them with successful timings.",
            "Percentiles describe attempts, including repeats. The report lists unique audio hashes separately.",
            "A saved audio hash does not prove that this attempt reread the audio. Check sourceHash and cacheHits.",
        ],
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("logs", type=Path, nargs="+")
    parser.add_argument("--manifest", type=Path, help="Restrict results to hashes in an existing benchmark manifest")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    records, warnings = load_records(args.logs)
    manifest = json.loads(args.manifest.read_text()) if args.manifest else None
    report = summarise(records, manifest)
    report["inputWarnings"] = warnings
    content = json.dumps(report, indent=2, allow_nan=False) + "\n"
    if args.output:
        args.output.write_text(content)
    else:
        print(content, end="")


if __name__ == "__main__":
    main()
