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

@Test(arguments: [false, true], [false, true])
@MainActor func fullyStoppedWaveformDropSurvivesRestart(snap: Bool, beatFix: Bool) async throws {
    let (model, root, track) = try await loadPlayheadFixture(streaming: true)
    defer { try? FileManager.default.removeItem(at: root) }
    model.load(trackID: track.id, deck: .a)
    await model.playbackLoads?.value
    #expect(!model.performance.snapPlayingWaveform)
    model.performance.snapPlayingWaveform = snap
    model.pressPlay(deck: .a, vinylStop: false)
    await model.playback.flushSourcePreparations()
    _ = model.playback.core.renderOffline(frames: 16000)
    model.refreshPlayback()
    let atStop = try #require(model.playbackSnapshot?.a.sourceFrame)
    model.pressPlay(deck: .a, vinylStop: false)
    _ = model.playback.core.renderOffline(frames: 4096)
    model.refreshPlayback()
    #expect(model.playbackSnapshot?.a.phase == .paused)
    #expect(model.playbackSnapshot?.a.sourceFrame == atStop)
    if beatFix { model.toggleGridEditing(deck: .a) }
    let target = 1234.5
    let span = track.analysis.sampleRate * 2
    let lift = 0.2 + (atStop - target) / span
    let gesture = WaveformGestureSession()
    func send(_ phase: SurfaceEvent.Phase, x: Double) {
        gesture.handle(.init(phase: phase, points: [.init(id: 1, x: x, y: 0.6)], ending: phase == .ended ? [1] : []),
                       model: model, deck: .a, span: span)
    }
    send(.began, x: 0.2)
    send(.moved, x: lift - 0.01)
    send(.ended, x: lift)
    await model.playback.flushSourcePreparations()
    _ = model.playback.core.renderOffline(frames: 2048)
    model.refreshPlayback()
    #expect(model.playbackSnapshot?.a.phase == .paused)
    #expect(abs(try #require(model.viewport[.a]) - target) < 0.0001)
    #expect(abs(try #require(model.playbackSnapshot?.a.sourceFrame) - target) < 0.0001)
    model.pressPlay(deck: .a, vinylStop: false)
    await model.playback.flushSourcePreparations()
    let restarted = try #require(model.playback.core.snapshot()?.a)
    #expect(restarted.phase == .playing && restarted.synced)
    #expect(abs(restarted.sourceFrame - target) < 0.0001)
    await model.finishForShutdown()
}

@Test(arguments: [false, true])
@MainActor func playingWaveformDropUsesTheSnapOption(snap: Bool) async throws {
    let (model, root, track) = try await loadPlayheadFixture(streaming: true)
    defer { try? FileManager.default.removeItem(at: root) }
    model.load(trackID: track.id, deck: .a)
    await model.playbackLoads?.value
    model.performance.snapPlayingWaveform = snap
    model.pressPlay(deck: .a, vinylStop: false)
    await model.playback.flushSourcePreparations()
    let gesture = WaveformGestureSession()
    let span = track.analysis.sampleRate * 2
    for (phase, x): (SurfaceEvent.Phase, Double) in [(.began, 0.8), (.moved, 0.5), (.ended, 0.49)] {
        gesture.handle(.init(phase: phase, points: [.init(id: 1, x: x, y: 0.6)], ending: phase == .ended ? [1] : []),
                       model: model, deck: .a, span: span)
    }
    await model.playback.flushSourcePreparations()
    let result = try #require(model.playback.core.snapshot())
    #expect(result.a.phase == .playing && !result.a.touchActive && result.a.synced)
    let target = (0.8 - 0.49) * span
    if snap {
        #expect(abs(try #require(result.syncPhaseError(.a))) < 0.001)
        #expect(abs(result.a.sourceFrame - target) > 1)
    } else {
        #expect(abs(result.a.sourceFrame - target) < 0.0001)
    }
    await model.finishForShutdown()
}

@Test(arguments: [true, false]) @MainActor
func stoppedWaveformDragParksAtLiftAndZ1StartsThere(synced: Bool) async throws {
    let (model, root, track) = try await loadPlayheadFixture(streaming: true)
    defer { try? FileManager.default.removeItem(at: root) }
    model.load(trackID: track.id, deck: .a)
    await model.playbackLoads?.value
    if !synced { model.toggleSync(deck: .a) }
    let span = track.analysis.sampleRate * 16
    let session = WaveformGestureSession()
    func send(_ phase: SurfaceEvent.Phase, _ x: Double) {
        session.handle(.init(phase: phase, points: [.init(id: 1, x: x, y: 0.5)], ending: phase == .ended ? [1] : []),
                       model: model, deck: .a, span: span)
    }
    send(.began, 0.9)
    send(.moved, 0.2)
    send(.ended, 0.19)
    let target = (0.9 - 0.19) * span
    for buttons: UInt8 in [0, 2, 0x12, 0x12] {
        model.receiveZ1(try performanceZ1Report(buttons: buttons))
    }
    await model.playback.flushSourcePreparations()
    let state = try #require(model.playback.core.snapshot()?.a)
    #expect(state.phase == .playing && !state.touchActive && state.synced == synced)
    #expect(abs(state.sourceFrame - target) < 0.0001)
    #expect(model.playback.core.renderOffline(frames: 4096).left.contains { abs($0) > 0.00001 })
    await model.finishForShutdown()
}
