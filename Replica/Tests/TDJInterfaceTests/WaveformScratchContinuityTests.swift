import Foundation
import Testing
import TDJCore
@testable import TDJInterface

@Test @MainActor func slowWaveformMovementDoesNotMuteScratch() async throws {
    var base=URL(fileURLWithPath:#filePath)
    for _ in 0..<4 { base.deleteLastPathComponent() }
    let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at:root) }
    let model=try ReplicaModel(root:root,playback:PlaybackController(offline:true))
    await model.importFiles([base.appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/clock-a-120.wav")])
    let track=try #require(model.library.tracks.first)
    model.load(trackID:track.id,deck:.a); await model.flushWrites()
    model.performance.waveformScratchAudio=true
    model.viewport[.a]=96000
    let session=WaveformGestureSession()
    func send(_ phase: SurfaceEvent.Phase,_ x: Double) {
        session.handle(.init(phase:phase,points:[.init(id:1,x:x,y:0.5)],ending:phase == .ended ? [1]:[]),
            model:model,deck:.a,span:96000)
    }
    send(.began,0.5)
    send(.moved,0.52)
    #expect(model.playbackSnapshot?.a.touchActive == true)
    // Movement below the former per-event cutoff must keep its direction.
    send(.moved,0.521)
    #expect(try #require(model.playbackSnapshot?.a.performanceRate)>0)
    send(.moved,0.5205)
    #expect(try #require(model.playbackSnapshot?.a.performanceRate)<0)
    let movingRate=try #require(model.playbackSnapshot?.a.performanceRate)
    send(.moved,0.5205)
    #expect(model.playbackSnapshot?.a.performanceRate == movingRate)
    // A delayed or absent touch event must not become an audio stop.
    try await Task.sleep(for:.milliseconds(250))
    model.refreshPlayback()
    #expect(model.playbackSnapshot?.a.performanceRate == movingRate)
    let beforeHold=try #require(model.playbackSnapshot?.a.sourceFrame)
    _=model.playback.core.renderOffline(frames:256)
    model.refreshPlayback()
    #expect(model.playbackSnapshot?.a.sourceFrame != beforeHold)
    #expect(model.playbackSnapshot?.a.phase == .playing)
    send(.ended,0.5205)
    #expect(model.playbackSnapshot?.a.touchActive == false)
    await model.finishForShutdown()
}
