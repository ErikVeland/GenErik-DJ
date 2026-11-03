from pathlib import Path
import subprocess
import os
root=Path(__file__).resolve().parents[5]
work=Path('/tmp/generik-r09-checks'); work.mkdir(exist_ok=True)
# Compile the production analysis data declarations and timeline implementation without the app UI.
models=(root/'Replica/Sources/TDJCore/Models.swift').read_text().split('public struct Preparation:')[0]
energy=(root/'Replica/Sources/TDJCore/MusicalAnalysisFeatures.swift').read_text().split('struct MusicalPulseFrame')[0]
(work/'AnalysisValues.swift').write_text(models+'\n'+energy)
(work/'BeatGridMap.swift').write_text((root/'Replica/Sources/TDJCore/BeatGridMap.swift').read_text().split('extension BeatTiming {')[0])
tests=(root/'Replica/Tests/TDJCoreTests/MusicalStructureTests.swift').read_text().replace('@testable import TDJCore','').replace('import XCTest','')
(work/'Tests.swift').write_text(tests)
(work/'Assertions.swift').write_text('import Foundation\nclass XCTestCase {}\nvar failures = 0\nfunc fail(_ message: String, _ line: UInt) { failures += 1; print("FAIL line \\(line): \\(message)") }\nfunc XCTAssertEqual<T: Equatable>(_ a: T, _ b: T, line: UInt = #line) { if a != b { fail("\\(a) != \\(b)",line) } }\nfunc XCTAssertEqual(_ a: Double, _ b: Double, accuracy: Double, line: UInt = #line) { if abs(a-b) > accuracy { fail("\\(a) != \\(b)",line) } }\nfunc XCTAssertTrue(_ value: Bool, line: UInt = #line) { if !value { fail("expected true",line) } }\nfunc XCTAssertFalse(_ value: Bool, line: UInt = #line) { XCTAssertTrue(!value,line:line) }\nfunc XCTAssertNil<T>(_ value: T?, line: UInt = #line) { if value != nil { fail("expected nil",line) } }\nfunc XCTFail(_ message: String, line: UInt = #line) { fail(message,line) }\nfunc XCTAssertNotNil<T>(_ value: T?, line: UInt = #line) { if value == nil { fail("expected a value",line) } }\nfunc XCTAssertLessThanOrEqual(_ a: Double, _ b: Double, line: UInt = #line) { if a > b { fail("\\(a) > \\(b)",line) } }\nfunc XCTAssertGreaterThanOrEqual(_ a: Double, _ b: Double, line: UInt = #line) { if a < b { fail("\\(a) < \\(b)",line) } }\n')
(work/'main.swift').write_text('import Foundation\nlet suite=MusicalStructureTests()\nsuite.testRepeatedVocalRefrainsHaveChorusNamesAndColours()\nsuite.testInstrumentalBreakBuildAndDropDoNotInventVocals()\nsuite.testMixRegionsAvoidDetectedVocalsAndEndingPrecedesTail()\nsuite.testSilenceAndSteadyTonesDoNotAcquireSongForm()\nsuite.testManualPreparationSurvivesNewAutomaticEvidence()\ntry suite.testActualCachedPCMProducesFiniteFeaturesWithoutInventingVocals()\nprint("Six structure checks, \\(failures) failed assertions")\nexit(failures == 0 ? 0:1)\n')
arrangement=root/'Replica/Sources/TDJCore/TrackArrangement.swift'
if os.environ.get('R09_BASELINE'):
    arrangement=work/'BaselineArrangement.swift'
    arrangement.write_text((root/'Replica/Sources/TDJCore/TrackArrangement.swift').read_text().replace('        if !features.isEmpty { return musicalPreparation(analysis:a,features:features) }',''))
files=[str(work/'AnalysisValues.swift'),str(arrangement)]+[str(root/'Replica/Sources/TDJCore'/name) for name in ['BeatGrid.swift','MusicalStructureAnalyzer.swift']]+[str(work/'BeatGridMap.swift'),str(work/'Assertions.swift'),str(work/'Tests.swift'),str(work/'main.swift')]
subprocess.run(['xcrun','swiftc','-O',*files,'-o',str(work/'checks')],check=True)
subprocess.run([str(work/'checks')],check=True)
