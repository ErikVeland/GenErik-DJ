import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@Test @MainActor func slowWaveformMovementFollowsFingerAndStopsWhenHeld() async throws {
    var base = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 { base.deleteLastPathComponent() }
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
    await model.importFiles([base.appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/clock-a-120.wav")])
    let track = try #require(model.library.tracks.first)
    model.load(trackID: track.id, deck: .a)
    await model.flushWrites()
    model.performance.waveformScratchAudio = true
    model.viewport[.a] = 96000
    let session = WaveformGestureSession()
    func send(_ phase: SurfaceEvent.Phase, _ x: Double) {
        session.handle(
            .init(phase: phase, points: [.init(id: 1, x: x, y: 0.5)], ending: phase == .ended ? [1] : []), model: model,
            deck: .a, span: 96000)
    }
    send(.began, 0.5)
    send(.moved, 0.52)
    #expect(abs(try #require(model.viewport[.a]) - 94080) < 0.00001)
    #expect(model.playbackSnapshot?.a.touchActive == true)
    // Movement below the former per-event cutoff must keep its direction.
    send(.moved, 0.521)
    #expect(try #require(model.playbackSnapshot?.a.performanceRate) < 0)
    send(.moved, 0.5205)
    #expect(try #require(model.playbackSnapshot?.a.performanceRate) > 0)
    send(.moved, 0.5205)
    #expect(model.playbackSnapshot?.a.performanceRate == 0)
    // A held waveform stays at the finger position.
    try await Task.sleep(for: .milliseconds(250))
    model.refreshPlayback()
    #expect(model.playbackSnapshot?.a.performanceRate == 0)
    let beforeHold = try #require(model.playbackSnapshot?.a.sourceFrame)
    _ = model.playback.core.renderOffline(frames: 256)
    model.refreshPlayback()
    #expect(model.playbackSnapshot?.a.sourceFrame == beforeHold)
    #expect(model.playbackSnapshot?.a.phase == .playing)
    send(.ended, 0.5205)
    #expect(model.playbackSnapshot?.a.touchActive == false)
    await model.finishForShutdown()
}

@Test @MainActor func waveformThrowCanBeCaughtAndCancelled() async throws {
    var base = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 { base.deleteLastPathComponent() }
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
    await model.importFiles([base.appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/clock-a-120.wav")])
    model.load(trackID: try #require(model.library.tracks.first).id, deck: .a)
    await model.flushWrites()
    model.performance.waveformScratchAudio = true
    model.viewport[.a] = 96000
    let session = WaveformGestureSession()
    func send(_ phase: SurfaceEvent.Phase, _ x: Double) {
        session.handle(
            .init(
                phase: phase, points: [.init(id: 1, x: x, y: 0.5)],
                ending: phase == .ended || phase == .cancelled ? [1] : []), model: model, deck: .a, span: 96000)
    }
    send(.began, 0.2)
    try await Task.sleep(for: .milliseconds(20))
    send(.moved, 0.25)
    let released = try #require(model.viewport[.a])
    send(.ended, 0.25)
    #expect(model.playbackSnapshot?.a.touchActive == true)
    try await Task.sleep(for: .milliseconds(50))
    let thrown = try #require(model.viewport[.a])
    #expect(thrown < released)
    send(.began, 0.7)
    let caught = try #require(model.viewport[.a])
    #expect(model.playbackSnapshot?.a.performanceRate == 0)
    try await Task.sleep(for: .milliseconds(50))
    #expect(model.viewport[.a] == caught)
    send(.cancelled, 0.7)
    #expect(model.playbackSnapshot?.a.touchActive == false)
    let cancelled = try #require(model.viewport[.a])
    try await Task.sleep(for: .milliseconds(50))
    #expect(model.viewport[.a] == cancelled)
    #expect(!model.previewing.contains(.a))
    await model.finishForShutdown()
}
