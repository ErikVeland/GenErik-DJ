import Foundation
import Testing

@testable import TDJCore
@testable import TDJInterface

@Test @MainActor func tempoWheelDoubleTapResetsThePlayingReferenceAndSyncedFollower() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true, sampleRate: 8000))
    let core = model.playback.core
    let asset = try PCMAsset(interleavedStereo: [Float](repeating: 0, count: 128000), sampleRate: 8000)
    let a = try core.load(asset, deck: .a, grid: BeatGrid(bpm: 123.45, anchorFrame: 0, sampleRate: 8000))
    let b = try core.load(asset, deck: .b, grid: BeatGrid(bpm: 128, anchorFrame: 0, sampleRate: 8000))
    core.processControlsWhileIdle()
    try core.play(deck: .b, generation: b)
    core.processControlsWhileIdle()
    _ = core.renderOffline(frames: 1000)
    try core.play(deck: .a, generation: a)
    _ = core.renderOffline(frames: 15000)
    model.setMasterBPM(140)
    let before = try #require(core.snapshot())
    let session = TempoWheelGestureSession()
    let point = SurfacePoint(id: 1, x: 0.8, y: 0.5)
    for time in [1.0, 1.2] {
        for phase in [SurfaceEvent.Phase.began, .ended] {
            session.handle(
                .init(phase: phase, points: [point], ending: phase == .ended ? [1] : []), width: 168, height: 168,
                bpm: 140, at: time, resetTempo: { model.resetMasterTempo() }, change: { model.setMasterBPM($0) })
        }
    }
    let reset = try #require(core.snapshot())
    #expect(reset.masterBPM == 128)
    #expect(reset.b.speed == 1)
    #expect(abs(reset.a.speed - 128 / 123.45) < 0.000001)
    #expect(reset.masterBeat == before.masterBeat)
    #expect(reset.a.sourceFrame == before.a.sourceFrame && reset.b.sourceFrame == before.b.sourceFrame)
    try core.play(deck: .b, generation: b)
    core.processControlsWhileIdle()
    model.resetMasterTempo()
    #expect(core.snapshot()?.masterBPM == 123.45)
    #expect(core.snapshot()?.a.speed == 1)
}

@Test @MainActor func tempoWheelTapRecognitionRejectsDragsHoldsCancellationAndExtraContacts() {
    for mode in ["single", "drag", "hold", "cancel", "multitouch", "late", "distant"] {
        let session = TempoWheelGestureSession()
        var resets = 0
        var bpm = 140.0
        let point = SurfacePoint(id: 1, x: 0.8, y: 0.5)
        func send(_ phase: SurfaceEvent.Phase, _ time: Double, _ points: [SurfacePoint], ending: Set<Int> = []) {
            session.handle(
                .init(phase: phase, points: points, ending: ending), width: 168, height: 168, bpm: bpm, at: time,
                resetTempo: { resets += 1 }, change: { bpm = $0 })
        }
        send(.began, 1, [point])
        if mode == "drag" {
            send(.moved, 1.05, [.init(id: 1, x: 0.5, y: 0.8)])
            send(.moved, 1.08, [point])
        }
        if mode == "multitouch" { send(.began, 1.05, [point, .init(id: 2, x: 0.2, y: 0.5)]) }
        send(mode == "cancel" ? .cancelled : .ended, mode == "hold" ? 1.6 : 1.1, [point], ending: [1, 2])
        if mode != "single" {
            let next = SurfacePoint(id: 3, x: mode == "distant" ? 0.2 : 0.8, y: 0.5)
            let time = mode == "hold" ? 1.7 : mode == "late" ? 2 : 1.2
            send(.began, time, [next])
            send(.ended, time + 0.05, [next], ending: [3])
        }
        #expect(resets == 0, "Unexpected reset after \(mode)")
    }
}

@Test @MainActor func tempoWheelCentreDoubleTapResetsOnceAndCancellationClearsHistory() {
    let session = TempoWheelGestureSession()
    var resets = 0
    let point = SurfacePoint(id: 1, x: 0.5, y: 0.5)
    func tap(_ time: Double) {
        for phase in [SurfaceEvent.Phase.began, .ended] {
            session.handle(
                .init(phase: phase, points: [point], ending: phase == .ended ? [1] : []), width: 168, height: 168,
                bpm: 140, at: time, resetTempo: { resets += 1 }, change: { _ in })
        }
    }
    tap(1)
    tap(1.2)
    tap(1.3)
    #expect(resets == 1)
    session.handle(
        .init(phase: .cancelled, points: [], ending: []), width: 168, height: 168, bpm: 140, at: 1.4,
        resetTempo: { resets += 1 }, change: { _ in })
    tap(1.5)
    #expect(resets == 1)
}

@Test @MainActor func tempoWheelResetWithoutASyncedTrackLeavesTempoAlone() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true, sampleRate: 8000))
    model.setMasterBPM(137)
    model.resetMasterTempo()
    #expect(model.playbackSnapshot?.masterBPM == 137)
    let core = model.playback.core
    let generation = try core.load(
        PCMAsset(interleavedStereo: [Float](repeating: 0, count: 32000), sampleRate: 8000), deck: .b,
        grid: BeatGrid(bpm: 126, anchorFrame: 0, sampleRate: 8000))
    core.processControlsWhileIdle()
    model.resetMasterTempo()
    #expect(core.snapshot()?.masterBPM == 126)
    try core.setSync(false, deck: .b, generation: generation)
    core.processControlsWhileIdle()
    model.setMasterBPM(137)
    model.resetMasterTempo()
    #expect(core.snapshot()?.masterBPM == 137)
}

@Test(arguments: [true, false]) @MainActor func trackLoadResetsMasterTempoOnlyWhileIdle(synced: Bool) async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try WorkspaceStore(root: root)
    let playback = try PlaybackController(offline: true, sampleRate: 8000)
    let asset = try PCMAsset(interleavedStereo: [Float](repeating: 0, count: 32000), sampleRate: 8000)

    func track(bpm: Double?) throws -> Track {
        let analysis = AudioAnalysis(
            implementation: "tempo-fixture", configurationID: "fixture", contentSHA256: "fixture",
            sampleRate: 8000, frameCount: 16000, channelCount: 2, waveformFramesPerBin: 80, waveform: [],
            bpm: bpm, beatAnchorFrame: 0, tempoConfidence: 1, key: nil, keyConfidence: 0, chroma: [], timbre: [])
        return try Track(title: "Tempo fixture", mediaFilename: "fixture.wav", analysis: analysis)
    }

    try await playback.load(track: track(bpm: 112), store: store, deck: .a, preparedAsset: asset, synced: synced)
    #expect(playback.core.snapshot()?.masterBPM == 112)
    try playback.play(.a)
    try playback.setMasterBPM(116)
    try await playback.load(track: track(bpm: 128), store: store, deck: .b, preparedAsset: asset, synced: synced)
    #expect(playback.core.snapshot()?.masterBPM == 116)
    #expect(playback.core.snapshot()?.a.phase == .playing)

    try playback.play(.a)
    try await playback.load(track: track(bpm: 126), store: store, deck: .b, preparedAsset: asset, synced: synced)
    #expect(playback.core.snapshot()?.masterBPM == 126)
    #expect(playback.core.snapshot()?.b.speed == 1)

    try await playback.load(track: track(bpm: nil), store: store, deck: .a, preparedAsset: asset, synced: synced)
    #expect(playback.core.snapshot()?.masterBPM == 126)
    try playback.play(.b)
    #expect(playback.core.snapshot()?.masterBPM == 126)
}
