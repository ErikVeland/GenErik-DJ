#!/usr/bin/env python3
"""Run the silent audio check and retain source/binary provenance."""
import argparse
import datetime
import hashlib
import json
from pathlib import Path
import subprocess
from runtime_validation_provenance import inputs


def utc_now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def hashes(root):
    result = inputs(root)
    for name in [".build/release/tdj-runtime-validation", ".build/runtime-validation-build.json"]:
        result[name] = hashlib.sha256((root / name).read_bytes()).hexdigest()
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path, help="A new validation directory")
    parser.add_argument("seconds", type=float, help="Duration from 5 to 3600 seconds")
    parser.add_argument("--sequential", action="store_true", help="Play a real source longer than the PCM pool without short-loop recalls")
    args = parser.parse_args()
    if not 5 <= args.seconds <= 3600:
        parser.error("Duration must be from 5 to 3600 seconds.")
    if args.sequential and args.seconds < 60:
        parser.error("Sequential read-ahead validation requires at least 60 seconds.")
    output = args.output.resolve()
    if output.exists():
        parser.error("Choose a new validation directory.")
    root = Path(__file__).resolve().parent.parent
    binary = root / ".build/release/tdj-runtime-validation"
    if not binary.is_file():
        parser.error("Build the Release runtime validator first.")
    build_record = root / ".build/runtime-validation-build.json"
    if not build_record.is_file():
        parser.error("Rebuild the runtime validator to record its build inputs.")
    compiled = json.loads(build_record.read_text())
    if compiled["inputsSHA256"] != inputs(root) or compiled["binarySHA256"] != hashlib.sha256(binary.read_bytes()).hexdigest():
        parser.error("Runtime validator differs from current inputs. Rebuild with sources settled.")
    before = hashes(root)
    started = utc_now()
    command = [str(binary), str(output), str(args.seconds)]
    if args.sequential:
        command.append("sequential")
    result = subprocess.run(command, cwd=root)
    after = hashes(root)
    changed = sorted(name for name in before.keys() | after.keys()
                     if before.get(name) != after.get(name))
    manifest = {"configuration": "release", "startedUTC": started,
                "finishedUTC": utc_now(), "runtimeExitCode": result.returncode,
                "sourcesSHA256": before, "matchedAfterRun": not changed,
                "matchedCompiledInputs": True,
                "changedPaths": changed}
    if output.is_dir():
        (output / "build.json").write_text(json.dumps(manifest, indent=2) + "\n")
    if changed:
        print("Source or binary files changed during validation: " + ", ".join(changed))
        return 3
    return result.returncode


if __name__ == "__main__":
    raise SystemExit(main())
