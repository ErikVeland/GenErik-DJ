#!/usr/bin/env python3
"""Check vocal-guided retries against the saved genre/version review."""
import argparse
import collections
import concurrent.futures
import hashlib
import json
from pathlib import Path
import subprocess
import time

from review_vocal_form import source_hashes

ROOT = Path(__file__).resolve().parents[2]


def run(args):
    previous = json.loads(args.previous.read_text())
    sources = {row["id"]: row for row in json.loads(args.sources.read_text())["tracks"]}
    args.work.mkdir(parents=True, exist_ok=True)
    hashes = source_hashes()
    name = "Replica/Sources/TDJCore/VocalRecognitionWindow.swift"
    hashes[name] = hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
    report = {
        "format": "generik.dense-remix-review/v1", "sourceHashes": hashes,
        "method": "Reuse the pinned R37 first-pass word fingerprints and classifier frames. Run the production vocal-guided refinement on each original source. No lyric text is saved.",
        "timingScope": "Elapsed time includes decoding and refinement. The reused first recognition pass is excluded.",
        "referenceStatus": "Machine-assisted review without independent listening annotations. Coverage is not accuracy.",
        "tracks": []
    }

    def check(index, old):
        row = {key: old.get(key) for key in ["id", "artist", "title", "genre", "genreFamilyHint", "versionHints", "split", "inputSHA256"]}
        source = sources[row["id"]]
        original = Path(source["path"])
        reference = args.first_pass / (row["id"] + ".json")
        context = args.work / (row["id"] + "-context.json")
        output = args.work / (row["id"] + ".json")
        log = args.work / (row["id"] + ".log")
        row["beforeRoles"] = old["afterRoles"]
        started = time.monotonic()
        try:
            before = original.stat()
            with original.open("rb") as stream:
                if hashlib.file_digest(stream, "sha256").hexdigest() != row["inputSHA256"]:
                    raise ValueError("The source no longer matches the baseline.")
            context.write_text(json.dumps({"title": row["title"], "genre": row["genre"]}))
            with log.open("w") as stream:
                subprocess.run([str(args.probe.resolve()), str(original), str(reference.resolve()), str(context.resolve()),
                                str(args.model.resolve()), str(output.resolve()), "--refine"],
                               stdout=stream, stderr=subprocess.STDOUT, check=True, timeout=300)
            after = original.stat()
            if (before.st_size, before.st_mtime_ns) != (after.st_size, after.st_mtime_ns):
                raise ValueError("The source changed during review.")
            value = json.loads(output.read_text())
            rate = value["analysis"]["sampleRate"]
            sections = value["arrangement"]["sections"]
            roles = dict(collections.Counter(s["role"] for s in sections))
            had_form = any(role in row["beforeRoles"] for role in ["verse", "hook", "chorus"])
            if had_form and (value["usedFocusedResult"] or value["attemptedWindows"] or roles != row["beforeRoles"]):
                raise ValueError("A completed vocal form changed during an unresolved-track retry.")
            if not value["valid"]:
                raise ValueError("The refined arrangement has invalid source boundaries.")
            if value["usedFocusedResult"]:
                for phrase in value["phrases"]:
                    if not any(w["coreStart"] <= phrase["start"] < phrase["end"] <= w["coreEnd"] for w in value["attemptedWindows"]):
                        raise ValueError("A recognised phrase escaped its source window.")
            row.update(state="analysed", valid=True, usedFocusedResult=value["usedFocusedResult"],
                       attemptedWindows=len(value["attemptedWindows"]), phraseCount=len(value["phrases"]), afterRoles=roles,
                       sections=[{"startSeconds": round(s["start"] / rate, 2), "endSeconds": round(s["end"] / rate, 2),
                                  "role": s["role"], "name": s["name"]} for s in sections])
        except (OSError, ValueError, subprocess.SubprocessError) as error:
            row.update(state="failed", error=str(error))
        row["elapsedSeconds"] = round(time.monotonic() - started, 3)
        return index, row

    rows = {}
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        pending = [pool.submit(check, i, row) for i, row in enumerate(previous["tracks"])]
        for future in concurrent.futures.as_completed(pending):
            index, row = future.result()
            rows[index] = row
            report["tracks"] = [rows[i] for i in sorted(rows)]
            (args.work / "report.json").write_text(json.dumps(report, indent=2) + "\n")
            print(f'{len(rows)}/{len(pending)} {row["artist"]} — {row["title"]}: {row["state"]} retry={row.get("attemptedWindows")} {row.get("afterRoles", {})}', flush=True)
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ["sources", "previous", "first_pass", "work", "probe", "model"]:
        parser.add_argument(name, type=Path)
    parser.add_argument("--jobs", type=int, choices=[1, 2], default=1)
    run(parser.parse_args())
