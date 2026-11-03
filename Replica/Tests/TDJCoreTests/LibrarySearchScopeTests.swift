import Foundation
import Testing
@testable import TDJCore

private func searchScopeTrack(_ index: Int, title: String) throws -> Track {
    let analysis = AudioAnalysis(implementation: "test", configurationID: "test",
        contentSHA256: String(format: "%064x", index), sampleRate: 48000, frameCount: 480000,
        channelCount: 2, waveformFramesPerBin: 4800, waveform: [], bpm: 120,
        beatAnchorFrame: 0, tempoConfidence: 1, key: nil, keyConfidence: 0, chroma: [], timbre: [])
    var track = try Track(title: title, artist: "File artist", genre: "House",
        mediaFilename: "\(index).caf", analysis: analysis)
    track.album = "File album"
    return track
}

private func searchScopeItem(_ id: String, title: String,
    availability: MusicLibraryItem.Availability = .available) -> MusicLibraryItem {
    .init(source: .init(platform: .iosMusic, persistentID: id), title: title,
        artist: "Native artist", album: "Native album", genre: "Techno",
        assetURL: nil, availability: availability)
}

@Test func librarySearchIgnoresRecommendationMembershipAndUsesNormalSort() async throws {
    let last = try searchScopeTrack(1, title: "Zulu needle")
    let first = try searchScopeTrack(2, title: "Alpha needle")
    let raw = searchScopeItem("raw", title: "Middle needle")
    let catalogue = MusicLibraryCatalog(items: [raw], playlists: [])
    let suggestions: [[String]?] = [nil, [], [last.id], [last.id, first.id], ["missing"]]

    for ids in suggestions {
        let result = try await LibraryBrowserProjection.build(tracks: [last, first],
            suggestionIDs: ids, search: "needle", sort: .title, category: .songs,
            group: nil, playlists: .init(), catalog: catalogue)
        #expect(result.entries.map(\.id) == [first.id, raw.id, last.id])
        let rawEntry = try #require(result.entries.first { $0.id == raw.id })
        #expect(rawEntry.track == nil)
    }
}

@Test func librarySearchHasNoRecommendationCountLimit() async throws {
    let tracks = try (1...24).map { try searchScopeTrack($0, title: "Requested song \($0)") }
    let result = try await LibraryBrowserProjection.build(tracks: tracks,
        suggestionIDs: Array(tracks.prefix(3).map(\.id)), search: "Requested", sort: .title,
        category: .songs, group: nil, playlists: .init(), catalog: nil)
    #expect(result.entries.map(\.id) == tracks.map(\.id))
}

@Test func librarySearchIgnoresArtistAlbumGenreAndPlaylistFilters() async throws {
    let file = try searchScopeTrack(1, title: "Needle file")
    let current = searchScopeItem("current", title: "Current song")
    let outside = searchScopeItem("outside", title: "Needle native")
    let catalogue = MusicLibraryCatalog(items: [current, outside], playlists: [
        .init(id: "current", name: "Current playlist", itemIDs: [current.id])
    ])
    var playlists = CollectionPlaylists()
    try playlists.add(trackIDs: [current.id], name: "Custom playlist")
    let customID = try #require(playlists.playlists.first?.id.uuidString)
    let contexts: [(CollectionCategory, String)] = [
        (.artists, "Native artist"), (.albums, "Native album"), (.genre, "Techno"),
        (.playlists, "music:current"), (.playlists, customID), (.playlists, "missing")
    ]

    for (category, group) in contexts {
        let result = try await LibraryBrowserProjection.build(tracks: [file],
            suggestionIDs: nil, search: "needle", sort: .title, category: category,
            group: group, playlists: playlists, catalog: catalogue)
        #expect(result.entries.map(\.id) == [file.id, outside.id])
        if group != "missing" {
            #expect(result.selectedGroup?.id == group)
        }
    }
}

