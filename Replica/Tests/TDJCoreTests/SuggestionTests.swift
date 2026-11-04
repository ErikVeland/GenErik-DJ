import Foundation
import Testing

@testable import TDJCore

func syntheticCalibration(id: String = "SYNTHETIC-TEST-ONLY") -> SuggestionCalibration {
    .init(
        id: id, basis: .syntheticDevelopment, referenceCaseIDs: [],
        weights: .init(tempo: 0.2, key: 0.1, timbre: 0.1, genre: 0.1, history: 0.5), tempoRatios: [1],
        tempoDistanceScale: 0.2, tempoCompatibilityDistance: 0.04,
        keyRelations: [.init(from: .init(tonic: 0, mode: .major), to: .init(tonic: 0, mode: .major), score: 1)],
        keyCompatibilityScore: 1, timbreDistanceScale: 1, genreCaseInsensitive: true,
        learningEventWeights: ["transition": 1], minimumTransitionDurationSeconds: 8, symmetricTransitions: false,
        historySaturation: 1, excludeReferenceTrack: true, excludeLoadedTracks: false, tieOrder: .libraryOrder)
}

func syntheticTrack(_ letter: String, bpm: Double) throws -> Track {
    let analysis = AudioAnalysis(
        implementation: "synthetic test", configurationID: "test", contentSHA256: String(repeating: letter, count: 64),
        sampleRate: 44100, frameCount: 441000, channelCount: 2, waveformFramesPerBin: 441, waveform: [], bpm: bpm,
        beatAnchorFrame: 0, tempoConfidence: 1, key: .init(tonic: 0, mode: .major), keyConfidence: 1,
        chroma: Array(repeating: 0, count: 12), timbre: [0.2, 0.8])
    return try Track(title: letter, genre: "House", mediaFilename: letter + ".wav", analysis: analysis)
}

func context(_ library: LibrarySnapshot) -> SuggestionContext {
    .init(
        referenceTrackID: library.tracks[0].id, destination: .b, usePerformanceBPM: false, loadedTrackIDs: [],
        libraryRevision: library.revision, historyRevision: library.adaptiveMemory.revision)
}

@Test func adaptationChangesOrderingAndSurvivesPersistence() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try WorkspaceStore(root: root)
    var library = LibrarySnapshot()
    library.tracks = try [syntheticTrack("a", bpm: 120), syntheticTrack("b", bpm: 120), syntheticTrack("c", bpm: 128)]
    let calibration = syntheticCalibration()
    library.calibration = calibration
    let first = try SuggestionEngine.rank(library: library, context: context(library), calibration: calibration)
    #expect(first.first?.id == library.tracks[1].id)
    let event = PerformanceEvent(
        sessionID: UUID(), kind: .transition, timestamp: Date(timeIntervalSince1970: 0),
        fromTrackID: library.tracks[0].id, toTrackID: library.tracks[2].id, durationSeconds: 30)
    library.events.append(event)
    try library.adaptiveMemory.consume(event, calibration: calibration)
    let learned = try SuggestionEngine.rank(library: library, context: context(library), calibration: calibration)
    #expect(learned.first?.id == library.tracks[2].id)
    #expect(library.adaptiveMemory.strength(from: library.tracks[2].id, to: library.tracks[0].id) == 0)
    try library.adaptiveMemory.consume(event, calibration: calibration)
    #expect(library.adaptiveMemory.revision == 1)
    try store.save(library)
    let reloaded = try store.load()
    #expect(
        try SuggestionEngine.rank(library: reloaded, context: context(reloaded), calibration: calibration) == learned)
    #expect(try AdaptiveMemory.rebuild(events: reloaded.events, calibration: calibration) == reloaded.adaptiveMemory)
}

@Test func loadsPreviewsAndShortTransitionsDoNotTrainUnderSyntheticPolicy() throws {
    var memory = AdaptiveMemory()
    let calibration = syntheticCalibration()
    for kind in [PerformanceEvent.Kind.load, .preview, .transition] {
        try memory.consume(
            .init(
                sessionID: UUID(), kind: kind, timestamp: Date(), fromTrackID: "a", toTrackID: "b", durationSeconds: 2),
            calibration: calibration)
    }
    #expect(memory.strength(from: "a", to: "b") == 0)
    #expect(memory.revision == 0)
    #expect(throws: (any Error).self) {
        try memory.consume(
            .init(
                sessionID: UUID(), kind: .transition, timestamp: Date(), fromTrackID: "a", toTrackID: "b",
                durationSeconds: 30), calibration: syntheticCalibration(id: "changed"))
    }
}

@Test func noDefaultPolicyAndNoStaleRankings() throws {
    var library = LibrarySnapshot()
    library.tracks = try [syntheticTrack("a", bpm: 120), syntheticTrack("b", bpm: 120)]
    let oldContext = context(library)
    #expect(throws: CoreError.calibrationRequired) {
        try SuggestionEngine.rank(library: library, context: oldContext, calibration: nil)
    }
    library.revision += 1
    #expect(throws: CoreError.staleContext) {
        try SuggestionEngine.rank(library: library, context: oldContext, calibration: syntheticCalibration())
    }
}

@Test func genreAndTimbreRemainSeparateAndCorrectionsChangeCompatibility() throws {
    var library = LibrarySnapshot()
    library.tracks = try [syntheticTrack("a", bpm: 120), syntheticTrack("b", bpm: 128)]
    let before = try SuggestionEngine.rank(
        library: library, context: context(library), calibration: syntheticCalibration())
    #expect(before.first?.tempoCompatible == false)
    library.tracks[1].preparation.grid = try BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 44100)
    library.revision += 1
    let corrected = try SuggestionEngine.rank(
        library: library, context: context(library), calibration: syntheticCalibration())
    #expect(corrected.first?.tempoCompatible == true)
    library.tracks[1].genre = "Techno"
    let changed = try SuggestionEngine.rank(
        library: library, context: context(library), calibration: syntheticCalibration())
    #expect(try #require(changed.first).score < #require(corrected.first).score)
    #expect(library.tracks[0].analysis.timbre == library.tracks[1].analysis.timbre)
}

@Test func rawEventsPersistWithoutInventingALearningPolicy() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try WorkspaceStore(root: root)
    let service = try LibraryService(store: store)
    let event = PerformanceEvent(sessionID: UUID(), kind: .load, timestamp: Date(), fromTrackID: "a", toTrackID: "b")
    _ = try await service.record(event)
    _ = try await service.record(event)
    let restored = try store.load()
    #expect(restored.events == [event])
    #expect(restored.adaptiveMemory.calibrationID == nil)
    #expect(restored.adaptiveMemory.revision == 0)
}
