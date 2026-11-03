import AVFoundation
import Foundation

public struct EmbeddedMetadata: Sendable {
    public var title: String?
    public var artist: String?
    public var album: String?
    public var genre: String?
    public var artwork: Data?
    public var initialKeys: [String] = []
    public init() {}

    public static func read(url: URL) async throws -> Self {
        let asset = AVURLAsset(url: url)
        var result = Self()
        let common = try await asset.load(.commonMetadata)
        for item in common {
            if item.commonKey == .commonKeyTitle { result.title = try await item.load(.stringValue) }
            if item.commonKey == .commonKeyArtist { result.artist = try await item.load(.stringValue) }
            if item.commonKey == .commonKeyAlbumName { result.album = try await item.load(.stringValue) }
            if item.commonKey == .commonKeyArtwork { result.artwork = try await item.load(.dataValue) }
        }
        for format in try await asset.load(.availableMetadataFormats) {
            for item in try await asset.loadMetadata(for: format) {
                let identifier = item.identifier
                if identifier == .id3MetadataInitialKey,
                   let rawValue = try await item.load(.stringValue) {
                    let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !value.isEmpty, !result.initialKeys.contains(value) { result.initialKeys.append(value) }
                }
                if identifier == .iTunesMetadataUserGenre || identifier == .id3MetadataContentType
                    || identifier == .quickTimeMetadataGenre {
                    if let value = try await item.load(.stringValue), !value.isEmpty { result.genre = value }
                }
            }
        }
        if let artwork = result.artwork, artwork.count > 5 * 1024 * 1024 { result.artwork = nil }
        return result
    }
}
