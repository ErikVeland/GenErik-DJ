import AVFoundation
import Foundation
import Testing
@testable import TDJCore

private func musicFixture(_ name: String = "clock-a-120.wav") -> URL {
    var root = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 { root.deleteLastPathComponent() }
    return root.appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/" + name)
}
private func musicItem(_ id: String, url: URL? = nil, title: String = "Library title") -> MusicLibraryItem {
    .init(source: .init(platform: .macMusic, persistentID: id), title: title, artist: "Library artist",
          album: "Library album", genre: "House", assetURL: url, availability: .available)
}

@Test func musicCatalogPreservesPlaylistOrderAndSearchesLibraryMetadata() {
    let a = musicItem("1", title: "Alpha"), b = musicItem("2", title: "Beta")
    let catalog = MusicLibraryCatalog(items: [a, b], playlists: [.init(id: "p", name: "Set", itemIDs: [b.id, "removed", a.id, b.id])])
    #expect(catalog.songs(playlistID: "p").map(\.id) == [b.id, a.id])
    #expect(catalog.songs(playlistID: "p", search: " BETA ").map(\.id) == [b.id])
    #expect(catalog.songs(search: "library ALBUM").count == 2)
    #expect(catalog.songs(playlistID: "missing").isEmpty)
    #expect(a.source.id != MusicLibrarySource(platform: .iosMusic, persistentID: "1").id)
}

@Test func musicLibraryImportRetainsMetadataIdentityAndManualPreparation() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try WorkspaceStore(root: root)
    let service = try LibraryService(store: store)
    let url = musicFixture()
    let hash = try AudioAnalyzer.sha256(url: url)
    let item = musicItem("17", url: url)
    let imported = try await service.importAudio(url: url, musicLibrary: .init(item: item))
    let track = try #require(imported.tracks.first)
    #expect(track.title == "Library title")
    #expect(track.artist == "Library artist")
    #expect(track.album == "Library album")
    #expect(track.genre == "House")
    #expect(track.id == hash)
    var preparation = track.preparation
    try preparation.grid?.halveBPM()
    preparation.gridIsManual = true
    _ = try await service.updatePreparation(trackID: track.id, preparation: preparation)
    let repeatImport = try await service.importAudio(url: url, musicLibrary: .init(item: item))
    let anotherSource = musicItem("18", url: url)
    _ = try await service.importAudio(url: url, musicLibrary: .init(item: anotherSource))
    let restored = try store.load()
    #expect(repeatImport.tracks.count == 1)
    #expect(restored.tracks.count == 1)
    #expect(restored.tracks[0].musicLibrarySources == [item.source, anotherSource.source])
    #expect(restored.tracks[0].preparation == preparation)
    #expect(restored.tracks[0].album == "Library album")
    #expect(restored.tracks[0].analysis.bpm == track.analysis.bpm)
    #expect(try AudioAnalyzer.sha256(url: url) == hash)
    #expect(restored.events.isEmpty)
    // Old workspaces have no source-link field and must remain readable.
    var json = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: store.libraryURL)) as? [String: Any])
    var tracks = try #require(json["tracks"] as? [[String: Any]])
    tracks[0].removeValue(forKey: "musicLibrarySources")
    tracks[0].removeValue(forKey: "album")
    json["tracks"] = tracks
    try JSONSerialization.data(withJSONObject: json).write(to: store.libraryURL)
    let legacy = try store.load()
    #expect(legacy.tracks[0].musicLibrarySources == nil)
    #expect(legacy.tracks[0].album == nil)
    #expect(legacy.tracks[0].preparation == preparation)
}

@Test func musicLibrarySourceCanMoveToUpdatedAudioWithoutDeletingPreparedTracks() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try WorkspaceStore(root: root)
    let service = try LibraryService(store: store)
    let item = musicItem("19")
    let first = try await service.importAudio(url: musicFixture(), musicLibrary: .init(item: item))
    let oldID = try #require(first.tracks.first?.id)
    _ = try await service.importAudio(url: musicFixture("clock-b-128.wav"), musicLibrary: .init(item: item))
    let restored = try store.load()
    #expect(restored.tracks.count == 2)
    #expect(restored.tracks.first { $0.id == oldID }?.musicLibrarySources?.isEmpty == true)
    #expect(restored.tracks.filter { $0.musicLibrarySources?.contains(item.source) == true }.count == 1)
}

