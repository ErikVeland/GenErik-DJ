import Foundation
import Testing

@testable import TDJCore

@Test(.enabled(if: ProcessInfo.processInfo.environment["R95_SOURCE"] != nil))
func nativeLoadingSavedDeviceProbe() async throws {
    guard let path = ProcessInfo.processInfo.environment["R95_SOURCE"],
        let libraryPath = ProcessInfo.processInfo.environment["R95_LIBRARY"]
    else { return }
    let url = URL(fileURLWithPath: path)
    let source = try await DecodedAudioSource.asset(url: url)
    var samples = [Float](repeating: 0, count: 44100)
    try samples.withUnsafeMutableBufferPointer {
        try source.read(first: 0, count: 22050, into: $0.baseAddress!)
    }
    let opening = try await NativePlaybackOpening.open(url: url, sourceIdentity: "device-probe")
    let saved = try JSONDecoder().decode(
        LibrarySnapshot.self, from: Data(contentsOf: URL(fileURLWithPath: libraryPath)))
    let track = try #require(saved.tracks.first { $0.title.contains("Hannah") })
    let item = MusicLibraryItem(
        source: try #require(track.musicLibrarySources?.first), title: track.title,
        artist: track.artist, assetURL: url, availability: .available)
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try WorkspaceStore(root: root)
    let service = try LibraryService(store: store, initial: saved)
    let registered = try await service.registerNativePlayback(
        analysis: opening.analysis, metadata: .init(item: item), audioFingerprint: opening.audioFingerprint)
    let selected = try #require(registered.track(id: track.id))
    let asset = try opening.asset()
    let transport = try SampleTransport()
    _ = try transport.reserveLoad(asset, deck: .a, grid: selected.grid, adaptiveMap: selected.adaptiveMap)
}
