import Foundation
import Testing

@testable import TDJCore

@Test func freshCatalogPurgesMissingAudioAndRetainsPlayableSources() async throws {
    var base = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 { base.deleteLastPathComponent() }
    let source = base.appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/clock-a-120.wav")
    let analysis = try AudioAnalyzer.waveformOnly(url: source)
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try WorkspaceStore(root: root)
    var tracks = [Track]()
    var items = [MusicLibraryItem]()
    for n in 0..<5 {
        var fields = try JSONSerialization.jsonObject(with: JSONEncoder().encode(analysis)) as! [String: Any]
        fields["contentSHA256"] = String(repeating: String(n), count: 64)
        let unique = try JSONDecoder().decode(AudioAnalysis.self, from: JSONSerialization.data(withJSONObject: fields))
        let identity = MusicLibrarySource(platform: .iosMusic, persistentID: "\(n)")
        var track = try Track(title: "Fred again.. / Hannah \(n)", mediaFilename: "\(n).wav", analysis: unique)
        track.musicLibrarySources = [identity]
        tracks.append(track)
        items.append(
            .init(
                source: identity, title: track.title, artist: "Fred again..", assetURL: n == 0 ? source : nil,
                availability: n == 0 ? .available : n == 4 ? .protected : .notDownloaded))
    }
    // One native source, one app copy, one loaded source, and two missing sources.
    try FileManager.default.copyItem(
        at: source, to: store.mediaDirectory.appendingPathComponent(tracks[1].mediaFilename))
    var saved = LibrarySnapshot()
    saved.tracks = tracks
    try store.save(saved)
    let service = try LibraryService(store: store)
    let catalog = MusicLibraryCatalog(items: items, playlists: [])
    let result = try await service.reconcileAvailableAudio(catalog: catalog, protectedTracks: [tracks[2].id])
    #expect(Set(result.tracks.map(\.id)) == Set(tracks.prefix(3).map(\.id)))
    #expect(result.track(id: tracks[0].id)?.nativeLibraryOnly == true)
    #expect(result.track(id: tracks[0].id)?.preparation == tracks[0].preparation)
    #expect(result.track(id: tracks[1].id)?.nativeLibraryOnly != true)
    #expect(result.track(id: tracks[2].id)?.nativeLibraryOnly == true)
    let browser = try await LibraryBrowserProjection.build(
        tracks: result.tracks, suggestionIDs: nil, search: "",
        sort: .title, category: .songs, group: nil, playlists: .init(), catalog: catalog)
    #expect(browser.entries.count == 2)
    let archive = try FileManager.default.contentsOfDirectory(
        at: root.appendingPathComponent("UnavailableTracks"), includingPropertiesForKeys: nil)
    #expect(archive.count == 1)
    #expect(try JSONDecoder().decode([Track].self, from: Data(contentsOf: archive[0])).count == 2)
    let unchanged = try await service.reconcileAvailableAudio(catalog: catalog, protectedTracks: [tracks[2].id])
    #expect(unchanged.revision == result.revision)
    let idle = try await service.reconcileAvailableAudio(catalog: catalog)
    #expect(idle.tracks.count == 2)
    #expect(try store.load(includeWaveforms: false).tracks.count == 2)
}