@Test func musicAssetDecodingProducesLosslessStereoPCMAndCleansFailedOutput() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let source = musicFixture("routing-left440-right880.wav")
    let hash = try AudioAnalyzer.sha256(url: source)
    let destination = root.appendingPathComponent("prepared.caf")
    try await MusicLibraryAudio.decodeAsset(url: source, destination: destination)
    let original = try AVAudioFile(forReading: source)
    let decoded = try AVAudioFile(forReading: destination)
    #expect(original.length == decoded.length)
    #expect(original.processingFormat == decoded.processingFormat)
    let a = try #require(AVAudioPCMBuffer(pcmFormat: original.processingFormat, frameCapacity: 4096))
    let b = try #require(AVAudioPCMBuffer(pcmFormat: decoded.processingFormat, frameCapacity: 4096))
    try original.read(into: a); try decoded.read(into: b)
    let left = try #require(a.floatChannelData), right = try #require(b.floatChannelData)
    for channel in 0..<2 {
        #expect(zip(UnsafeBufferPointer(start: left[channel], count: Int(a.frameLength)),
                    UnsafeBufferPointer(start: right[channel], count: Int(b.frameLength))).allSatisfy { abs($0 - $1) < 0.000001 })
    }
    #expect(try AudioAnalyzer.sha256(url: source) == hash)
    let failed = root.appendingPathComponent("failed.caf")
    await #expect(throws: (any Error).self) {
        try await MusicLibraryAudio.decodeAsset(url: root.appendingPathComponent("missing.wav"), destination: failed)
    }
    #expect(!FileManager.default.fileExists(atPath: failed.path))
    await #expect(throws: MusicLibraryError.missingAudio) {
        try await MusicLibraryAudio.decodeAsset(url: URL(string: "https://example.invalid/song.m4a")!, destination: failed)
    }
    await #expect(throws: (any Error).self) {
        try await MusicLibraryAudio.decodeAsset(url: source, destination: destination)
    }
    #expect(try AVAudioFile(forReading: destination).length == original.length)
}

@Test func musicLibraryBackgroundProjectionPreservesOrderAndPreparedSelection() async throws {
    let a = musicItem("1",title:"Alpha"), b = musicItem("2",title:"Beta")
    let catalog = MusicLibraryCatalog(items:[a,b],playlists:[.init(id:"p",name:"Set",itemIDs:[b.id,a.id])])
    var prepared = try syntheticTrack("a",bpm:120)
    prepared.musicLibrarySources = [a.source]
    let result = try await MusicLibraryProjection.build(catalog:catalog,tracks:[prepared],playlistID:"p",search:"")
    #expect(result.songs.map(\.id) == [b.id,a.id])
    #expect(result.preparedIDs == [a.id])
    #expect(result.selectableIDs == [b.id])
    let searched = try await MusicLibraryProjection.build(catalog:catalog,tracks:[prepared],playlistID:"p",search:"Alpha")
    #expect(searched.songs.map(\.id) == [a.id])
    #expect(searched.selectableIDs.isEmpty)
}

@Test func nativeCatalogueMatchesAnalysisAndQueuesOnlyAccessibleUnanalysedSongs() throws {
    let analysed = musicItem("1", title: "Analysed")
    let fresh = musicItem("2", title: "Fresh")
    let protected = MusicLibraryItem(source: .init(platform: .macMusic, persistentID: "3"), title: "Protected", artist: "Artist", assetURL: nil, availability: .protected)
    var track = try syntheticTrack("existing", bpm: 120)
    track.musicLibrarySources = [analysed.source]
    let result = MusicLibraryReconciliation(catalog: .init(items: [analysed, fresh, protected], playlists: []), tracks: [track])
    #expect(result.entries.map(\.item.id) == [analysed.id, fresh.id, protected.id])
    #expect(result.entries[0].track?.id == track.id)
    #expect(result.entries[1].track == nil)
    #expect(result.analysisQueue.map(\.id) == [fresh.id])
}

@Test func nativeAnalysisRetainsMusicSourceWithoutCopyingTheOriginal() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try WorkspaceStore(root: root)
    let service = try LibraryService(store: store)
    let source = musicFixture()
    let item = musicItem("native-direct", url: source)
    let originalHash = try AudioAnalyzer.sha256(url: source)
    let snapshot = try await service.analyzeNativeMusic(url: source, musicLibrary: .init(item: item))
    let track = try #require(snapshot.tracks.first)
    #expect(track.id == originalHash)
    #expect(track.musicLibrarySources == [item.source])
    #expect(track.nativeLibraryOnly == true)
    #expect(try FileManager.default.contentsOfDirectory(atPath: store.mediaDirectory.path).isEmpty)
    #expect(try AudioAnalyzer.sha256(url: source) == originalHash)
    let restored = try store.load()
    #expect(restored.tracks.first?.musicLibrarySources == [item.source])
    let repeated = try await service.analyzeNativeMusic(url: source, musicLibrary: .init(item: item))
    #expect(repeated.tracks.count == 1)
}

@Test func nativeCatalogueQueuesTracksWhoseMusicalAnalysisWasDeferred() throws {
    let item = musicItem("deferred")
    var track = try syntheticTrack("deferred-track", bpm: 120)
    track.musicLibrarySources = [item.source]
    track.analysis.musicalAnalysisDeferred = true
    let result = MusicLibraryReconciliation(catalog: .init(items: [item], playlists: []), tracks: [track])
    #expect(result.entries.first?.track?.id == track.id)
    #expect(result.analysisQueue.map(\.id) == [item.id])
}

@Test func musicAssetDecoderOwnsCreationOfItsMissingPreparationDirectory() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let destination = root.appendingPathComponent("native/staging/prepared.caf")
    #expect(!FileManager.default.fileExists(atPath: root.path))
    let source = musicFixture("routing-left440-right880.wav")
    try await MusicLibraryAudio.decodeAsset(url: source, destination: destination)
    let original = try AVAudioFile(forReading: source), decoded = try AVAudioFile(forReading: destination)
    #expect(decoded.length == original.length && decoded.processingFormat == original.processingFormat)
}
