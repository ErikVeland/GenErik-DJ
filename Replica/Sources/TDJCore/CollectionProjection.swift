import Foundation

public struct CollectionGroup: Identifiable, Sendable {
    public let id: String
    public let name: String
}

public struct CollectionProjection: Sendable {
    public let tracks: [Track]
    public let groups: [CollectionGroup]
    private static let worker = AnalysisWorker()

    public static func build(
        tracks: [Track], suggestionIDs: [String]?, search: String, sort: CollectionSort, category: CollectionCategory,
        group: String?, playlists: CollectionPlaylists, catalog: MusicLibraryCatalog?
    ) async throws -> Self {
        try await worker.run { check in
            try check()
            let localSources = Set((catalog?.items ?? []).lazy.filter(\.isOnDevice).map(\.source))
            let visibleTracks = tracks.filter { track in
                track.nativeLibraryOnly != true
                    || (track.musicLibrarySources ?? []).contains(where: localSources.contains)
            }
            var byTrackID: [String: Track] = [:]
            var bySourceID: [String: Track] = [:]
            for track in visibleTracks {
                if byTrackID[track.id] == nil { byTrackID[track.id] = track }
                for source in track.musicLibrarySources ?? [] where bySourceID[source.id] == nil {
                    bySourceID[source.id] = track
                }
            }
            let groups: [CollectionGroup]
            if category == .playlists {
                groups =
                    playlists.playlists.map { .init(id: $0.id.uuidString, name: $0.name) }
                    + (catalog?.playlists.map { .init(id: "music:" + $0.id, name: $0.name + " · Music") } ?? [])
            } else if category == .songs {
                groups = []
            } else {
                groups = Set(visibleTracks.map { category.value(for: $0) }).sorted {
                    $0.localizedStandardCompare($1) == .orderedAscending
                }.map { .init(id: $0, name: $0.isEmpty ? "Unknown" : $0) }
            }
            try check()
            let searching = search.contains { !$0.isWhitespace }
            var candidates = visibleTracks
            if !searching, let suggestionIDs {
                let lookup = Dictionary(visibleTracks.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
                candidates = suggestionIDs.compactMap { lookup[$0] }
            } else if !searching, let group {
                if category == .playlists {
                    if group.hasPrefix("music:"), let catalog {
                        let sources = Set(catalog.songs(playlistID: String(group.dropFirst(6))).map(\.source))
                        candidates = visibleTracks.filter { !sources.isDisjoint(with: $0.musicLibrarySources ?? []) }
                    } else {
                        candidates = (playlists.playlists.first { $0.id.uuidString == group }?.trackIDs ?? [])
                            .compactMap { byTrackID[$0] ?? bySourceID[$0] }
                    }
                } else if category != .songs {
                    candidates = visibleTracks.filter { category.value(for: $0) == group }
                }
            }
            try check()
            let result = CollectionBrowser.tracks(
                candidates, search: search, sort: suggestionIDs == nil || searching ? sort : nil)
            try check()
            return Self(tracks: result, groups: groups)
        }
    }
}
