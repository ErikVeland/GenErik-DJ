import XCTest
@testable import TDJCore

final class SectionCueAllocatorTests: XCTestCase {
    private let sections: [ArrangementSection] = [
        .init(start:0,end:1000,role:.intro), .init(start:1000,end:2000,role:.verse),
        .init(start:2000,end:3000,role:.chorus)
    ]
    func testSectionsFillFreeSlotsWithoutChangingExistingCues() {
        let manual=PerformanceCue(frame:123,loopEnd:456)
        let result=SectionCueAllocator.allocate(sections:sections,existing:[0:manual],alreadyPrepared:false)
        XCTAssertEqual(result[0],manual)
        XCTAssertEqual(result[1]?.frame,0)
        XCTAssertEqual(result[2]?.sectionName,"VERSE")
        XCTAssertEqual(result[3]?.sectionColour,0xF6AF69)
    }
    func testEightSlotLimitAndExistingBoundaryCuesAreRespected() {
        let full=Dictionary(uniqueKeysWithValues:(0..<8).map { ($0,PerformanceCue(frame:Double($0))) })
        XCTAssertEqual(SectionCueAllocator.allocate(sections:sections,existing:full,alreadyPrepared:false),full)
        let grid=PerformanceCue(frame:0,kind:.grid)
        let result=SectionCueAllocator.allocate(sections:sections,existing:[0:grid],alreadyPrepared:false)
        XCTAssertEqual(result.count,3)
        XCTAssertEqual(result[0],grid)
        XCTAssertEqual(result[1]?.frame,1000)
    }
    func testDeletedCuesStayDeletedAndSectionCorrectionsRefreshGeneratedLabels() throws {
        var first=SectionCueAllocator.allocate(sections:sections,existing:[:],alreadyPrepared:false)
        first[1]=nil
        var edited=sections
        edited[2].role = .bridge
        let result=SectionCueAllocator.allocate(sections:edited,existing:first,alreadyPrepared:true)
        XCTAssertNil(result[1])
        XCTAssertEqual(result[2]?.sectionName,"BRIDGE")
        XCTAssertEqual(result[2]?.sectionColour,0xB69BE8)
        XCTAssertEqual(try JSONDecoder().decode(PerformanceCue.self,from:JSONEncoder().encode(result[2]!)),result[2])
        let legacy=try JSONDecoder().decode(PerformanceCue.self,from:Data("{\"frame\":42}".utf8))
        XCTAssertEqual(legacy.frame,42)
        XCTAssertNil(legacy.sectionName)
    }
}
