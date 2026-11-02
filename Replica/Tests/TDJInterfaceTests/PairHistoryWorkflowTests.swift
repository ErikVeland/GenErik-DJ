import Foundation
import Testing
import TDJCore
import TDJInterface

@Test @MainActor func audiblePairIsRetainedOnceAndSurvivesModelRestart() async throws {
    let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at:root) }
    var base=URL(fileURLWithPath:#filePath)
    for _ in 0..<4 { base.deleteLastPathComponent() }
    let model=try ReplicaModel(root:root,playback:PlaybackController(offline:true))
    await model.importFiles(["clock-a-120.wav","clock-b-128.wav"].map { base.appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/"+$0) })
    model.load(trackID:model.library.tracks[0].id,deck:.a)
    model.load(trackID:model.library.tracks[1].id,deck:.b)
    await model.flushWrites()
    model.pressPlay(deck:.a); await model.flushTransportRequests()
    _=model.playback.core.renderOffline(frames:12000)
    model.pressPlay(deck:.b); await model.flushTransportRequests()
    _=model.playback.core.renderOffline(frames:96000)
    model.refreshPlayback(); await model.flushHistoryWrites()
    #expect(model.library.events.filter { $0.kind == .transition }.count == 1)
    model.refreshPlayback(); await model.flushHistoryWrites()
    #expect(model.library.events.filter { $0.kind == .transition }.count == 1)
    let restarted=try ReplicaModel(root:root,playback:PlaybackController(offline:true))
    #expect(restarted.library.events.filter { $0.kind == .transition }.count == 1)
}
