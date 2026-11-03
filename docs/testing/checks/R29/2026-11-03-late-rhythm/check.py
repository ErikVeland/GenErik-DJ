from pathlib import Path
import subprocess
root=Path(__file__).resolve().parents[5]
work=Path('/tmp/generik-late-rhythm-checks')
work.mkdir(exist_ok=True)
core=root/'Replica/Sources/TDJCore'
(work/'Values.swift').write_text((core/'Models.swift').read_text().split('public struct Preparation:')[0])
(work/'BeatGridMap.swift').write_text((core/'BeatGridMap.swift').read_text().split('extension BeatTiming {')[0])
tests=(root/'Replica/Tests/TDJCoreTests/LateRhythmTests.swift').read_text().replace('import XCTest','import Foundation').replace('@testable import TDJCore','')
(work/'Tests.swift').write_text(tests)
assertions=(root/'docs/testing/checks/R09/2026-11-03-musical-structure/check.py').read_text()
# Share the small standalone assertion adapter used by the previous iteration.
import ast
module=ast.parse(assertions)
for node in ast.walk(module):
    if isinstance(node,ast.Call) and isinstance(node.func,ast.Attribute) and node.func.attr=='write_text' and node.args:
        if isinstance(node.args[0],ast.Constant) and isinstance(node.args[0].value,str) and 'class XCTestCase {}' in node.args[0].value:
            (work/'Assertions.swift').write_text(node.args[0].value+'\nfunc XCTUnwrap<T>(_ value: T?, line: UInt = #line) throws -> T { guard let value else { fail("missing fixture value",line); throw NSError(domain:"fixture",code:1) }; return value }\n')
            break
else: raise RuntimeError('Assertion adapter was not found')
(work/'main.swift').write_text('''import Foundation
let suite=LateRhythmTests()
try suite.testQuietLateRhythmIsFoundDespiteLowWholeTrackActivity()
try suite.testLoudIrregularIntroDoesNotMaskMuchQuieterLateBeats()
try suite.testRhythmNearTheFileEndingRetainsItsSourceAnchor()
try suite.testAnIsolatedLateHitDoesNotInventATempo()
try suite.testExistingSteadyRhythmKeepsItsTempoAndAnchor()
try suite.testLateSearchHonoursCancellation()
try suite.testDecodedAudioWithALongIntroFindsTheQuietLateBeat()
print("Seven late-rhythm checks, \\(failures) failed assertions")
exit(failures == 0 ? 0:1)
''')
files=[work/'Values.swift',core/'AudioAnalyzer.swift',core/'MusicalSpectrumAnalyzer.swift',core/'BeatGrid.swift',work/'BeatGridMap.swift',core/'MusicalAnalysisFeatures.swift',core/'AdaptiveRhythmAnalyzer.swift',work/'Assertions.swift',work/'Tests.swift',work/'main.swift']
subprocess.run(['xcrun','swiftc','-O',*map(str,files),'-o',str(work/'checks')],check=True)
subprocess.run([str(work/'checks')],check=True)
