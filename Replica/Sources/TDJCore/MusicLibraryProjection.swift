import Foundation

/// Search and prepared-state lookup stay off the performance-control actor.
public struct MusicLibraryProjection: Sendable {
    public let songs: [MusicLibraryItem]
    public let preparedIDs: Set<String>
    public let selectableIDs: Set<String>
    private static let worker = AnalysisWorker()

    public static func build(catalog: MusicLibraryCatalog?, tracks: [Track],
                             playlistID: String?, search: String) async throws -> Self {
        try await worker.run { check in
            try check()
            let sources = Set(tracks.flatMap { $0.musicLibrarySources ?? [] })
            let songs = catalog?.songs(playlistID: playlistID, search: search) ?? []
            var prepared = Set<String>(), selectable = Set<String>()
            for song in songs {
                try check()
                if sources.contains(song.source) { prepared.insert(song.id) }
                else if song.isOnDevice { selectable.insert(song.id) }
            }
            return Self(songs: songs, preparedIDs: prepared, selectableIDs: selectable)
        }
    }
}
