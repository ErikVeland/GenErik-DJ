from pathlib import Path
import subprocess
import os
root=Path(__file__).resolve().parents[5]
work=root/'TestBuilds/ipad/R34/checks'; work.mkdir(parents=True,exist_ok=True)
# Compile only the production structure analyser and its value types.
core=root/'Replica/Sources/TDJCore'
models=(root/'Replica/Sources/TDJCore/Models.swift').read_text().split('public struct Preparation:')[0]
energy=(root/'Replica/Sources/TDJCore/MusicalAnalysisFeatures.swift').read_text().split('struct MusicalPulseFrame')[0]
(work/'AnalysisValues.swift').write_text(models+'\n'+energy)
(work/'BeatGridMap.swift').write_text((root/'Replica/Sources/TDJCore/BeatGridMap.swift').read_text().split('extension BeatTiming {')[0])

(work/'main.swift').write_text((Path(__file__).parent/'TrackProbe.swift').read_text())
files=[work/'AnalysisValues.swift',core/'TrackArrangement.swift',core/'MusicalStructureAnalyzer.swift',core/'BeatGrid.swift',work/'BeatGridMap.swift',work/'main.swift']
subprocess.run(['xcrun','swiftc','-O',*map(str,files),'-o',str(work/'track-probe')],check=True)
subprocess.run([str(work/'track-probe'),*__import__('sys').argv[1:]],check=True)
