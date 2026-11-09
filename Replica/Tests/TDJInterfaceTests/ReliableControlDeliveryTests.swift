import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@Test(arguments: ["volume", "master"]) @MainActor
func reliableControlMixerReturnSurvivesQueuePressure(parameterName: String) throws {
    let controller = try PlaybackController(offline: true)
    defer { controller.stopAudio() }
    let core = controller.core
    let asset = try PCMAsset(interleavedStereo: [Float](repeating: 0.4, count: 48000 * 8), sampleRate: 48000)
    let generation = try core.load(asset, deck: .a, grid: nil, synced: false)
    try core.play(deck: .a, generation: generation)
    let parameter: MixerParameter = parameterName == "volume" ? .volume : .master
    try controller.setMixer(parameter, value: 0)
    _ = core.renderOffline(frames: 512)
    for _ in 0..<127 { try core.setMixer(.high, value: 1) }
    try controller.setMixer(parameter, value: 1)
    for _ in 0..<3 {
        _ = core.renderOffline(frames: 512)
        controller.maintainControlState()
    }
    let audio = core.renderOffline(frames: 512)
    let state = try #require(core.snapshot())
    #expect(state.a.phase == .playing)
    #expect((parameter == .volume ? state.a.mixer.volume : state.masterGain) == 1)
    #expect(audio.left.suffix(256).contains { abs($0) > 0.01 })
}

@Test(arguments: [false, true]) @MainActor
func reliableControlWaveformReleaseSurvivesQueuePressure(streaming: Bool) async throws {
    let (model, root, track) = try await loadPlayheadFixture(streaming: streaming)
    defer { try? FileManager.default.removeItem(at: root) }
    model.load(trackID: track.id, deck: .a)
    await model.playbackLoads?.value
    model.pressPlay(deck: .a, vinylStop: false)
    _ = model.playback.core.renderOffline(frames: 512)
    model.refreshPlayback()
    model.performance.waveformScratchAudio = false
    let session = WaveformGestureSession()
    let span = track.analysis.sampleRate * 2
    func send(_ phase: SurfaceEvent.Phase, _ x: Double) {
        session.handle(.init(phase: phase, points: [.init(id: 1, x: x, y: 0.5)],
                             ending: phase == .ended ? [1] : []), model: model, deck: .a, span: span)
    }
    send(.began, 0.5)
    send(.moved, 0.48)
    await model.playback.flushSourcePreparations()
    model.refreshPlayback()
    try #require(model.playbackSnapshot?.a.touchActive == true)
    for _ in 0..<127 { try model.playback.core.setMixer(.high, value: 1) }
    send(.ended, 0.48)
    for _ in 0..<3 {
        _ = model.playback.core.renderOffline(frames: 512)
        model.refreshPlayback()
    }
    await model.playback.flushSourcePreparations()
    model.refreshPlayback()
    let held = try #require(model.playbackSnapshot?.a.sourceFrame)
    _ = model.playback.core.renderOffline(frames: 512)
    model.refreshPlayback()
    #expect(model.playbackSnapshot?.a.touchActive == false)
    #expect(model.playbackSnapshot?.a.synced == true)
    #expect(abs(try #require(model.playbackSnapshot?.syncPhaseError(.a))) < 0.0001)
    #expect(try #require(model.playbackSnapshot?.a.sourceFrame) > held)
    await model.finishForShutdown()
}

@Test @MainActor func reliableControlRetriesIndependentMixerLanesAndEffectOff() throws {
    let controller = try PlaybackController(offline: true)
    let reference = try PlaybackController(offline: true)
    defer { controller.stopAudio(); reference.stopAudio() }
    let asset = try PCMAsset(interleavedStereo: [Float](repeating: 0.4, count: 48000 * 8), sampleRate: 48000)
    let effect = PerformanceEffect.gater.rawValue
    for playback in [controller, reference] {
        let generation = try playback.core.load(asset, deck: .a, grid: nil)
        try playback.core.play(deck: .a, generation: generation)
        try playback.setEffect(effect, slot: 0, x: 0, y: 1, enabled: true, deck: .a)
        _ = playback.core.renderOffline(frames: 512)
        playback.maintainControlState()
    }
    for _ in 0..<127 { try controller.core.setMixer(.high, value: 1) }
    try controller.setMixer(.filterEnabled, value: 1)
    try controller.setEffect(effect, slot: 0, x: 0, y: 0.3, enabled: true, deck: .a)
    try controller.setMixer(.volume, value: 0.8)
    try controller.setMixer(.filterEnabled, value: 0)
    try controller.setEffect(effect, slot: 0, x: 0, y: 1, enabled: false, deck: .a)
    try reference.setMixer(.volume, value: 0.8)
    try reference.setEffect(effect, slot: 0, x: 0, y: 1, enabled: false, deck: .a)
    controller.maintainControlState()
    let audio = controller.core.renderOffline(frames: 1024)
    let expected = reference.core.renderOffline(frames: 1024)
    #expect(audio.left == expected.left && audio.right == expected.right)
    #expect(controller.core.snapshot()?.a.mixer.filterEnabled == false)
    #expect(controller.core.snapshot()?.a.mixer.volume == 0.8)
}

@Test(arguments: [false, true]) @MainActor
func queuedHandoffSurvivesPressureAndCanBeCancelled(cancel: Bool) async throws {
    let (model, root, track) = try await loadPlayheadFixture()
    defer { try? FileManager.default.removeItem(at: root) }
    model.load(trackID: track.id, deck: .a)
    await model.playbackLoads?.value
    model.load(trackID: track.id, deck: .b)
    await model.playbackLoads?.value
    let controller = model.playback
    let core = controller.core
    try controller.play(.a)
    _ = core.renderOffline(frames: 512)
    controller.maintainControlState()
    for _ in 0..<127 { try core.setMixer(.high, value: 1) }
    try controller.play(.b)
    if cancel { try controller.play(.b) }
    await controller.flushSourcePreparations()
    let state = try #require(core.snapshot())
    #expect(state.a.phase == .playing)
    #expect(state.b.phase == (cancel ? .ready : .queued))
    #expect(state.b.synced)
    if !cancel {
        let beat = try #require(state.b.targetBeat)
        let frames = Int(ceil((beat - state.masterBeat) * 60 * state.sampleRate / state.masterBPM))
        _ = core.renderOffline(frames: frames + 512)
        #expect(core.snapshot()?.b.phase == .playing)
    }
    await model.finishForShutdown()
}
