import Foundation
import Testing

@testable import TDJCore

private func rankedTrack(_ id: String, bpm: Double, key: MusicalKey?, level: Float) throws -> Track {
    let analysis = AudioAnalysis(
        implementation: "test", configurationID: "test", contentSHA256: String(repeating: id, count: 64),
        sampleRate: 48000, frameCount: 480000, channelCount: 2, waveformFramesPerBin: 4800,
        waveform: Array(repeating: .init(minimum: -level, maximum: level, rms: level), count: 100), bpm: bpm,
        beatAnchorFrame: 0, tempoConfidence: 1, key: key, keyConfidence: 1, chroma: [],
        timbre: Array(repeating: 0, count: 7))
    return try Track(title: id, mediaFilename: id + ".wav", analysis: analysis)
}
private func performerContext(_ library: LibrarySnapshot, tempo: Double? = nil) -> SuggestionContext {
    .init(
        referenceTrackID: library.tracks[0].id, destination: .b, performanceBPM: tempo, usePerformanceBPM: tempo != nil,
        loadedTrackIDs: [], libraryRevision: library.revision, historyRevision: library.adaptiveMemory.revision)
}

@Test func backgroundSuggestionsPreserveTheConfirmedPriorityOrder() async throws {
    var library = LibrarySnapshot()
    let key = MusicalKey(tonic: 0, mode: .major)
    library.tracks = try [
        rankedTrack("a", bpm: 120, key: key, level: 0.1), rankedTrack("b", bpm: 128, key: key, level: 0.1),
        rankedTrack("c", bpm: 140, key: key, level: 0.7),
    ]
    let context = performerContext(library)
    let expected = try PerformerSuggestions.rank(library: library, context: context)
    let actual = try await PerformerSuggestions.rankAsync(library: library, context: context)
    #expect(actual.map(\.id) == expected.map(\.id))
    #expect(actual.map(\.tempoCompatible) == expected.map(\.tempoCompatible))
}

@Test func performerPrioritiesCannotBeOverriddenByLowerCriteria() throws {
    let key = MusicalKey(tonic: 0, mode: .major)
    var library = LibrarySnapshot()
    library.tracks = try [
        rankedTrack("a", bpm: 120, key: key, level: 0.1), rankedTrack("b", bpm: 180, key: key, level: 0.7),  // Exact key wins despite tempo and energy.
        rankedTrack("c", bpm: 120, key: .init(tonic: 7, mode: .major), level: 0.1),
        rankedTrack("d", bpm: 125, key: key, level: 0.7),  // In range wins over better energy outside range.
        rankedTrack("e", bpm: 140, key: key, level: 0.1), rankedTrack("f", bpm: 125, key: key, level: 0.1),  // Similar energy wins within tempo range.
    ]
    library.events = [
        .init(
            sessionID: UUID(), kind: .transition, timestamp: Date(), fromTrackID: library.tracks[0].id,
            toTrackID: library.tracks[3].id)
    ]
    let ranked = try PerformerSuggestions.rank(library: library, context: performerContext(library))
    #expect(ranked.map(\.id) == [5, 3, 4, 1, 2].map { library.tracks[$0].id })
}

@Test func eightPercentBoundsAndCurrentPerformanceTempoAreUsed() throws {
    var library = LibrarySnapshot()
    let key = MusicalKey(tonic: 0, mode: .major)
    library.tracks = try [
        rankedTrack("a", bpm: 120, key: key, level: 0.1), rankedTrack("b", bpm: 110.4, key: key, level: 0.1),
        rankedTrack("c", bpm: 129.6, key: key, level: 0.1), rankedTrack("d", bpm: 129.61, key: key, level: 0.1),
    ]
    let normal = try PerformerSuggestions.rank(library: library, context: performerContext(library))
    #expect(normal.map(\.tempoCompatible) == [true, true, false])
    let faster = try PerformerSuggestions.rank(library: library, context: performerContext(library, tempo: 140))
    #expect(faster.first?.id == library.tracks[2].id)
    #expect(faster.last?.id == library.tracks[1].id)
}

