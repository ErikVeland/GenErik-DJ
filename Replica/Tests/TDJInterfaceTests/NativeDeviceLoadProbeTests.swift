import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private final class DeviceProbeLibrary: LocalMusicLibraryProviding {
    let item: MusicLibraryItem
    init(_ item: MusicLibraryItem) { self.item = item }
    func catalog() async throws -> MusicLibraryCatalog { .init(items: [item], playlists: []) }
    func playbackSource(_ item: MusicLibraryItem) async throws -> PreparedMusicLibraryAudio? {
        .init(url: try #require(item.assetURL), metadata: .init(item: item))
    }
    func prepare(_ item: MusicLibraryItem, in directory: URL) async throws -> PreparedMusicLibraryAudio {
        throw CancellationError()
    }
}
@Test(.enabled(if: ProcessInfo.processInfo.environment["R95_SOURCE"] != nil))
@MainActor func nativeDeviceSavedLibraryLoadProbe() async throws {
    guard let path = ProcessInfo.processInfo.environment["R95_SOURCE"],
        let libraryPath = ProcessInfo.processInfo.environment["R95_LIBRARY"]
    else { return }
    let saved = try JSONDecoder().decode(
        LibrarySnapshot.self, from: Data(contentsOf: URL(fileURLWithPath: libraryPath)))
    let track = try #require(saved.tracks.first { $0.title.contains("Hannah") })
    let item = MusicLibraryItem(
        source: try #require(track.musicLibrarySources?.first), title: track.title,
        artist: track.artist, assetURL: URL(fileURLWithPath: path), availability: .available)
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try WorkspaceStore(root: root)
    try store.save(saved)
    let model = try ReplicaModel(
        root: root, playback: PlaybackController(offline: true), musicLibraryProvider: DeviceProbeLibrary(item))
    await model.refreshMusicLibrary()
    model.loadLibraryEntry(.init(nativeItem: item, track: track), deck: .a)
    await model.flushWrites()
    #expect(model.loaded[.a] == track.id, "\(model.status.debugDescription)")
    #expect(model.playback.core.snapshot()?.a.phase == .ready, "\(model.status.debugDescription)")
    await model.finishForShutdown()
}

@Test(
    .serialized,
    arguments: ["Fred again..", "..Hannah (The Sun)", "100% #1? & +", "Björk – 東京 🎵", "quote'\"\\name", "e\u{301}"])
@MainActor func nativeBrowserIgnoresMissingCopyAndPreservesLiteralNames(name: String) async throws {
    var base = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 { base.deleteLastPathComponent() }
    let fixtures = base.appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures")
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try WorkspaceStore(root: root)
    let source = root.appendingPathComponent(name + ".wav")
    try FileManager.default.copyItem(at: fixtures.appendingPathComponent("clock-a-120.wav"), to: source)
    let title = name + " / ../ %2F \u{0}\nTitle"
    let item = MusicLibraryItem(
        source: .init(platform: .iosMusic, persistentID: "551467752780119129"),
        title: title, artist: name, album: "../album #?", assetURL: source, availability: .available)
    let analysis = try AudioAnalyzer.waveformOnly(url: source)
    var track = try Track(
        title: title, artist: name, mediaFilename: analysis.contentSHA256 + ".caf", analysis: analysis)
    track.musicLibrarySources = [item.source]
    track.preparation.grid = try BeatGrid(bpm: 125, anchorFrame: 42196, sampleRate: analysis.sampleRate)
    track.preparation.gridIsManual = true
    let preparation = track.preparation
    var saved = LibrarySnapshot()
    let otherAnalysis = try AudioAnalyzer.waveformOnly(url: fixtures.appendingPathComponent("clock-b-128.wav"))
    var other = try Track(
        title: title, artist: name, mediaFilename: otherAnalysis.contentSHA256 + ".caf", analysis: otherAnalysis)
    other.musicLibrarySources = [.init(platform: .iosMusic, persistentID: "551467752780119130")]
    saved.tracks = [other, track]
    try store.save(saved)
    let provider = DeviceProbeLibrary(item)
    let model = try ReplicaModel(
        root: root, playback: PlaybackController(offline: true), musicLibraryProvider: provider)
    await model.refreshMusicLibrary()
    if name == "Fred again.." {
        model.load(trackID: track.id, deck: .a)
    } else {
        model.loadLibraryEntry(.init(nativeItem: item, track: track), deck: .a)
    }
    await model.flushNativeMusicLoads()
    #expect(model.playback.core.snapshot()?.a.phase == .ready, "\(model.status.debugDescription)")
    #expect(model.track(.a)?.title == title)
    #expect(model.track(.a)?.artist == name)
    #expect(model.track(.a)?.preparation == preparation)
    #expect(model.library.track(id: track.id)?.nativeLibraryOnly == true)
    #expect(try store.load(includeWaveforms: false).track(id: track.id)?.nativeLibraryOnly == true)
    // A direct saved-track selection must use the same source after the repair.
    model.load(trackID: track.id, deck: .b)
    await model.flushNativeMusicLoads()
    #expect(model.loaded[.b] == track.id)
    #expect(model.playback.core.snapshot()?.b.phase == .ready, "\(model.status.debugDescription)")
    if name == "Fred again.." {
        for _ in 0..<16 {
            model.loadLibraryEntry(.init(nativeItem: item, track: track), deck: .a)
            await model.flushNativeMusicLoads()
            #expect(model.playback.core.snapshot()?.a.phase == .ready, "\(model.status.debugDescription)")
            #expect(model.trackLoadFailures[.a] == nil)
        }
    }
    await model.finishForShutdown()
}
