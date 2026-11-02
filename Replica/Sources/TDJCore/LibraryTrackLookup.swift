final class LibraryTrackLookup: Sendable {
    private final class Payload: Sendable {
        let indices: [String: Int]
        init(tracks: [Track]) {
            var indices: [String: Int] = [:]
            indices.reserveCapacity(tracks.count)
            for (index, track) in tracks.enumerated() where indices[track.id] == nil {
                indices[track.id] = index
            }
            self.indices = indices
        }
    }

    private let payload: BackgroundOwnedResource<Payload>

    init(tracks: [Track]) {
        payload = BackgroundOwnedResource { Payload(tracks: tracks) }
    }

    func index(for id: String) -> Int? {
        payload.withResource { $0.indices[id] }
    }
}