@Test func librarySearchShowsOnlySongsStoredOnThisDevice() async throws {
    let available = MusicLibraryItem(source: .init(platform: .iosMusic, persistentID: "available"),
        title: "Needle available", artist: "Native artist", album: "Native album", genre: "Techno",
        assetURL: URL(string: "ipod-library://item/available"), availability: .available)
    let cloud = searchScopeItem("cloud", title: "Needle cloud", availability: .notDownloaded)
    let protected = searchScopeItem("protected", title: "Needle protected", availability: .protected)
    let catalog = MusicLibraryCatalog(items: [protected, cloud, available], playlists: [
        .init(id: "mixed", name: "Mixed", itemIDs: [cloud.id, protected.id, available.id]),
        .init(id: "cloud", name: "Cloud only", itemIDs: [cloud.id])
    ])
    #expect(catalog.playlists.map(\.id) == ["mixed"])
    #expect(catalog.playlists.first?.itemIDs == [available.id])
    let result = try await LibraryBrowserProjection.build(tracks: [], suggestionIDs: [],
        search: "needle", sort: .title, category: .songs, group: nil, playlists: .init(),
        catalog: catalog)
    #expect(result.entries.map(\.id) == [available.id])
    #expect(result.entries.allSatisfy { $0.track == nil && $0.canLoad })
    let mixed = try await LibraryBrowserProjection.build(tracks: [], suggestionIDs: nil,
        search: "", sort: nil, category: .playlists, group: "music:mixed", playlists: .init(), catalog: catalog)
    #expect(mixed.groups.map(\.id) == ["music:mixed"])
    #expect(mixed.entries.map(\.id) == [available.id])
}

@Test func clearingLibrarySearchRestoresRecommendationRankAndPlaylistMembership() async throws {
    let first = try searchScopeTrack(1, title: "Alpha")
    let second = try searchScopeTrack(2, title: "Zulu")
    var playlists = CollectionPlaylists()
    try playlists.add(trackIDs: [first.id], name: "Selected playlist")
    let group = try #require(playlists.playlists.first?.id.uuidString)

    for query in ["", " \t\n", "\u{00A0}\u{2003}"] {
        let ranked = try await LibraryBrowserProjection.build(tracks: [first, second],
            suggestionIDs: [second.id, first.id], search: query, sort: .title,
            category: .playlists, group: group, playlists: playlists, catalog: nil)
        #expect(ranked.entries.map(\.id) == [second.id, first.id])

        let members = try await LibraryBrowserProjection.build(tracks: [first, second],
            suggestionIDs: nil, search: query, sort: nil, category: .playlists,
            group: group, playlists: playlists, catalog: nil)
        #expect(members.entries.map(\.id) == [first.id])
    }

    let noMatches = try await LibraryBrowserProjection.build(tracks: [first, second],
        suggestionIDs: [second.id], search: "missing", sort: .title, category: .songs,
        group: nil, playlists: playlists, catalog: nil)
    #expect(noMatches.entries.isEmpty)
}

@Test func collectionSearchIgnoresSuggestionAndPlaylistScopes() async throws {
    let outside = try searchScopeTrack(1, title: "Alpha needle")
    let current = try searchScopeTrack(2, title: "Zulu needle")
    var playlists = CollectionPlaylists()
    try playlists.add(trackIDs: [current.id], name: "Selected playlist")
    let group = try #require(playlists.playlists.first?.id.uuidString)
    let suggestions: [[String]?] = [nil, [], [current.id]]

    for ids in suggestions {
        let result = try await CollectionProjection.build(tracks: [current, outside],
            suggestionIDs: ids, search: "needle", sort: .title, category: .playlists,
            group: group, playlists: playlists, catalog: nil)
        #expect(result.tracks.map(\.id) == [outside.id, current.id])
    }
}

@Test func nativeMusicSearchFindsMatchesOutsideTheSelectedPlaylist() async throws {
    let outside = searchScopeItem("outside", title: "Needle outside")
    let current = searchScopeItem("current", title: "Current song")
    let catalogue = MusicLibraryCatalog(items: [outside, current], playlists: [
        .init(id: "current", name: "Current playlist", itemIDs: [current.id])
    ])

    for playlistID: String? in [nil, "current", "missing"] {
        #expect(catalogue.songs(playlistID: playlistID, search: "Needle").map(\.id) == [outside.id])
        let result = try await MusicLibraryProjection.build(catalog: catalogue, tracks: [],
            playlistID: playlistID, search: "Needle")
        #expect(result.songs.map(\.id) == [outside.id])
        #expect(result.selectableIDs == [outside.id])
    }

    for query in ["", " \t\n", "\u{00A0}\u{2003}"] {
        #expect(catalogue.songs(playlistID: "current", search: query).map(\.id) == [current.id])
    }
}
