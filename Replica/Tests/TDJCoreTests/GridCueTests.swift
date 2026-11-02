import Foundation
import Testing
@testable import TDJCore

@Test func gridCueUsesFreeSlotTracksEditsAndPreservesDeletion() throws {
    var preparation=PerformancePreparation()
    preparation.cues["track"]=[0:.init(frame:100),1:.init(frame:200,loopEnd:400)]
    let changed1=preparation.synchronizeGridCue(trackID:"track",frame:80)
    #expect(changed1)
    #expect(preparation.cues["track"]?[2]?.category == .grid)
    #expect(preparation.cues["track"]?[0]?.category == .cue)
    #expect(preparation.cues["track"]?[1]?.category == .loop)
    let changed2=preparation.synchronizeGridCue(trackID:"track",frame:90)
    #expect(changed2)
    #expect(preparation.cues["track"]?[2]?.frame == 90)
    let url=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at:url) }
    preparation.cues["track"]?[2]=nil
    try preparation.save(to:url)
    var restored=try PerformancePreparation.load(from:url)
    let changed3=restored.synchronizeGridCue(trackID:"track",frame:100)
    #expect(!changed3)
    #expect(restored.cues["track"]?[2] == nil)
    #expect(restored.cues["track"]?[0]?.frame == 100)
    #expect(restored.cues["track"]?[1]?.loopEnd == 400)
}

@Test func gridCueDoesNotOverwriteFullBanksOrRewriteLegacyCues() throws {
    var preparation=PerformancePreparation()
    preparation.cues["full"]=Dictionary(uniqueKeysWithValues:(0..<8).map { ($0,PerformanceCue(frame:Double($0)*100)) })
    let before=preparation.cues["full"]
    let changed4=preparation.synchronizeGridCue(trackID:"full",frame:80)
    #expect(changed4)
    #expect(preparation.cues["full"] == before)
    var legacy=try #require(JSONSerialization.jsonObject(with:JSONEncoder().encode(preparation)) as? [String:Any])
    legacy.removeValue(forKey:"gridCueTracks")
    let url=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at:url) }
    try JSONSerialization.data(withJSONObject:legacy).write(to:url)
    var restored=try PerformancePreparation.load(from:url)
    let changed5=restored.synchronizeGridCue(trackID:"full",frame:90)
    #expect(!changed5)
    #expect(restored.cues["full"] == before)
    let changed6=restored.synchronizeGridCue(trackID:"new",frame:0)
    #expect(changed6)
    #expect(restored.cues["new"]?[0]?.category == .grid)
}
