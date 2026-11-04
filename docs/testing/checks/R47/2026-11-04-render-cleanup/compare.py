#!/usr/bin/env python3
"""Compare waveform geometry with the pre-cleanup source at 7cb4dc346."""
from pathlib import Path
import subprocess
import tempfile

folder = Path(__file__).resolve().parent
root = folder.parents[4]
source = root / "Replica/Sources/TDJCore"
with tempfile.TemporaryDirectory(prefix="generik-waveform-") as temporary:
    work = Path(temporary)
    # Copy the production declarations needed by the standalone drawing check.
    (work / "Models.swift").write_text((source / "Models.swift").read_text().split("public struct AudioAnalysis:")[0])
    (work / "BeatGridMap.swift").write_text((source / "BeatGridMap.swift").read_text().split("extension BeatTiming")[0])
    for name in ["BeatGrid.swift", "WaveformRangeIndex.swift", "WaveformLayers.swift"]:
        (work / name).write_bytes((source / name).read_bytes())
    baseline = subprocess.check_output(
        ["git", "show", "7cb4dc346:Replica/Sources/TDJCore/WaveformLayers.swift"], cwd=root, text=True)
    (work / "Baseline.swift").write_text(baseline.replace("WaveformLayers", "BaselineWaveformLayers"))
    executable = work / "compare"
    subprocess.run(["xcrun", "swiftc", "-O", "-whole-module-optimization", "-parse-as-library",
                    *map(str, work.glob("*.swift")), str(folder / "compare.swift"), "-o", str(executable)], check=True)
    subprocess.run([str(executable)], check=True)
