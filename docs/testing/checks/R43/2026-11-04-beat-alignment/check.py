from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[5]
CORE = ROOT / "Replica/Sources/TDJCore"
WORK = Path(tempfile.mkdtemp(prefix="generik-beat-diagnosis-"))
(WORK / "Values.swift").write_text((CORE / "Models.swift").read_text().split("public struct Preparation:")[0])
(WORK / "BeatGridMap.swift").write_text((CORE / "BeatGridMap.swift").read_text().split("extension BeatTiming {")[0])
(WORK / "Configuration.swift").write_text((CORE / "AudioAnalyzer.swift").read_text().split("public enum AudioAnalyzer")[0])
(WORK / "main.swift").write_text((Path(__file__).parent / "BeatAlignmentProbe.swift").read_text())
files = [WORK / "Values.swift", WORK / "BeatGridMap.swift", WORK / "Configuration.swift"]
files += [CORE / name for name in ["BeatGrid.swift", "MusicalAnalysisFeatures.swift", "AdaptiveRhythmAnalyzer.swift"]]
files += [WORK / "main.swift"]
subprocess.run(["xcrun", "swiftc", "-O", *map(str, files), "-o", str(WORK / "probe")], check=True)
subprocess.run([str(WORK / "probe")], check=True)
