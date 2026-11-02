import Foundation

public struct MusicLibrarySource: Codable, Hashable, Sendable, Identifiable {
    public enum Platform: String, Codable, Sendable { case macMusic, iosMusic }
    public let platform: Platform
    public let persistentID: String
    public var id: String { "\(platform.rawValue):\(persistentID)" }
    public init(platform: Platform, persistentID: String) {
        self.platform = platform; self.persistentID = persistentID
    }
}

public struct MusicLibraryItem: Sendable, Identifiable, Equatable {
    public enum Availability: String, Sendable {
        case available, notDownloaded, protected, unavailable
        public var message: String {
            switch self {
            case .available: return "Available on this device"
            case .notDownloaded: return "Download or sync this song in Music, then refresh."
            case .protected: return "Protected audio cannot be used for mixing."
            case .unavailable: return "Local audio is unavailable. Refresh after syncing in Music."
            }
        }
    }
    public let source: MusicLibrarySource
    public var id: String { source.id }
    public let title: String
    public let artist: String
    public let album: String
    public let genre: String?
    public let duration: Double
    public let assetURL: URL?
    public let availability: Availability
    public init(source: MusicLibrarySource, title: String, artist: String, album: String = "",
                genre: String? = nil, duration: Double = 0, assetURL: URL?, availability: Availability) {
        self.source = source; self.title = title; self.artist = artist; self.album = album
        self.genre = genre; self.duration = duration; self.assetURL = assetURL; self.availability = availability
    }
}

public struct MusicLibraryPlaylist: Sendable, Identifiable, Equatable {
    public let id: String
    public let name: String
    public let itemIDs: [String]
    public init(id: String, name: String, itemIDs: [String]) {
        self.id = id; self.name = name; self.itemIDs = itemIDs
    }
}

public struct MusicLibraryCatalog: Sendable, Equatable {
    public let items: [MusicLibraryItem]
    public let playlists: [MusicLibraryPlaylist]
    public init(items: [MusicLibraryItem], playlists: [MusicLibraryPlaylist]) {
        self.items = items; self.playlists = playlists
    }
    public func songs(playlistID: String? = nil, search: String = "") -> [MusicLibraryItem] {
        let candidates: [MusicLibraryItem]
        if let playlistID {
            let lookup = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            var seen: Set<String> = []
            candidates = playlists.first { $0.id == playlistID }?.itemIDs.compactMap { id in
                seen.insert(id).inserted ? lookup[id] : nil
            } ?? []
        } else { candidates = items }
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return candidates }
        return candidates.filter {
            [$0.title, $0.artist, $0.album].contains { $0.localizedStandardContains(query) }
        }
    }
}

public struct MusicLibraryImportMetadata: Sendable {
    public let source: MusicLibrarySource
    public let title: String
    public let artist: String
    public let album: String
    public let genre: String?
    public let artwork: Data?
    public init(item: MusicLibraryItem, artwork: Data? = nil) {
        source = item.source; title = item.title; artist = item.artist; album = item.album; genre = item.genre; self.artwork = artwork
    }
}

public enum MusicLibraryError: Error, LocalizedError, Equatable {
    case permissionDenied, restricted, unavailable, protected, missingAudio, decoding(String)
    public var errorDescription: String? {
        switch self {
        case .permissionDenied: return "Allow GenErik DJ to access your music library in Settings, then refresh."
        case .restricted: return "Music library access is restricted on this device."
        case .unavailable: return "The music library is unavailable. Open Music and check your local library, then refresh."
        case .protected: return "This song has protected audio and cannot be used for mixing."
        case .missingAudio: return "This song has no accessible local audio. Download or sync it in Music, then refresh."
        case .decoding(let message): return "Cannot prepare this library song: \(message)"
        }
    }
}
