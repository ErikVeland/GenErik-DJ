import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor func loadPlayheadFixture() async throws -> (ReplicaModel, URL, Track) {
    var base = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 { base.deleteLastPathComponent() }
    let source = base.appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/clock-a-120.wav")
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let store = try WorkspaceStore(root: root)
    var analysis = try await AnalysisWorker.shared.waveformOnly(url: source)
    analysis.musicalAnalysisDeferred = false
    var track = try Track(title: "Offset grid", mediaFilename: "clock.wav", analysis: analysis)
    track.preparation.grid = try BeatGrid(
        bpm: 120, anchorFrame: 8 * analysis.sampleRate, sampleRate: analysis.sampleRate)
    track.preparation.gridIsManual = true
    track.preparation.correctedKey = MusicalKey(tonic: 0, mode: .major)
    try FileManager.default.copyItem(at: source, to: store.mediaDirectory.appendingPathComponent(track.mediaFilename))
    var library = LibrarySnapshot()
    library.tracks = [track]
    try store.save(library)
    return (try ReplicaModel(root: root, playback: PlaybackController(offline: true)), root, track)
}

@Test(arguments: DeckID.allCases) @MainActor
func trackLoadShowsFileStartBeforeAndAfterAudioReadiness(deck: DeckID) async throws {
    let (model, root, track) = try await loadPlayheadFixture()
    defer { try? FileManager.default.removeItem(at: root) }
    model.load(trackID: track.id, deck: deck)
    #expect(model.viewport[deck] == 0)
    await model.playbackLoads?.value
    #expect(model.playbackSnapshot?[deck].phase == .ready)
    #expect(model.playbackSnapshot?[deck].sourceFrame == 0)
    #expect(model.viewport[deck] == 0)
    #expect(model.grid(deck)?.anchorFrame == 8 * track.analysis.sampleRate)
    model.refreshPlayback()
    #expect(model.viewport[deck] == 0)
    await model.finishForShutdown()
}

@Test @MainActor func readyDeckWaveformFollowsAudioSeeksWithoutPressingPlay() async throws {
    let (model, root, track) = try await loadPlayheadFixture()
    defer { try? FileManager.default.removeItem(at: root) }
    model.load(trackID: track.id, deck: .a)
    await model.playbackLoads?.value
    model.jump(track.analysis.sampleRate * 3, deck: .a, quantized: false)
    await model.playback.flushSourcePreparations()
    model.refreshPlayback()
    #expect(model.playbackSnapshot?.a.phase == .ready)
    #expect(model.playbackSnapshot?.a.sourceFrame == track.analysis.sampleRate * 3)
    #expect(model.viewport[.a] == track.analysis.sampleRate * 3)
    await model.finishForShutdown()
}

@Test @MainActor func replacingPausedTrackIgnoresItsOldPlayheadWhileLoading() async throws {
    let (model, root, track) = try await loadPlayheadFixture()
    defer { try? FileManager.default.removeItem(at: root) }
    model.load(trackID: track.id, deck: .a)
    await model.playbackLoads?.value
    model.pressPlay(deck: .a, vinylStop: false)
    await model.flushTransportRequests()
    _ = model.playback.core.renderOffline(frames: 96000)
    model.pressPlay(deck: .a, vinylStop: false)
    #expect(model.playbackSnapshot?.a.phase == .paused)
    #expect(try #require(model.playbackSnapshot?.a.sourceFrame) > 0)
    let barrier = AsyncStream<Void>.makeStream()
    model.playbackLoads = Task { for await _ in barrier.stream {} }
    model.load(trackID: track.id, deck: .a)
    model.refreshPlayback()
    #expect(model.preparingPlayback.contains(.a))
    #expect(model.viewport[.a] == 0)
    barrier.continuation.finish()
    await model.playbackLoads?.value
    #expect(model.playbackSnapshot?.a.phase == .ready)
    #expect(model.viewport[.a] == 0)
    await model.finishForShutdown()
}

@Test(arguments: ["preview", "freeze", "grid"]) @MainActor
func readyDeckRetainsDeliberateWaveformView(mode: String) async throws {
    let (model, root, track) = try await loadPlayheadFixture()
    defer { try? FileManager.default.removeItem(at: root) }
    model.load(trackID: track.id, deck: .a)
    await model.playbackLoads?.value
    switch mode {
    case "preview": model.previewing.insert(.a)
    case "freeze": model.frozen.insert(.a)
    default: model.editing.insert(.a)
    }
    model.viewport[.a] = track.analysis.sampleRate * 5
    model.refreshPlayback()
    #expect(model.viewport[.a] == track.analysis.sampleRate * 5)
    #expect(model.playbackSnapshot?.a.sourceFrame == 0)
    await model.finishForShutdown()
}
