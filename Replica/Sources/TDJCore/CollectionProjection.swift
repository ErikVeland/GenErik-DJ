import Foundation

public struct CollectionGroup: Identifiable, Sendable {
    public let id: String
    public let name: String
}

public struct CollectionProjection: Sendable {
    public let tracks: [Track]
    public let groups: [CollectionGroup]
    private static let worker = AnalysisWorker()

    public static func build(tracks: [Track], suggestionIDs: [String]?, search: String,
                             sort: CollectionSort, category: CollectionCategory, group: String?,
                             playlists: CollectionPlaylists, catalog: MusicLibraryCatalog?) async throws -> Self {
        try await worker.run { check in
            try check()
            let groups: [CollectionGroup]
            if category == .playlists {
                groups = playlists.playlists.map { .init(id: $0.id.uuidString, name: $0.name) }
                    + (catalog?.playlists.map { .init(id: "music:" + $0.id, name: $0.name + " · Music") } ?? [])
            } else if category == .songs {
                groups = []
            } else {
                groups = Set(tracks.map { category.value(for: $0) }).sorted {
                    $0.localizedStandardCompare($1) == .orderedAscending
                }.map { .init(id: $0, name: $0.isEmpty ? "Unknown" : $0) }
            }
            try check()
            let searching = search.contains { !$0.isWhitespace }
            var candidates = tracks
            if !searching, let suggestionIDs {
                let lookup = Dictionary(tracks.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
                candidates = suggestionIDs.compactMap { lookup[$0] }
            } else if !searching, let group {
                if category == .playlists {
                    if group.hasPrefix("music:"), let catalog {
                        let sources = Set(catalog.songs(playlistID: String(group.dropFirst(6))).map(\.source))
                        candidates = tracks.filter { !sources.isDisjoint(with: $0.musicLibrarySources ?? []) }
                    } else {
                        let lookup = Dictionary(tracks.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
                        candidates = (playlists.playlists.first { $0.id.uuidString == group }?.trackIDs ?? []).compactMap { lookup[$0] }
                    }
                } else if category != .songs {
                    candidates = tracks.filter { category.value(for: $0) == group }
                }
            }
            try check()
            let result = CollectionBrowser.tracks(candidates, search: search, sort: suggestionIDs == nil || searching ? sort : nil)
            try check()
            return Self(tracks: result, groups: groups)
        }
    }
}
