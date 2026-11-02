import Foundation

public struct CollectionPlaylist: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var trackIDs: [String]
}

public struct CollectionPlaylists: Codable, Equatable, Sendable {
    public private(set) var playlists: [CollectionPlaylist] = []
    public init() {}
    public mutating func add(trackIDs: [String], to id: UUID? = nil, name: String = "") throws {
        if let id {
            guard let index=playlists.firstIndex(where: { $0.id == id }) else { throw CoreError.staleContext }
            var seen=Set(playlists[index].trackIDs)
            playlists[index].trackIDs += trackIDs.filter { seen.insert($0).inserted }
        } else {
            let name=name.trimmingCharacters(in:.whitespacesAndNewlines)
            guard !name.isEmpty else { throw CoreError.invalidWorkspace("Enter a playlist name.") }
            var seen=Set<String>()
            playlists.append(.init(id:UUID(),name:name,trackIDs:trackIDs.filter { seen.insert($0).inserted }))
        }
    }
    public static func load(from url: URL) throws -> Self {
        guard FileManager.default.fileExists(atPath:url.path) else { return .init() }
        let value=try JSONDecoder().decode(Self.self,from:Data(contentsOf:url))
        guard Set(value.playlists.map(\.id)).count == value.playlists.count,
              value.playlists.allSatisfy({ !$0.name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty && Set($0.trackIDs).count == $0.trackIDs.count }) else {
            throw CoreError.invalidWorkspace("Invalid saved collection playlists.")
        }
        return value
    }
    public func save(to url: URL) throws { try JSONEncoder().encode(self).write(to:url,options:.atomic) }
}

public enum CollectionCategory: String, CaseIterable, Sendable {
    case songs = "Songs", playlists = "Playlists", artists = "Artists", albums = "Albums", genre = "Genre"
    public func value(for track: Track) -> String {
        switch self {
        case .artists: return track.artist
        case .albums: return track.album ?? ""
        case .genre: return track.genre ?? ""
        default: return ""
        }
    }
}
