import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@Test func mouseSurfaceCancellationRetainsContactAndRejectsItsLateRelease() {
    var session = MouseContactSession()
    var events: [SurfaceEvent] = []
    let start = SurfacePoint(id: 0, x: 0.25, y: 0.4)
    let moved = SurfacePoint(id: 0, x: 0.6, y: 0.7)
    session.move(to: start) { events.append($0) }
    session.move(to: moved) { events.append($0) }
    session.cancel { events.append($0) }
    session.cancel { events.append($0) }
    session.move(to: start) { events.append($0) }
    session.end(at: start) { events.append($0) }
    #expect(events.map(\.phase) == [.began, .moved, .moved, .cancelled])
    #expect(events.last?.points == [moved])
    #expect(events.last?.ending == [0])
    #expect(events.last?.remaining.isEmpty == true)
    session.move(to: start) { events.append($0) }
    session.end(at: moved) { events.append($0) }
    #expect(events.suffix(3).map(\.phase) == [.began, .moved, .ended])
    #expect(events.last?.points == [moved])
}

@Test func mouseSurfaceRecognizerCancellationAllowsTheNextGestureAndIdleResizeDoesNotBlockIt() {
    var session = MouseContactSession()
    var phases: [SurfaceEvent.Phase] = []
    let point = SurfacePoint(id: 0, x: 0.5, y: 0.5)
    session.cancel { phases.append($0.phase) }
    session.move(to: point) { phases.append($0.phase) }
    session.cancel(untilRelease: false) { phases.append($0.phase) }
    session.end(at: point) { phases.append($0.phase) }
    session.move(to: point) { phases.append($0.phase) }
    session.end(at: point) { phases.append($0.phase) }
    session.cancel(untilRelease: false) { phases.append($0.phase) }
    #expect(phases == [.began, .moved, .cancelled, .began, .moved, .ended])
}

@Test @MainActor func mouseSurfaceRemovalReleasesFrozenAuditionWithoutASeekOrLoopChange() async throws {
    var base = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 { base.deleteLastPathComponent() }
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
    await model.importFiles([base.appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/clock-a-120.wav")])
    let track = try #require(model.library.tracks.first)
    model.load(trackID: track.id, deck: .a)
    await model.flushWrites()
    model.load(trackID: track.id, deck: .b)
    await model.flushWrites()
    let reference = try PlaybackController(offline: true)
    try await reference.load(track: track, store: model.store, deck: .b)
    try model.playback.setMixer(.crossfader, value: 1)
    try reference.setMixer(.crossfader, value: 1)
    try model.playback.play(.b)
    try reference.play(.b)
    for _ in 0..<4 {
        let actual = model.playback.core.renderOffline(frames: 512)
        let expected = reference.core.renderOffline(frames: 512)
        #expect(actual.left == expected.left && actual.right == expected.right)
    }
    model.refreshPlayback()
    model.viewport[.a] = 96000
    model.frozen.insert(.a)
    model.performance.slicerQuantize = false
    var mouse = MouseContactSession()
    let waveform = WaveformGestureSession()
    let handle: (SurfaceEvent) -> Void = { waveform.handle($0, model: model, deck: .a, span: 96000) }
    mouse.move(to: .init(id: 0, x: 0.25, y: 0.5), action: handle)
    #expect(model.playbackSnapshot?.a.touchActive == true)
    for _ in 0..<4 {
        let actual = model.playback.core.renderOffline(frames: 512)
        let expected = reference.core.renderOffline(frames: 512)
        #expect(actual.left == expected.left && actual.right == expected.right)
    }
    mouse.cancel(action: handle)
    let cancelled = try #require(model.playbackSnapshot?.a)
    #expect(!cancelled.touchActive)
    #expect(cancelled.phase == .paused)
    #expect(!cancelled.loopEnabled)
    mouse.end(at: .init(id: 0, x: 0.9, y: 0.1), action: handle)
    #expect(model.playbackSnapshot?.a.sourceFrame == cancelled.sourceFrame)
    #expect(model.playbackSnapshot?.a.touchActive == false)
    #expect(model.playbackSnapshot?.a.loopEnabled == false)
    for _ in 0..<4 {
        let actual = model.playback.core.renderOffline(frames: 512)
        let expected = reference.core.renderOffline(frames: 512)
        #expect(actual.left == expected.left && actual.right == expected.right)
    }
    model.refreshPlayback()
    #expect(model.playbackSnapshot?.b.phase == .playing)
    #expect(model.playbackSnapshot?.b.sourceFrame == reference.core.snapshot()?.b.sourceFrame)
    #expect(model.playback.rejectedCommandCount == 0)
    await model.finishForShutdown()
    reference.stopAudio()
}
