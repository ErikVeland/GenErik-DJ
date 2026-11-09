import Foundation
import Testing

@testable import TDJCore
@testable import TDJInterface

@Test(arguments: [false, true]) @MainActor
func persistentSyncGestureKeepsExplicitChoiceAcrossReload(explicitlyOff: Bool) async throws {
    var base = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 { base.deleteLastPathComponent() }
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
    await model.importFiles([base.appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/clock-a-120.wav")])
    let track = try #require(model.library.tracks.first)
    model.load(trackID: track.id, deck: .a)
    await model.flushWrites()
    model.toggleSync(deck: .a)
    if !explicitlyOff { model.toggleSync(deck: .a) }
    model.pressPlay(deck: .a, vinylStop: false)
    await model.flushTransportRequests()
    _ = model.playback.core.renderOffline(frames: 4800)
    model.jump(96000, deck: .a, quantized: false)
    let session = WaveformGestureSession()
    func send(_ phase: SurfaceEvent.Phase, _ x: Double) {
        session.handle(
            .init(phase: phase, points: [.init(id: 1, x: x, y: 0.5)], ending: phase == .began || phase == .moved ? [] : [1]),
            model: model, deck: .a, span: 96000)
    }
    send(.began, 0.5)
    send(.moved, 0.49)
    #expect(model.playbackSnapshot?.a.synced == !explicitlyOff)
    _ = model.playback.core.renderOffline(frames: 256)
    send(explicitlyOff ? .cancelled : .ended, 0.49)
    await model.flushTransportRequests()
    model.refreshPlayback()
    #expect(model.playbackSnapshot?.a.synced == !explicitlyOff)
    #expect(model.playbackSnapshot?.a.touchActive == false)
    if !explicitlyOff { #expect(abs(try #require(model.playbackSnapshot?.syncPhaseError(.a))) < 0.001) }
    session.stopMotion(model: model, deck: .a)
    model.pressPlay(deck: .a, vinylStop: false)
    model.load(trackID: track.id, deck: .a)
    await model.flushWrites()
    #expect(model.playbackSnapshot?.a.synced == !explicitlyOff)
    await model.flushPreferenceWrites()
    let saved = try MixerPreferences.load(from: root.appendingPathComponent("mixer-preferences.json"))
    #expect(saved.syncA == !explicitlyOff)
    await model.finishForShutdown()
}
