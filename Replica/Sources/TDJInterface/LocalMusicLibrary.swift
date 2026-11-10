import Foundation
import TDJCore

#if os(macOS)
    import iTunesLibrary
#else
    import MediaPlayer
    import UIKit
#endif

public struct PreparedMusicLibraryAudio: Sendable {
    public let url: URL
    public let metadata: MusicLibraryImportMetadata
    public let temporary: Bool
    public init(url: URL, metadata: MusicLibraryImportMetadata, temporary: Bool = false) {
        self.url = url
        self.metadata = metadata
        self.temporary = temporary
    }
}

@MainActor public protocol LocalMusicLibraryProviding {
    var allowsCachedCatalog: Bool { get }
    func catalog() async throws -> MusicLibraryCatalog
    func prepare(_ item: MusicLibraryItem, in directory: URL) async throws -> PreparedMusicLibraryAudio
    func playbackSource(_ item: MusicLibraryItem) async throws -> PreparedMusicLibraryAudio?
}
extension LocalMusicLibraryProviding {
    public var allowsCachedCatalog: Bool { false }
    public func playbackSource(_ item: MusicLibraryItem) async throws -> PreparedMusicLibraryAudio? { nil }
}

@MainActor public final class LocalMusicLibrary: LocalMusicLibraryProviding {
    private nonisolated static let mediaQueue = DispatchQueue(label: "org.generikdj.music-library", qos: .background)
    private nonisolated static let playbackQueue = DispatchQueue(
        label: "org.generikdj.music-playback-source", qos: .userInitiated)
    private nonisolated static func onMediaQueue<T: Sendable>(
        playback: Bool = false, _ work: @escaping @Sendable () throws -> T
    ) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            let queue = playback ? playbackQueue : mediaQueue
            queue.async(qos: playback ? .userInitiated : .background, flags: .enforceQoS) {
                do { continuation.resume(returning: try autoreleasepool(invoking: work)) } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    private let diagnosticsURL: URL?
    /// Replaces the diagnostics file with the latest stage, so a device copy shows where a read stopped.
    private nonisolated static func stage(_ text: String, at url: URL?) {
        guard let url else { return }
        try? Data((Date().ISO8601Format() + " " + text + "\n").utf8).write(to: url, options: .atomic)
    }
    public init(diagnosticsURL: URL? = nil) { self.diagnosticsURL = diagnosticsURL }
    #if os(iOS)
        public var allowsCachedCatalog: Bool { MPMediaLibrary.authorizationStatus() == .authorized }
    #endif
    public func catalog() async throws -> MusicLibraryCatalog {
        #if os(macOS)
            let diagnosticsURL = diagnosticsURL
            return try await Self.onMediaQueue {
                Self.stage("Opening native music library", at: diagnosticsURL)
                let library: ITLibrary
                do { library = try ITLibrary(apiVersion: "1.0", options: .lazyLoadData) } catch {
                    throw MusicLibraryError.decoding(
                        "Music library access failed. Allow access in System Settings and refresh. \(error.localizedDescription)"
                    )
                }
                return try Self.macCatalog(library: library, diagnosticsURL: diagnosticsURL)
            }
        #else
            let diagnosticsURL = diagnosticsURL
            var authorization = MPMediaLibrary.authorizationStatus()
            Self.stage("Music library authorization: \(authorization.rawValue)", at: diagnosticsURL)
            if authorization == .notDetermined, UIApplication.shared.applicationState != .background {
                authorization = await withCheckedContinuation { continuation in
                    MPMediaLibrary.requestAuthorization { continuation.resume(returning: $0) }
                }
            }
            guard authorization == .authorized else {
                Self.stage("Music library access not authorised: \(authorization.rawValue)", at: diagnosticsURL)
                throw authorization == .restricted ? MusicLibraryError.restricted : MusicLibraryError.permissionDenied
            }
            let progress = AnalysisWorkProgress.observer
            return try await Self.onMediaQueue {
                Self.stage("Reading native songs and playlists", at: diagnosticsURL)
                let catalog = try Self.iosCatalog(progress: progress)
                Self.stage(
                    "Finished native library read: \(catalog.items.count) songs, \(catalog.playlists.count) playlists",
                    at: diagnosticsURL)
                return catalog
            }
        #endif
    }

    public func playbackSource(_ item: MusicLibraryItem) async throws -> PreparedMusicLibraryAudio? {
        try await prepare(item, in: FileManager.default.temporaryDirectory, export: false)
    }
    public func prepare(_ item: MusicLibraryItem, in directory: URL) async throws -> PreparedMusicLibraryAudio {
        try await prepare(item, in: directory, export: true)
    }
    private func prepare(_ item: MusicLibraryItem, in directory: URL, export: Bool) async throws
        -> PreparedMusicLibraryAudio
    {
        guard item.availability != .protected else { throw MusicLibraryError.protected }
        guard item.isOnDevice, let catalogURL = item.assetURL else { throw MusicLibraryError.missingAudio }
        var url = catalogURL
        var metadata = MusicLibraryImportMetadata(item: item)
        #if os(iOS)
            guard MPMediaLibrary.authorizationStatus() == .authorized else { throw MusicLibraryError.permissionDenied }
            let prepared = try await Self.onMediaQueue(playback: !export) { () -> (URL, MusicLibraryImportMetadata) in
                guard let persistentID = UInt64(item.source.persistentID) else { throw MusicLibraryError.missingAudio }
                let query = MPMediaQuery.songs()
                query.addFilterPredicate(
                    MPMediaPropertyPredicate(
                        value: NSNumber(value: persistentID), forProperty: MPMediaItemPropertyPersistentID))
                guard let current = query.items?.first(where: { $0.persistentID == persistentID }) else {
                    throw MusicLibraryError.missingAudio
                }
                guard !current.hasProtectedAsset else { throw MusicLibraryError.protected }
                guard let currentURL = current.assetURL else { throw MusicLibraryError.missingAudio }
                guard currentURL.isFileURL || currentURL.scheme?.lowercased() == "ipod-library" else {
                    throw MusicLibraryError.missingAudio
                }
                if currentURL.isFileURL {
                    guard FileManager.default.isReadableFile(atPath: currentURL.path) else {
                        throw MusicLibraryError.missingAudio
                    }
                } else {
                    guard !current.isCloudItem else { throw MusicLibraryError.missingAudio }
                }
                let artwork =
                    export
                    ? current.artwork?.image(at: CGSize(width: 512, height: 512))?.jpegData(compressionQuality: 0.9)
                    : nil
                let metadata = MusicLibraryImportMetadata(
                    item: item, artwork: artwork.flatMap { $0.count <= 5 * 1024 * 1024 ? $0 : nil })
                return (currentURL, metadata)
            }
            try Task.checkCancellation()
            (url, metadata) = prepared
        #endif
        guard url.isFileURL || url.scheme?.lowercased() == "ipod-library" else { throw MusicLibraryError.missingAudio }
        if url.isFileURL || !export { return .init(url: url, metadata: metadata) }
        let destination = directory.appendingPathComponent(UUID().uuidString + ".caf")
        try await MusicLibraryAudio.decodeAsset(url: url, destination: destination)
        return .init(url: destination, metadata: metadata, temporary: true)
    }

    #if os(macOS)
        private nonisolated static func macCatalog(library: ITLibrary, diagnosticsURL: URL?) throws
            -> MusicLibraryCatalog
        {
            func stage(_ text: String) { Self.stage(text, at: diagnosticsURL) }
            stage("Reading native song index")
            let mediaItems = library.allMediaItems
            stage("Checking local audio for \(mediaItems.count) indexed items")
            let items: [MusicLibraryItem] = mediaItems.filter { $0.mediaKind == .kindSong }.map {
                item -> MusicLibraryItem in
                let source = MusicLibrarySource(platform: .macMusic, persistentID: item.persistentID.stringValue)
                let url = item.location
                let available: Bool
                if let url, url.isFileURL {
                    let scoped = url.startAccessingSecurityScopedResource()
                    available = FileManager.default.isReadableFile(atPath: url.path)
                    if scoped { url.stopAccessingSecurityScopedResource() }
                } else {
                    available = false
                }
                let availability: MusicLibraryItem.Availability =
                    item.isDRMProtected
                    ? .protected : available ? .available : item.isCloud ? .notDownloaded : .unavailable
                return MusicLibraryItem(
                    source: source, title: item.title, artist: item.artist?.name ?? "", album: item.album.title ?? "",
                    genre: item.genre.isEmpty ? nil : item.genre, duration: Double(item.totalTime) / 1000,
                    assetURL: url, availability: availability)
            }.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
            stage("Reading native playlists")
            let known = Set(items.filter(\.isOnDevice).map(\.id))
            let playlists = library.allPlaylists.filter { $0.isVisible }.map { playlist in
                MusicLibraryPlaylist(
                    id: "mac-playlist:\(playlist.persistentID.stringValue)", name: playlist.name,
                    itemIDs: playlist.items.map {
                        MusicLibrarySource(platform: .macMusic, persistentID: $0.persistentID.stringValue).id
                    }.filter { known.contains($0) })
            }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            stage("Finished native library read: \(items.count) songs, \(playlists.count) playlists")
            return .init(items: items, playlists: playlists)
        }
    #else
        private nonisolated static func iosCatalog(progress: (@Sendable (Double) -> Void)?) throws -> MusicLibraryCatalog {
            guard let songs = MPMediaQuery.songs().items else { throw MusicLibraryError.unavailable }
            progress?(0.05)
            var songProgress = AnalysisWorkProgress.Step(0.05...0.85, observer: progress)
            let items: [MusicLibraryItem] = songs.enumerated().map { index, item -> MusicLibraryItem in
                let url = item.assetURL
                let hasLocalAsset: Bool
                let isCloudOnly: Bool
                if let url, url.isFileURL {
                    hasLocalAsset = FileManager.default.isReadableFile(atPath: url.path)
                    isCloudOnly = false
                } else if url?.scheme?.lowercased() == "ipod-library" {
                    hasLocalAsset = true
                    isCloudOnly = item.isCloudItem
                } else {
                    hasLocalAsset = false
                    isCloudOnly = item.isCloudItem
                }
                let availability: MusicLibraryItem.Availability
                if item.hasProtectedAsset {
                    availability = .protected
                } else if hasLocalAsset && !isCloudOnly {
                    availability = .available
                } else if item.isCloudItem {
                    availability = .notDownloaded
                } else {
                    availability = .unavailable
                }
                songProgress.advance(Int64(index + 1), of: Int64(songs.count))
                return MusicLibraryItem(
                    source: .init(platform: .iosMusic, persistentID: String(item.persistentID)),
                    title: item.title ?? "Untitled", artist: item.artist ?? "", album: item.albumTitle ?? "",
                    genre: item.genre, duration: item.playbackDuration, assetURL: url, availability: availability)
            }.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
            let known = Set(items.filter(\.isOnDevice).map(\.id))
            let collections = MPMediaQuery.playlists().collections as? [MPMediaPlaylist] ?? []
            var playlistProgress = AnalysisWorkProgress.Step(0.85...1, observer: progress)
            let playlists = collections.enumerated().map { index, playlist in
                let entry = MusicLibraryPlaylist(
                    id: "ios-playlist:\(playlist.persistentID)", name: playlist.name ?? "Playlist",
                    itemIDs: playlist.items.map {
                        MusicLibrarySource(platform: .iosMusic, persistentID: String($0.persistentID)).id
                    }.filter { known.contains($0) })
                playlistProgress.advance(Int64(index + 1), of: Int64(collections.count))
                return entry
            }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            return .init(items: items, playlists: playlists)
        }
    #endif
}
