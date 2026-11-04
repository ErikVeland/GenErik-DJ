#!/usr/bin/env python3
"""Compile the production vocal recogniser as a focused native review tool."""
from pathlib import Path
import argparse
import subprocess

ROOT = Path(__file__).resolve().parents[2]


def compile_probe(work, framework, diagnostics=False, trace=False):
    work.mkdir(parents=True, exist_ok=True)
    core = ROOT / "Replica/Sources/TDJCore"
    (work / "Values.swift").write_text((core / "Models.swift").read_text().split("public struct Preparation:")[0])
    (work / "Energy.swift").write_text((core / "MusicalAnalysisFeatures.swift").read_text().split("struct MusicalPulseFrame")[0])
    (work / "BeatGridMap.swift").write_text((core / "BeatGridMap.swift").read_text().split("extension BeatTiming {")[0])
    (work / "main.swift").write_text((Path(__file__).parent / "VocalFormProbe.swift").read_text())
    sources = [work / name for name in ["Values.swift", "Energy.swift", "BeatGridMap.swift", "main.swift"]]
    sources += [core / name for name in ["BeatGrid.swift", "TrackArrangement.swift", "MusicalStructureAnalyzer.swift", "VocalFormAnalyzer.swift", "VocalRecognitionWindow.swift"]]
    recognizer = ROOT / "Replica/Sources/TDJInterface/VocalPhraseRecognizer.swift"
    if diagnostics or trace:
        source = recognizer.read_text()
        if diagnostics:
            source = source.replace(
            'guard whisper_full_get_segment_no_speech_prob(context,segment) < 0.6,\n                  let text=',
            'guard let text=')
            source = source.replace('guard noSpeech < 0.6 || (musicWindow && confidence >= 0.75) else { continue }', '')
            source = source.replace('guard noSpeech < 0.6 || (musicWindow && confidence >= 0.6) else { continue }', '')
        source = source.replace('let value=String(cString:text).trimmingCharacters(in:.whitespacesAndNewlines)',
            'let value=String(cString:text).trimmingCharacters(in:.whitespacesAndNewlines)\n'
            '            let count=VocalPhrase(start:start,end:end,text:value,confidence:confidence).words.count\n'
            '            FileHandle.standardError.write(Data("SEGMENT \\(start/analysis.sampleRate) \\(end/analysis.sampleRate) probability=\\(confidence) noSpeech=\\(whisper_full_get_segment_no_speech_prob(context,segment)) words=\\(count)\\n".utf8))')
        if trace:
            source = source.replace('let useRefined=hasVocalForm(refined)',
                'try JSONEncoder().encode(phrases).write(to:pcm.appendingPathExtension("focused.json"))\n'
                '        let useRefined=hasVocalForm(refined)')
        recognizer = work / "RecognizerDiagnostics.swift"
        recognizer.write_text(source)
    sources += [recognizer]
    subprocess.run(["xcrun", "swiftc", "-O", "-F", str(framework), "-framework", "whisper", "-Xlinker", "-rpath", "-Xlinker", str(framework),
                    *map(str, sources), "-o", str(work / "probe")], check=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("work", type=Path)
    parser.add_argument("framework", type=Path)
    parser.add_argument("--diagnostics", action="store_true", help="Report raw segment scores without the extra no-speech filter. No lyric text is printed.")
    parser.add_argument("--trace", action="store_true", help="Retain guided word fingerprints for local review. No lyric text is printed.")
    args = parser.parse_args()
    compile_probe(args.work, args.framework, args.diagnostics, args.trace)
