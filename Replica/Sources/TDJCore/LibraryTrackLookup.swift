final class LibraryTrackLookup: Sendable {
    private final class Payload: Sendable {
        let indices: [String: Int]
        let musicSources: [MusicLibrarySource: Int]
        init(tracks: [Track]) {
            var indices: [String: Int] = [:]
            var sources: [MusicLibrarySource: Int] = [:]
            indices.reserveCapacity(tracks.count)
            for (index, track) in tracks.enumerated() {
                if indices[track.id] == nil { indices[track.id] = index }
                for source in track.musicLibrarySources ?? [] where sources[source] == nil { sources[source] = index }
            }
            self.indices = indices
            musicSources = sources
        }
    }

    private let payload: BackgroundOwnedResource<Payload>

    init(tracks: [Track]) { payload = BackgroundOwnedResource { Payload(tracks: tracks) } }

    func index(for id: String) -> Int? { payload.withResource { $0.indices[id] } }
    func index(for source: MusicLibrarySource) -> Int? { payload.withResource { $0.musicSources[source] } }
}
