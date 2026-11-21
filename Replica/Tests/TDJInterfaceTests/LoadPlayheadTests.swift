import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor func loadPlayheadFixture(streaming: Bool = false) async throws -> (ReplicaModel, URL, Track) {
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
    return (try ReplicaModel(root: root, playback: PlaybackController(offline: true, streamingPlayback: streaming)), root, track)
}

@Test(arguments: DeckID.allCases) @MainActor
func trackLoadCentresFirstBarButAudioStaysAtFileStart(deck: DeckID) async throws {
    let (model, root, track) = try await loadPlayheadFixture()
    defer { try? FileManager.default.removeItem(at: root) }
    model.load(trackID: track.id, deck: deck)
    #expect(model.viewport[deck] == 0)
    await model.playbackLoads?.value
    #expect(model.playbackSnapshot?[deck].phase == .ready)
    let firstBar = 8 * track.analysis.sampleRate
    #expect(model.playbackSnapshot?[deck].sourceFrame == 0)
    #expect(model.viewport[deck] == firstBar)
    #expect(model.grid(deck)?.anchorFrame == firstBar)
    model.refreshPlayback()
    #expect(model.viewport[deck] == firstBar)
    model.pressPlay(deck: deck, vinylStop: false)
    await model.flushTransportRequests()
    _ = model.playback.core.renderOffline(frames: 512)
    model.refreshPlayback()
    #expect(model.viewport[deck] == model.playbackSnapshot?[deck].sourceFrame)
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
    #expect(model.playbackSnapshot?.a.sourceFrame == 0)
    #expect(model.viewport[.a] == 8 * track.analysis.sampleRate)
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

@Test @MainActor func clonedTrackRetainsItsDeliberateCursor() async throws {
    let (model, root, track) = try await loadPlayheadFixture()
    defer { try? FileManager.default.removeItem(at: root) }
    model.load(trackID: track.id, deck: .a)
    await model.playbackLoads?.value
    let cursor = 3 * track.analysis.sampleRate
    model.jump(cursor, deck: .a, quantized: false)
    await model.playback.flushSourcePreparations()
    model.refreshPlayback()
    model.cloneTrackDeck(from: .a, to: .b)
    await model.playbackLoads?.value
    #expect(model.playbackSnapshot?.b.sourceFrame == cursor)
    #expect(model.viewport[.b] == cursor)
    #expect(model.loadedWaveformPresentations[.b] == nil)
    await model.finishForShutdown()
}

@Test func firstBarLoadPresentationUsesRealGridAndExpiresOnTransportChange() throws {
    let grid = try BeatGrid(bpm: 120, anchorFrame: 48_000, sampleRate: 48_000, downbeatOffset: 1)
    let timing = BeatTiming(fixed: grid)
    let pin = try #require(LoadedWaveformPresentation(
        generation: 8, phase: .ready, sourceFrame: 0, timing: timing, frameCount: 160_000))
    #expect(pin.center == 72_000)
    #expect(pin.holds(generation: 8, phase: .ready, sourceFrame: 0))
    #expect(!pin.holds(generation: 8, phase: .playing, sourceFrame: 0))
    #expect(!pin.holds(generation: 9, phase: .ready, sourceFrame: 0))
    #expect(!pin.holds(generation: 8, phase: .paused, sourceFrame: 100))
    #expect(LoadedWaveformPresentation(
        generation: 8, phase: .ready, sourceFrame: 0, timing: nil, frameCount: 160_000) == nil)
    let map = BeatGridMap(
        anchors: [.init(beat: 0, frame: 1_500), .init(beat: 4, frame: 111_000)], sampleRate: 48_000,
        downbeatOffset: 2)
    let flex = try #require(LoadedWaveformPresentation(
        generation: 9, phase: .paused, sourceFrame: 0,
        timing: BeatTiming(fixed: grid, adaptive: map), frameCount: 150_000))
    #expect(flex.center == 56_250)
}
