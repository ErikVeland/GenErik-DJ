from pathlib import Path
import ast
import subprocess

ROOT = Path(__file__).resolve().parents[5]
WORK = ROOT / "TestBuilds/ipad/R43/focused"
WORK.mkdir(parents=True, exist_ok=True)
CORE = ROOT / "Replica/Sources/TDJCore"
(WORK / "Values.swift").write_text((CORE / "Models.swift").read_text().split("public struct Preparation:")[0])
(WORK / "BeatGridMap.swift").write_text((CORE / "BeatGridMap.swift").read_text().split("extension BeatTiming {")[0])
adapter = ast.parse((ROOT / "docs/testing/checks/R09/2026-11-03-musical-structure/check.py").read_text())
for node in ast.walk(adapter):
    if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute) and node.func.attr == "write_text" and node.args:
        if isinstance(node.args[0], ast.Constant) and isinstance(node.args[0].value, str) and "class XCTestCase {}" in node.args[0].value:
            (WORK / "Assertions.swift").write_text(node.args[0].value + '\nfunc XCTUnwrap<T>(_ value:T?) throws -> T { guard let value else { fail("Missing fixture value",#line);throw CoreError.invalidGrid };return value }\n')
            break
else:
    raise RuntimeError("The focused assertion adapter is missing.")
source = ROOT / "Replica/Tests/TDJCoreTests/DenseBeatAlignmentTests.swift"
tests = source.read_text().replace("import XCTest", "").replace("@testable import TDJCore", "").replace("#filePath", '"' + str(source) + '"')
offbeats = (ROOT / "Replica/Tests/TDJCoreTests/MusicalRhythmRegressionTests.swift").read_text().split("@Test(arguments:")[0]
offbeats = offbeats.replace("import Testing", "").replace("@testable import TDJCore", "").replace("private func analyzeOffbeatRhythm", "func analyzeOffbeatRhythm").replace("try #require(", "try XCTUnwrap(")
(WORK / "Tests.swift").write_text(tests + "\n" + offbeats)
(WORK / "main.swift").write_text(r'''import Foundation
try DenseBeatAlignmentTests().testCreepRemixKeepsEveryKickAndTheOpeningAttack()
try DenseBeatAlignmentTests().testCachedStereoGridDetectionRejectsMissingFramesAndCancels()
try DenseBeatAlignmentTests().testCachedStereoPulsesKeepAnOpeningBeatWithOppositeChannels()
for firstBeat in 0..<4 {
    for gain in [1.0,0.1] {
        let value=try analyzeOffbeatRhythm(firstBeatIndex:firstBeat,gain:gain,accented:true)
        XCTAssertEqual(value.bpm ?? -1,120,accuracy:0.02)
        XCTAssertEqual((value.beatAnchorFrame ?? -44100)/value.sampleRate,0,accuracy:0.01)
        XCTAssertEqual(value.detectedDownbeatOffset,(4-firstBeat)%4)
    }
}
let even=try analyzeOffbeatRhythm(firstBeatIndex:0,gain:1,accented:false)
XCTAssertEqual(even.bpm ?? -1,120,accuracy:0.02)
XCTAssertNil(even.detectedDownbeatOffset)
print("Twelve dense-grid and offbeat checks, \(failures) failed assertions")
exit(failures == 0 ? 0:1)
''')
files = [WORK / "Values.swift", WORK / "BeatGridMap.swift"]
files += [CORE / name for name in ["AudioAnalyzer.swift", "MusicalSpectrumAnalyzer.swift", "MusicalAnalysisFeatures.swift", "AdaptiveRhythmAnalyzer.swift", "BeatGrid.swift"]]
files += [WORK / name for name in ["Assertions.swift", "Tests.swift", "main.swift"]]
subprocess.run(["xcrun", "swiftc", "-O", *map(str, files), "-o", str(WORK / "checks")], check=True)
subprocess.run([str(WORK / "checks")], check=True)
