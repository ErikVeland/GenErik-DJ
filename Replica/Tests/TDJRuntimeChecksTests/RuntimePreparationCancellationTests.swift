import Foundation
import Testing

@testable import TDJCore
@testable import TDJInterface
@testable import TDJRuntimeChecks

private final class ImportObservationGate: @unchecked Sendable {
    private let entered = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
    private let released = AsyncStream<Void>.makeStream()
    func hold() async {
        entered.continuation.yield(())
        for await _ in released.stream {}
    }
    func waitUntilEntered() async -> Bool {
        for await _ in entered.stream { return true }
        return false
    }
    func open() {
        entered.continuation.finish()
        released.continuation.finish()
    }
}

private func observationWAV(_ url: URL) throws {
    var data = Data()
    func text(_ value: String) { data.append(contentsOf: value.utf8) }
    func word(_ value: UInt16) {
        var value = value.littleEndian
        withUnsafeBytes(of: &value) { data.append(contentsOf: $0) }
    }
    func long(_ value: UInt32) {
        var value = value.littleEndian
        withUnsafeBytes(of: &value) { data.append(contentsOf: $0) }
    }
    text("RIFF")
    long(36 + 384000)
    text("WAVEfmt ")
    long(16)
    word(1)
    word(2)
    long(48000)
    long(192000)
    word(4)
    word(16)
    text("data")
    long(384000)
    data.append(Data(count: 384000))
    try data.write(to: url)
}

@MainActor private func observationFixture(controllerOwnsLoads: Bool = true) async throws -> (
    model: ReplicaModel, root: URL, track: Track, grids: [DeckID: BeatGrid], generations: [DeckID: UInt64],
    collections: [RuntimePreparationCollection]
) {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let store = try WorkspaceStore(root: root)
    let source = store.mediaDirectory.appendingPathComponent("observation.wav")
    try observationWAV(source)
    let analysis = AudioAnalysis(
        implementation: "Synthetic observation fixture", configurationID: "observation-fixture",
        contentSHA256: try AudioAnalyzer.sha256(url: source), sampleRate: 48000, frameCount: 96000, channelCount: 2,
        waveformFramesPerBin: 512, waveform: (0..<188).map { _ in WaveformBin(minimum: 0, maximum: 0, rms: 0) },
        bpm: 110, beatAnchorFrame: 0, tempoConfidence: 0, key: nil, keyConfidence: 0, chroma: [], timbre: [])
    var track = try Track(title: "Synthetic observation", mediaFilename: "observation.wav", analysis: analysis)
    track.musicLibrarySources = [.init(platform: .iosMusic, persistentID: "4660")]
    var library = LibrarySnapshot()
    library.tracks = [track]
    _ = try store.save(library)
    let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
    track = try #require(model.library.tracks.first)
    if controllerOwnsLoads {
        for deck in DeckID.allCases { model.load(trackID: track.id, deck: deck) }
        await model.playbackLoads?.value
        for deck in DeckID.allCases {
            try model.playback.setSync(false, deck: deck)
            model.pressPlay(deck: deck)
        }
    } else {
        let asset = try PCMAsset(interleavedStereo: [Float](repeating: 0, count: 192000), sampleRate: 48000)
        for deck in DeckID.allCases {
            let generation = try model.playback.core.load(asset, deck: deck, grid: track.grid, synced: false)
            model.playback.core.processControlsWhileIdle()
            try model.playback.core.play(deck: deck, generation: generation)
            model.playback.core.processControlsWhileIdle()
            model.loaded[deck] = track.id
        }
    }
    _ = model.playback.core.renderOffline(frames: 256)
    let state = try #require(model.playback.core.snapshot())
    let grids = Dictionary(
        uniqueKeysWithValues: DeckID.allCases.compactMap { deck in state[deck].grid.map { (deck, $0) } })
    try #require(grids.count == 2 && state.a.phase == .playing && state.b.phase == .playing)
    let generations = Dictionary(uniqueKeysWithValues: DeckID.allCases.map { ($0, state[$0].generation) })
    let collections = try RuntimePreparationImportStress.prepareCollections(directory: root, duration: 2, entries: 1)
    return (model, root, track, grids, generations, collections)
}

@Test(arguments: ["unchanged", "analysis", "native-grid", "saved-grid"]) @MainActor
func preparationImportCancellationStillObservesTheLastState(_ mutation: String) async throws {
    let f = try await observationFixture()
    let gate = ImportObservationGate()
    defer {
        gate.open()
        try? FileManager.default.removeItem(at: f.root)
    }
    var prior = RuntimePreparationImportReport(entriesPerCollection: 1)
    await RuntimePreparationImportStress.importOnce(
        model: f.model, collection: f.collections[0], track: f.track, expectedGrids: f.grids, report: &prior)
    try #require(prior.passed && prior.completedImports == 1)
    let task = Task { @MainActor in
        await gate.hold()
        var report = prior
        await RuntimePreparationImportStress.importOnce(
            model: f.model, collection: f.collections[1], track: f.track, expectedGrids: f.grids, report: &report)
        return report
    }
    try #require(await gate.waitUntilEntered())
    switch mutation {
    case "analysis":
        let source = f.model.store.mediaDirectory.appendingPathComponent(f.track.mediaFilename)
        f.model.library.tracks[0].analysis = try AudioAnalyzer.waveformOnly(url: source)
    case "native-grid": try f.model.playback.updateGrid(BeatGrid(bpm: 117, anchorFrame: 0, sampleRate: 48000), deck: .a)
    case "saved-grid":
        f.model.saveGrid(try BeatGrid(bpm: 117, anchorFrame: 0, sampleRate: 48000), deck: .a)
        await f.model.preparationWrites?.value
    default: break
    }
    f.model.importing = true
    task.cancel()
    gate.open()
    let report = await task.value
    f.model.importing = false
    #expect(report.passed == (mutation == "unchanged"))
    #expect(report.completedImports == 1 && report.referencesBound == 1)
    if mutation == "analysis" {
        #expect(!report.fullAnalysisRetained)
    } else if mutation != "unchanged" {
        #expect(!report.activePreparationUnchanged)
    }
    await f.model.finishForShutdown()
}

