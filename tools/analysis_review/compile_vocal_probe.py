#!/usr/bin/env python3
"""Compile the production vocal recogniser as a focused native review tool."""
from pathlib import Path
import argparse
import subprocess

ROOT = Path(__file__).resolve().parents[2]


def compile_probe(work, framework):
    work.mkdir(parents=True, exist_ok=True)
    core = ROOT / "Replica/Sources/TDJCore"
    (work / "Values.swift").write_text((core / "Models.swift").read_text().split("public struct Preparation:")[0])
    (work / "Energy.swift").write_text((core / "MusicalAnalysisFeatures.swift").read_text().split("struct MusicalPulseFrame")[0])
    (work / "BeatGridMap.swift").write_text((core / "BeatGridMap.swift").read_text().split("extension BeatTiming {")[0])
    (work / "main.swift").write_text((Path(__file__).parent / "VocalFormProbe.swift").read_text())
    sources = [work / name for name in ["Values.swift", "Energy.swift", "BeatGridMap.swift", "main.swift"]]
    sources += [core / name for name in ["BeatGrid.swift", "TrackArrangement.swift", "MusicalStructureAnalyzer.swift", "VocalFormAnalyzer.swift"]]
    sources += [ROOT / "Replica/Sources/TDJInterface/VocalPhraseRecognizer.swift"]
    subprocess.run(["xcrun", "swiftc", "-O", "-F", str(framework), "-framework", "whisper", "-Xlinker", "-rpath", "-Xlinker", str(framework),
                    *map(str, sources), "-o", str(work / "probe")], check=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("work", type=Path)
    parser.add_argument("framework", type=Path)
    args = parser.parse_args()
    compile_probe(args.work, args.framework)
