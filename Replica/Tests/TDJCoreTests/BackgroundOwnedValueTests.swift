import Foundation
import Testing
@testable import TDJCore

private func ownedValueTrack(_ number: Int) throws -> Track {
    let analysis = AudioAnalysis(implementation: "owned-input", configurationID: "owned-input",
        contentSHA256: String(format: "%064x", number), sampleRate: 48000, frameCount: 480000,
        channelCount: 2, waveformFramesPerBin: 512, waveform: [], bpm: 120, beatAnchorFrame: 0,
        tempoConfidence: 1, key: .init(tonic: 0, mode: .major), keyConfidence: 1, chroma: [], timbre: [])
    return try Track(title: "Owned \(number)", mediaFilename: "owned.caf", analysis: analysis)
}
@Test func backgroundOwnedValueKeepsCapturedSnapshotAcrossLaterValueEdits() async throws {
    var original = LibrarySnapshot();original.tracks = [try ownedValueTrack(1)]
    let captured = BackgroundOwnedValue(original)
    original.tracks[0].title = "Later edit"
    #expect(captured.withValue { $0.tracks[0].title } == "Owned 1")
    #expect(original.tracks[0].title == "Later edit")
    await drainQueuedBackgroundRetirements()
}
@Test func ownedBrowserWorkerInputsMatchPublicValueProjectionAndPlaylistResolution() async throws {
    var snapshot = LibrarySnapshot();snapshot.tracks = [try ownedValueTrack(1), try ownedValueTrack(2)]
    let item = MusicLibraryItem(source: .init(platform: .iosMusic, persistentID: "raw"),
        title: "Raw song", artist: "Artist", assetURL: URL(string: "ipod-library://item/raw"), availability: .available)
    let catalog = MusicLibraryCatalog(items: [item], playlists: [])
    let librarySource = BackgroundOwnedValue(snapshot), catalogSource = BackgroundOwnedValue(catalog)
    let value = try await LibraryBrowserProjection.build(tracks: snapshot.tracks, suggestionIDs: nil,
        search: "", sort: .title, category: .songs, group: nil, playlists: .init(), catalog: catalog)
    let owned = try await LibraryBrowserProjection.build(librarySource: librarySource, catalogSource: catalogSource,
        suggestionIDs: nil, search: "", sort: .title, category: .songs, group: nil, playlists: .init())
    #expect(owned.entries.map(\.id) == value.entries.map(\.id))
    #expect(owned.entries.map(\.title) == value.entries.map(\.title))
    let selection = Set([snapshot.tracks[0].id, item.id])
    let valueMembers = try await LibraryBrowserProjection.selectedIDs(selection: selection, tracks: snapshot.tracks, catalog: catalog)
    let ownedMembers = try await LibraryBrowserProjection.selectedIDs(selection: selection, librarySource: librarySource, catalogSource: catalogSource)
    #expect(ownedMembers == valueMembers)
}
@Test func ownedRankingInputMatchesPublicValueRanking() async throws {
    var snapshot = LibrarySnapshot();snapshot.tracks = [try ownedValueTrack(1), try ownedValueTrack(2)]
    let context = SuggestionContext(referenceTrackID: snapshot.tracks[0].id, destination: .b,
        usePerformanceBPM: false, loadedTrackIDs: [snapshot.tracks[0].id], libraryRevision: 0, historyRevision: 0)
    let value = try await PerformerSuggestions.rankAsync(library: snapshot, context: context)
    let owned = try await PerformerSuggestions.rankAsync(librarySource: BackgroundOwnedValue(snapshot), context: context)
    #expect(owned == value)
}