@Test func priorPairingBreaksTiesInEitherDirectionAndSurvivesRestart() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    var library = LibrarySnapshot()
    let key = MusicalKey(tonic: 9, mode: .minor)
    library.tracks = try [
        rankedTrack("a", bpm: 120, key: key, level: 0.1), rankedTrack("b", bpm: 120, key: key, level: 0.1),
        rankedTrack("c", bpm: 126, key: key, level: 0.1),
    ]
    library.events = [
        .init(
            sessionID: UUID(), kind: .preview, timestamp: Date(), fromTrackID: library.tracks[0].id,
            toTrackID: library.tracks[2].id)
    ]
    #expect(
        try PerformerSuggestions.rank(library: library, context: performerContext(library)).first?.id
            == library.tracks[1].id)
    library.events.append(
        .init(
            sessionID: UUID(), kind: .transition, timestamp: Date(), fromTrackID: library.tracks[2].id,
            toTrackID: library.tracks[0].id))
    let store = try WorkspaceStore(root: root)
    try store.save(library)
    let restored = try store.load()
    #expect(
        try PerformerSuggestions.rank(library: restored, context: performerContext(restored)).first?.id
            == library.tracks[2].id)
}

@Test func unavailableAnalysisIsNotFabricatedAndCorrectedKeyWins() throws {
    #expect(
        PerformerSuggestions.keyTier(reference: .init(tonic: 0, mode: .major), candidate: .init(tonic: 9, mode: .minor))
            == 1)
    #expect(PerformerSuggestions.keyTier(reference: .init(tonic: 0, mode: .major), candidate: nil) == 3)
    var library = LibrarySnapshot()
    library.tracks = try [
        rankedTrack("a", bpm: 120, key: .init(tonic: 0, mode: .major), level: 0.1),
        rankedTrack("b", bpm: 120, key: nil, level: 0),
        rankedTrack("c", bpm: 120, key: .init(tonic: 7, mode: .major), level: 0.1),
    ]
    #expect(PerformerSuggestions.energyLevel(library.tracks[1].analysis) == nil)
    library.tracks[1].preparation.correctedKey = .init(tonic: 0, mode: .major)
    #expect(
        try PerformerSuggestions.rank(library: library, context: performerContext(library)).first?.id
            == library.tracks[1].id)
}

@Test func backgroundCollectionPreservesSearchGroupsAndSuggestionOrder() async throws {
    var a = try rankedTrack("a", bpm: 120, key: nil, level: 0.1)
    var b = try rankedTrack("b", bpm: 128, key: nil, level: 0.1)
    a.artist = "One"
    a.album = "First"
    b.artist = "Two"
    b.album = "Second"
    let tracks = [b, a]
    let albums = try await CollectionProjection.build(
        tracks: tracks, suggestionIDs: nil, search: "One First", sort: .title, category: .albums, group: "First",
        playlists: .init(), catalog: nil)
    #expect(albums.tracks.map(\.id) == [a.id])
    #expect(albums.groups.map(\.name) == ["First", "Second"])
    #expect(CollectionBrowser.tracks(tracks, search: "", sort: .album).map(\.id) == [a.id, b.id])
    let suggestions = try await CollectionProjection.build(
        tracks: tracks, suggestionIDs: [b.id, a.id], search: "", sort: .title, category: .albums, group: "First",
        playlists: .init(), catalog: nil)
    #expect(suggestions.tracks.map(\.id) == [b.id, a.id])
    var playlists = CollectionPlaylists()
    try playlists.add(trackIDs: [b.id, a.id], to: nil, name: "Set")
    let selected = try await CollectionProjection.build(
        tracks: tracks, suggestionIDs: nil, search: "Two", sort: .title, category: .playlists,
        group: playlists.playlists[0].id.uuidString, playlists: playlists, catalog: nil)
    #expect(selected.tracks.map(\.id) == [b.id])
}