@Test(arguments: ["generation", "empty-grids", "partial-grids", "empty-generations", "partial-generations", "paused"])
@MainActor func preparationImportFinalObservationRejectsChangedOwnershipOrMissingExpectations(_ mutation: String)
    async throws
{
    let f = try await observationFixture()
    defer { try? FileManager.default.removeItem(at: f.root) }
    var report = RuntimePreparationImportReport(entriesPerCollection: 1)
    await RuntimePreparationImportStress.importOnce(
        model: f.model, collection: f.collections[0], track: f.track, expectedGrids: f.grids, report: &report)
    try #require(report.passed)
    var grids = f.grids
    var generations = f.generations
    switch mutation {
    case "generation":
        let core = f.model.playback.core
        try core.play(deck: .a, generation: try #require(f.generations[.a]))
        core.processControlsWhileIdle()
        let asset = try PCMAsset(interleavedStereo: [Float](repeating: 0, count: 192000), sampleRate: 48000)
        let replacement = try core.load(asset, deck: .a, grid: f.grids[.a], synced: false)
        core.processControlsWhileIdle()
        try core.play(deck: .a, generation: replacement)
        core.processControlsWhileIdle()
        let state = try #require(core.snapshot())
        try #require(state.a.phase == .playing && state.a.grid == f.grids[.a])
        try #require(state.a.generation != f.generations[.a])
    case "paused":
        try f.model.playback.core.play(deck: .a, generation: try #require(f.generations[.a]))
        f.model.playback.core.processControlsWhileIdle()
        try #require(f.model.playback.core.snapshot()?.a.phase == .paused)
    case "empty-grids": grids = [:]
    case "partial-grids": grids[.b] = nil
    case "partial-generations": generations[.b] = nil
    default: generations = [:]
    }
    RuntimePreparationImportStress.observe(
        model: f.model, track: f.track, expectedGrids: grids, expectedGenerations: generations, report: &report)
    #expect(!report.activePreparationUnchanged && !report.passed)
    #expect(report.fullAnalysisRetained)
    #expect(report.completedImports == 1 && report.referencesBound == 1)
    await f.model.finishForShutdown()
}

@Test @MainActor func preparationImportCancelledBeforeWorkCannotPass() async throws {
    let f = try await observationFixture()
    let gate = ImportObservationGate()
    defer {
        gate.open()
        try? FileManager.default.removeItem(at: f.root)
    }
    let task = Task { @MainActor in
        await gate.hold()
        return await RuntimePreparationImportStress.run(
            model: f.model, collections: f.collections, track: f.track, expectedGrids: f.grids,
            expectedGenerations: f.generations)
    }
    try #require(await gate.waitUntilEntered())
    task.cancel()
    gate.open()
    let report = await task.value
    #expect(report.completedImports == 0 && !report.passed)
    #expect(report.activePreparationUnchanged && report.fullAnalysisRetained)
    await f.model.finishForShutdown()
}

@Test @MainActor func preparationImportFinalObservationCannotRestoreAnEarlierFailure() async throws {
    let f = try await observationFixture()
    defer { try? FileManager.default.removeItem(at: f.root) }
    var report = RuntimePreparationImportReport(entriesPerCollection: 1)
    report.completedImports = 1
    report.referencesBound = 1
    report.activePreparationUnchanged = false
    report.fullAnalysisRetained = false
    RuntimePreparationImportStress.observe(
        model: f.model, track: f.track, expectedGrids: f.grids, expectedGenerations: f.generations, report: &report)
    #expect(!report.passed && !report.activePreparationUnchanged && !report.fullAnalysisRetained)
    await f.model.finishForShutdown()
}

@Test @MainActor func preparationImportMissingControllerGenerationsCannotQualify() async throws {
    let f = try await observationFixture(controllerOwnsLoads: false)
    defer { try? FileManager.default.removeItem(at: f.root) }
    var report = RuntimePreparationImportReport(entriesPerCollection: 1)
    report.completedImports = 1
    report.referencesBound = 1
    for deck in DeckID.allCases {
        try #require(f.model.track(deck)?.grid == f.grids[deck])
        try #require(f.model.playback.core.snapshot()?[deck].grid == f.grids[deck])
        try #require(f.model.playback.generations[deck] == nil)
    }
    #expect(RuntimePreparationImportStress.generations(model: f.model).isEmpty)
    RuntimePreparationImportStress.observe(
        model: f.model, track: f.track, expectedGrids: f.grids, expectedGenerations: f.generations, report: &report)
    #expect(!report.activePreparationUnchanged && !report.passed)
    #expect(report.fullAnalysisRetained)
    await f.model.finishForShutdown()
}
