#!/usr/bin/env python3
"""Compare vocal roles on an even genre sample and explicit 12-inch versions."""
import argparse
import collections
import hashlib
import json
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]


def source_hashes():
    paths = ["Replica/Package.swift", "Replica/Sources/TDJCore/TrackArrangement.swift", "Replica/Sources/TDJCore/MusicalStructureAnalyzer.swift",
             "Replica/Sources/TDJCore/VocalFormAnalyzer.swift", "Replica/Sources/TDJInterface/VocalPhraseRecognizer.swift",
             "Replica/Sources/TDJInterface/ArrangementModel.swift", "Replica/Sources/TDJInterface/ReplicaModel.swift",
             "Replica/Sources/TDJInterface/VocalModelAssets/model.json"]
    return {path: hashlib.sha256((ROOT / path).read_bytes()).hexdigest() for path in paths}


def replay(report, work, probe, model):
    result = dict(report)
    result["inferenceSourceHashes"] = report["sourceHashes"]
    result["sourceHashes"] = source_hashes()
    result["selection"] = "Two successful recordings per genre family, all successful 12-inch entries, then missing version types."
    result["reviewMethod"] = "Replay the final role assignment on the saved native recogniser phrases and sound-classifier frames. No new transcription or source decode."
    result["tracks"] = []
    context = work / "replay-context.json"
    for source in report["tracks"]:
        row = dict(source)
        if row["state"] == "analysed":
            original = work / (row["id"] + ".json")
            output = work / (row["id"] + "-final.json")
            context.write_text(json.dumps({"title": row["title"], "genre": row["genre"]}))
            subprocess.run([str(probe), str(original), str(original), str(context), str(model), str(output), "--replay"], check=True)
            value = json.loads(output.read_text())
            rate = value["analysis"]["sampleRate"]
            sections = value["arrangement"]["sections"]
            row.update(valid=value["valid"], afterRoles=dict(collections.Counter(s["role"] for s in sections)),
                       sections=[{"startSeconds": round(s["start"] / rate, 2), "endSeconds": round(s["end"] / rate, 2),
                                  "role": s["role"], "name": s["name"]} for s in sections])
        result["tracks"].append(row)
    (work / "final-report.json").write_text(json.dumps(result, indent=2) + "\n")
    return result


def run(baseline, work, probe, model):
    work.mkdir(parents=True, exist_ok=True)
    groups = collections.defaultdict(list)
    for row in baseline["tracks"]:
        if row["state"] == "analysed":
            groups[row["genreFamilyHint"]].append(row)
    selected = []
    for family in sorted(groups):
        selected += groups[family][:2]
    selected += [row for rows in groups.values() for row in rows if "12-inch" in row["versionHints"]]
    for version in ["live", "radio-edit", "instrumental", "club", "extended", "dub", "acappella", "remix", "mashup"]:
        if not any(version in row["versionHints"] for row in selected):
            selected += next(([row] for rows in groups.values() for row in rows if version in row["versionHints"]), [])
    selected = list({row["id"]: row for row in selected}.values())
    report = {
        "format": "generik.vocal-form-review/v1",
        "selection": "Two successful recordings per genre family, all successful 12-inch entries, then missing version types.",
        "scope": "Source-bound machine-assisted review. No independent listening annotations or section-accuracy score.",
        "sourceHashes": {}, "tracks": []
    }
    for folder in ["Replica/Sources/TDJCore", "Replica/Sources/TDJInterface"]:
        for path in (ROOT / folder).glob("*Vocal*.swift"):
            report["sourceHashes"][str(path.relative_to(ROOT))] = hashlib.sha256(path.read_bytes()).hexdigest()
    for index, source in enumerate(selected):
        row = {key: source.get(key) for key in ["id", "artist", "title", "genre", "genreFamilyHint", "versionHints", "split", "inputSHA256"]}
        output = work / (row["id"] + ".json")
        reference = work / "reference.json"
        context = work / "context.json"
        reference.write_text(json.dumps(source["prediction"]))
        context.write_text(json.dumps({"title": row["title"], "genre": row["genre"]}))
        started = time.monotonic()
        try:
            path = Path(source["path"])
            with path.open("rb") as stream:
                if hashlib.file_digest(stream, "sha256").hexdigest() != row["inputSHA256"]:
                    raise ValueError("The source does not match the baseline hash.")
            log = work / (row["id"] + ".log")
            with log.open("w") as stream:
                subprocess.run([str(probe), str(path), str(reference), str(context), str(model), str(output)],
                               stdout=stream, stderr=subprocess.STDOUT, check=True, timeout=240)
            result = json.loads(output.read_text())
            rate = result["analysis"]["sampleRate"]
            sections = result["arrangement"]["sections"]
            row.update(state="analysed", valid=result["valid"], phraseCount=len(result["phrases"]),
                       beforeRoles=dict(collections.Counter(s["role"] for s in source["prediction"]["arrangement"]["sections"])),
                       afterRoles=dict(collections.Counter(s["role"] for s in sections)),
                       sections=[{"startSeconds": round(s["start"] / rate, 2), "endSeconds": round(s["end"] / rate, 2),
                                  "role": s["role"], "name": s["name"]} for s in sections])
        except (OSError, ValueError, subprocess.SubprocessError) as error:
            row.update(state="failed", error=str(error))
        row["elapsedSeconds"] = round(time.monotonic() - started, 3)
        report["tracks"].append(row)
        (work / "report.json").write_text(json.dumps(report, indent=2) + "\n")
        print(f'{index+1}/{len(selected)} {row["genreFamilyHint"]}: {row["artist"]} — {row["title"]}: {row["state"]} {row.get("afterRoles", {})}', flush=True)
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("baseline", type=Path)
    parser.add_argument("work", type=Path)
    parser.add_argument("probe", type=Path)
    parser.add_argument("model", type=Path)
    parser.add_argument("--replay", action="store_true")
    args = parser.parse_args()
    action = replay if args.replay else run
    action(json.loads(args.baseline.read_text()), args.work, args.probe.resolve(), args.model.resolve())
