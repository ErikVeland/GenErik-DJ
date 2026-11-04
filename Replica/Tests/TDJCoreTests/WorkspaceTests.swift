import Foundation
import Testing

@testable import TDJCore

@Test func manualPreparationSurvivesRelaunch() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try WorkspaceStore(root: root)
    var library = LibrarySnapshot()
    library.tracks = try [syntheticTrack("a", bpm: 120)]
    try store.save(library)
    let service = try LibraryService(store: store)
    var preparation = library.tracks[0].preparation
    try preparation.grid?.halveBPM()
    preparation.gridIsManual = true
    preparation.correctedKey = .init(tonic: 2, mode: .minor)
    _ = try await service.updatePreparation(trackID: library.tracks[0].id, preparation: preparation)
    let restored = try store.load()
    #expect(restored.tracks[0].bpm == 60)
    #expect(restored.tracks[0].analysis.bpm == 120)
    #expect(restored.tracks[0].preparation.correctedKey == MusicalKey(tonic: 2, mode: .minor))
    #expect(restored.revision == 1)
}

@Test func corruptWorkspaceIsNotReplacedWithAnEmptyLibrary() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try WorkspaceStore(root: root)
    let original = Data("{broken archive".utf8)
    try original.write(to: store.libraryURL)
    #expect(throws: (any Error).self) { try store.load() }
    #expect(try Data(contentsOf: store.libraryURL) == original)
}

@Test func concurrentImportsCommitOneVerifiedLibraryEntry() async throws {
    let source = try #require(
        Bundle.module.url(forResource: "metadata-clock", withExtension: "m4a", subdirectory: "Fixtures"))
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try WorkspaceStore(root: root)
    let service = try LibraryService(store: store)
    async let first = service.importAudio(url: source)
    async let second = service.importAudio(url: source)
    _ = try await (first, second)
    let restored = try store.load()
    #expect(restored.tracks.count == 1)
    #expect(restored.revision == 1)
    let track = try #require(restored.tracks.first)
    #expect(try AudioAnalyzer.sha256(url: store.mediaDirectory.appendingPathComponent(track.mediaFilename)) == track.id)
}
