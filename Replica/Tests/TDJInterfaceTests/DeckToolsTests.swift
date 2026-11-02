import Foundation
import Testing
import TDJCore
@testable import TDJInterface

@MainActor private func loadedClockModel() async throws -> (ReplicaModel, URL, Track) {
    var base = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 { base.deleteLastPathComponent() }
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
    await model.importFiles([base.appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/clock-a-120.wav")])
    let track = try #require(model.library.tracks.first)
    model.load(trackID: track.id, deck: .a); await model.flushWrites()
    return (model, root, track)
}

@Test func loopStepperRunsFromOneThirtySecondToThirtyTwoBeats() {
    let sizes = PerformancePreparation.loopSizes
    #expect(sizes.first == 1.0 / 32 && sizes.last == 32 && sizes.count == 11)
    #expect(zip(sizes, sizes.dropFirst()).allSatisfy { $1 == $0 * 2 })
    #expect(PerformancePreparation.steppedLoopSize(from: 4, direction: 1) == 8)
    #expect(PerformancePreparation.steppedLoopSize(from: 4, direction: -1) == 2)
    #expect(PerformancePreparation.steppedLoopSize(from: 32, direction: 1) == 32)
    #expect(PerformancePreparation.steppedLoopSize(from: 1.0 / 32, direction: -1) == 1.0 / 32)
    #expect(PerformancePreparation.loopSizeLabel(0.0625) == "1/16" && PerformancePreparation.loopSizeLabel(32) == "32")
}

@Test @MainActor func loopStepperChangesTheDeckLoopSize() async throws {
    let (model, root, _) = try await loadedClockModel()
    defer { try? FileManager.default.removeItem(at: root) }
    model.setLoopSize(4, deck: .a)
    model.stepLoopSize(direction: -1, deck: .a)
    #expect(model.performance.loopBeats(for: .a) == 2)
    for _ in 0..<10 { model.stepLoopSize(direction: -1, deck: .a) }
    #expect(model.performance.loopBeats(for: .a) == 1.0 / 32)
}

@Test @MainActor func beatJumpMovesWholeBeatsFromThePlayhead() async throws {
    let (model, root, _) = try await loadedClockModel()
    defer { try? FileManager.default.removeItem(at: root) }
    let grid = try #require(model.grid(.a))
    let start = try #require(model.playbackSnapshot?.a.sourceFrame)
    model.beatJump(beats: 4, deck: .a)
    let after = try #require(model.playbackSnapshot?.a.sourceFrame)
    #expect(abs(after - (start + 4 * grid.framesPerBeat)) < 1)
    model.beatJump(beats: -2, deck: .a)
    #expect(abs((model.playbackSnapshot?.a.sourceFrame ?? 0) - (start + 2 * grid.framesPerBeat)) < 1)
}

@Test @MainActor func tempoFaderSetsUnsyncedDeckSpeed() async throws {
    let (model, root, _) = try await loadedClockModel()
    defer { try? FileManager.default.removeItem(at: root) }
    if model.playbackSnapshot?.a.synced == true { model.toggleSync(deck: .a) }
    model.setDeckTempo(percent: 4, deck: .a)
    #expect(abs(model.deckTempoPercent(deck: .a) - 4) < 0.01)
    model.setDeckTempo(percent: 0, deck: .a)
    #expect(abs(model.deckTempoPercent(deck: .a)) < 0.01)
}

private func entry(_ id: String, bpm: Double?, key: MusicalKey?) -> LibraryBrowserEntry {
    LibraryBrowserEntry(nativeItem: .init(source: .init(platform: .iosMusic, persistentID: id), title: id, artist: "",
                                          duration: 200, assetURL: nil, availability: .notDownloaded),
                        hint: .init(bpm: bpm, key: key, isMix: false))
}

@Test func collectionOnlySeedGivesRecommendationsAndExcludesLoadedTracks() {
    let seed = entry("seed", bpm: 128, key: .init(tonic: 9, mode: .minor))
    let library = [entry("a", bpm: 127, key: .init(tonic: 9, mode: .minor)), entry("loaded", bpm: 128, key: nil), entry("far", bpm: 90, key: nil)]
    let matches = BrowserRecommendations.matches(for: seed, in: library, excluding: [library[1].id])
    #expect(matches.map(\.entry.title) == ["a"])
}

@Test func seedWithoutKeyFallsBackToTempoAndWithoutTempoToKey() {
    let noKey = entry("seed", bpm: 120, key: nil)
    let library = [entry("x", bpm: 121, key: .init(tonic: 0, mode: .major)), entry("y", bpm: 60, key: nil), entry("z", bpm: 140, key: nil)]
    #expect(Set(BrowserRecommendations.matches(for: noKey, in: library).map(\.entry.title)) == ["x", "y"])
    let noTempo = entry("seed2", bpm: nil, key: .init(tonic: 0, mode: .major))
    #expect(BrowserRecommendations.matches(for: noTempo, in: library).map(\.entry.title) == ["x"])
}

@Test @MainActor func recommendationSeedFollowsLoadingAndPlaying() async throws {
    let (model, root, track) = try await loadedClockModel()
    defer { try? FileManager.default.removeItem(at: root) }
    #expect(model.recommendationSeedDeck(destination: nil) == .a)
    #expect(model.lastLoadedDeck == .a)
    #expect(model.recommendationSeed(deck: .a)?.bpm.map { abs($0 - 120) < 0.5 } == true)
    // Suggesting for deck B uses deck A as the reference; suggesting for A has no reference yet.
    #expect(model.recommendationSeedDeck(destination: .b) == .a)
    #expect(model.recommendationSeedDeck(destination: .a) == nil)
    model.load(trackID: track.id, deck: .b); await model.flushWrites()
    #expect(model.recommendationSeedDeck(destination: nil) == .b)
}

@Test func sortMenuOrdersByCollectionTempoAndKey() async throws {
    let catalog = MusicLibraryCatalog(items: ["slow", "fast", "mid"].map {
        MusicLibraryItem(source: .init(platform: .iosMusic, persistentID: $0), title: $0, artist: "", duration: 200,
                         assetURL: nil, availability: .notDownloaded)
    }, playlists: [])
    let hints = ["ios:slow": BrowserPreparationHint(bpm: 90, key: nil, isMix: false)]
        .merging(Dictionary(uniqueKeysWithValues: catalog.items.map { ($0.id, BrowserPreparationHint(bpm: ["slow": 90.0, "fast": 140, "mid": 120][$0.title]!, key: nil, isMix: false)) })) { $1 }
    let byBPM = try await LibraryBrowserProjection.build(tracks: [], suggestionIDs: nil, search: "", sort: .bpm, category: .songs, group: nil,
                                                         playlists: .init(), catalog: catalog, hints: hints)
    #expect(byBPM.entries.map(\.title) == ["slow", "mid", "fast"])
    #expect(CollectionSort.allCases.map(\.rawValue) == ["Title", "Artist", "Album", "Key", "BPM"])
}
