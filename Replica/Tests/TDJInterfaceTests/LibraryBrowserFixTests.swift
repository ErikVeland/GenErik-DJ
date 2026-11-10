import AVFoundation
import CoreGraphics
import Foundation
import ImageIO
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private final class LargeMusicLibrary: LocalMusicLibraryProviding {
    let snapshot: MusicLibraryCatalog
    var error: MusicLibraryError?
    init(songs: Int, playlists: [String], local: Bool = true) {
        let items = (0..<songs).map { index in
            MusicLibraryItem(
                source: .init(platform: .iosMusic, persistentID: String(index + 1)),
                title: String(format: "Song %05d", index), artist: "Artist \(index%40)",
                assetURL: local ? URL(string: "ipod-library://item/\(index+1)") : nil,
                availability: local ? .available : .notDownloaded)
        }
        let lists = playlists.enumerated().map { index, name in
            MusicLibraryPlaylist(
                id: "ios-playlist:\(index)", name: name, itemIDs: items.prefix(10 * (index + 1)).map(\.id))
        }
        snapshot = .init(items: items, playlists: lists)
    }
    func catalog() async throws -> MusicLibraryCatalog {
        if let error { throw error }
        return snapshot
    }
    func prepare(_ item: MusicLibraryItem, in directory: URL) async throws -> PreparedMusicLibraryAudio {
        throw MusicLibraryError.missingAudio
    }
}

@Test @MainActor func cloudOnlyMusicDoesNotCreateLibraryRowsOrPlaylists() async throws {
    let provider = LargeMusicLibrary(songs: 3, playlists: ["Cloud only"], local: false)
    let (model, workspace) = try largeLibraryModel(provider)
    defer { try? FileManager.default.removeItem(at: workspace) }
    await model.refreshMusicLibrary()
    #expect(model.browsableSongCount == 0)
    let songs = try await LibraryBrowserProjection.build(
        librarySource: model.libraryReadSource(), catalogSource: model.catalogReadSource(), suggestionIDs: nil,
        search: "", sort: .title, category: .songs, group: nil, playlists: CollectionPlaylists())
    #expect(songs.entries.isEmpty)
    let playlists = try await LibraryBrowserProjection.build(
        librarySource: model.libraryReadSource(), catalogSource: model.catalogReadSource(), suggestionIDs: nil,
        search: "", sort: nil, category: .playlists, group: nil, playlists: CollectionPlaylists())
    #expect(playlists.groups.isEmpty && playlists.entries.isEmpty)
}

@MainActor private func largeLibraryModel(_ provider: LargeMusicLibrary) throws -> (ReplicaModel, URL) {
    let workspace = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    return (
        try ReplicaModel(root: workspace, playback: PlaybackController(offline: true), musicLibraryProvider: provider),
        workspace
    )
}

@Test func lazySongRowsCoverEveryEntryThroughTheLastRow() {
    let rows = LibraryBrowserRows(count: 5996)
    #expect(rows.indices.first == 0 && rows.indices.last == 5995)
    #expect(rows.indices.count == 5996)
    #expect(rows.contentHeight == 5996 * LibraryBrowserRowWindow.rowHeight)
    #expect(LibraryBrowserRows(count: -3).indices.isEmpty)
}

@Test @MainActor func wholeMusicLibraryIsListedAndCountedWithPlaylistsInOrder() async throws {
    let provider = LargeMusicLibrary(songs: 5996, playlists: ["Warm Up", "Peak", "Closing"])
    let (model, workspace) = try largeLibraryModel(provider)
    defer { try? FileManager.default.removeItem(at: workspace) }
    await model.refreshMusicLibrary()
    #expect(model.browsableSongCount == 5996)
    #expect(model.libraryFooterText == "5996 songs")
    let songs = try await LibraryBrowserProjection.build(
        librarySource: model.libraryReadSource(), catalogSource: model.catalogReadSource(), suggestionIDs: nil,
        search: "", sort: .title, category: .songs, group: nil, playlists: CollectionPlaylists())
    #expect(songs.entries.count == 5996)
    // The last row resolves to the last song, so a full scroll ends on real content.
    #expect(songs.entries[LibraryBrowserRows(count: songs.entries.count).indices.last!].title == "Song 05995")
    let lists = try await LibraryBrowserProjection.build(
        librarySource: model.libraryReadSource(), catalogSource: model.catalogReadSource(), suggestionIDs: nil,
        search: "", sort: nil, category: .playlists, group: nil, playlists: CollectionPlaylists())
    let groups = try await LibraryGroupProjection.build(source: lists.groupSource, search: "", selectedID: nil)
    #expect(groups.count == 3)
    #expect(
        groups.visibleGroups(in: 0..<groups.count).map(\.name).sorted() == [
            "Closing", "Peak", "Warm Up",
        ])
    let peak = try #require(groups.visibleGroups(in: 0..<groups.count).first { $0.name == "Peak" })
    let members = try await LibraryBrowserProjection.build(
        librarySource: model.libraryReadSource(), catalogSource: model.catalogReadSource(), suggestionIDs: nil,
        search: "", sort: nil, category: .playlists, group: peak.id, playlists: CollectionPlaylists())
    #expect(members.entries.map(\.title) == (0..<20).map { String(format: "Song %05d", $0) })
}

@Test @MainActor func unreadableMusicLibraryIsReportedInsteadOfAShortList() async throws {
    let provider = LargeMusicLibrary(songs: 3, playlists: [])
    provider.error = .permissionDenied
    let (model, workspace) = try largeLibraryModel(provider)
    defer { try? FileManager.default.removeItem(at: workspace) }
    await model.refreshMusicLibrary()
    #expect(model.libraryFooterText.hasPrefix("Music library unavailable:"))
}

private func artworkPNG() throws -> Data {
    let context = try #require(
        CGContext(
            data: nil, width: 600, height: 600, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
    context.setFillColor(CGColor(red: 1, green: 0.4, blue: 0, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: 600, height: 600))
    let data = NSMutableData()
    let destination = try #require(CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil))
    CGImageDestinationAddImage(destination, try #require(context.makeImage()), nil)
    #expect(CGImageDestinationFinalize(destination))
    return data as Data
}

@Test func embeddedCoverArtIsReadFromTheAudioFileAndCachedAsAThumbnail() async throws {
    var root = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 { root.deleteLastPathComponent() }
    let source = root.appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/clock-a-120.wav")
    let output = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".m4a")
    defer { try? FileManager.default.removeItem(at: output) }
    let export = try #require(
        AVAssetExportSession(asset: AVURLAsset(url: source), presetName: AVAssetExportPresetAppleM4A))
    let art = AVMutableMetadataItem()
    art.identifier = .commonIdentifierArtwork
    art.value = try artworkPNG() as NSData
    art.dataType = kCMMetadataBaseDataType_PNG as String
    export.metadata = [art]
    export.outputURL = output
    export.outputFileType = .m4a
    await export.export()
    #expect(export.status == .completed)
    let data = await ArtworkThumbnails.embeddedArtwork(output)
    #expect(data?.isEmpty == false)
    let cache = ArtworkThumbnails()
    let thumbnail = try #require(await cache.load(ArtworkSource(asset: output)))
    #expect(thumbnail.image.width == 192 && thumbnail.image.height == 192)
    #expect(await cache.load(ArtworkSource(asset: output))?.image === thumbnail.image)
    // A file with no embedded art yields no thumbnail rather than a placeholder image.
    #expect(await cache.load(ArtworkSource(asset: source)) == nil)
}
