import Foundation
import Testing
import TDJCore
@testable import TDJInterface

@MainActor private func instantLoadModel() async throws -> (ReplicaModel, URL, Track) {
    var base = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 { base.deleteLastPathComponent() }
    let source = base.appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/clock-a-120.wav")
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let store = try WorkspaceStore(root: root)
    let analysis = try await AnalysisWorker.shared.waveformOnly(url: source)
    let track = try Track(title: "Instant load", artist: "Fixture", mediaFilename: "clock.wav", analysis: analysis)
    try FileManager.default.copyItem(at: source, to: store.mediaDirectory.appendingPathComponent(track.mediaFilename))
    var library = LibrarySnapshot()
    library.tracks = [track]
    try store.save(library)
    return (try ReplicaModel(root: root, playback: PlaybackController(offline: true)), root, track)
}

@Test @MainActor func instantTrackLoadShowsWaveformBeforeAudioReadiness() async throws {
    let (model, root, track) = try await instantLoadModel()
    defer { try? FileManager.default.removeItem(at: root) }
    let barrier = AsyncStream<Void>.makeStream()
    model.playbackLoads = Task { for await _ in barrier.stream {} }
    model.load(trackID: track.id, deck: .a)
    await model.flushWaveforms()
    #expect(model.preparingPlayback.contains(.a))
    #expect(model.track(.a)?.analysis.waveform.isEmpty == false)
    barrier.continuation.finish()
    await model.flushWrites()
    await model.finishForShutdown()
}

@Test @MainActor func instantTrackLoadQueuesPlayBeforeAnalysisAndKeepsTheAudioGeneration() async throws {
    let (model, root, track) = try await instantLoadModel()
    defer { try? FileManager.default.removeItem(at: root) }
    var reachedAudioBeforeAnalysis = false
    model.playback.loadCheckpoint = { checkpoint in
        if case .decoded = checkpoint {
            reachedAudioBeforeAnalysis = model.track(.a)?.analysis.musicalAnalysisDeferred == true
        }
    }
    model.load(trackID: track.id, deck: .a)
    model.pressPlay(deck: .a)
    #expect(model.playWhenReady.contains(.a))
    await model.flushWrites()
    #expect(reachedAudioBeforeAnalysis)
    #expect(model.playback.core.snapshot()?.a.phase == .playing)
    #expect(model.playWhenReady.isEmpty)
    #expect(model.track(.a)?.analysis.musicalAnalysisDeferred == true)
    let generation = model.playback.generations[.a]
    model.pressPlay(deck: .a, vinylStop: false)
    await model.flushDeckAnalysis()
    #expect(model.track(.a)?.analysis.musicalAnalysisDeferred != true)
    #expect(model.playback.generations[.a] == generation)
    #expect(model.playback.core.snapshot()?.a.phase.active == false)
    await model.finishForShutdown()
}

@Test @MainActor func instantTrackLoadSecondTapCancelsPendingPlay() async throws {
    let (model, root, track) = try await instantLoadModel()
    defer { try? FileManager.default.removeItem(at: root) }
    model.load(trackID: track.id, deck: .b)
    model.pressPlay(deck: .b)
    model.pressPlay(deck: .b)
    #expect(model.playWhenReady.isEmpty)
    await model.flushWrites()
    #expect(model.playback.core.snapshot()?.b.phase == .ready)
    await model.finishForShutdown()
}

@Test @MainActor func instantTrackLoadReplacementClearsPendingPlay() async throws {
    let (model, root, track) = try await instantLoadModel()
    defer { try? FileManager.default.removeItem(at: root) }
    model.load(trackID: track.id, deck: .a)
    model.pressPlay(deck: .a)
    model.load(trackID: track.id, deck: .a)
    #expect(model.playWhenReady.isEmpty)
    await model.flushWrites()
    #expect(model.playback.core.snapshot()?.a.phase == .ready)
    await model.finishForShutdown()
}
