import XCTest
@testable import TDJCore

final class DeckAnalysisPolicyTests: XCTestCase {
    func testMissingBPMOrKeyTriggersADeckAnalysisEvenWhenNotDeferred() {
        let key=MusicalKey(tonic:0,mode:.major)
        XCTAssertTrue(NativeAnalysisPlan.needsDeckAnalysis(deferred:false,bpm:nil,key:key))
        XCTAssertTrue(NativeAnalysisPlan.needsDeckAnalysis(deferred:nil,bpm:120,key:nil))
        XCTAssertTrue(NativeAnalysisPlan.needsDeckAnalysis(deferred:false,bpm:.nan,key:key))
        XCTAssertTrue(NativeAnalysisPlan.needsDeckAnalysis(deferred:true,bpm:120,key:key))
        XCTAssertFalse(NativeAnalysisPlan.needsDeckAnalysis(deferred:false,bpm:120,key:key))
    }
}
