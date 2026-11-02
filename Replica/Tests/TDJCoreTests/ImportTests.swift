import Foundation
import Testing
@testable import TDJCore

@Test func concurrentImportsDeduplicateAndRetainGridCorrections() async throws {
    var base = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 { base.deleteLastPathComponent() }
    let source = base.appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/clock-a-120.wav")
    let originalHash = try AudioAnalyzer.sha256(url: source)
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try WorkspaceStore(root: root)
    let service = try LibraryService(store: store)
    async let one = service.importAudio(url: source)
    async let two = service.importAudio(url: source)
    _ = try await (one, two)
    let imported = await service.snapshot()
    #expect(imported.tracks.count == 1)
    let track = try #require(imported.tracks.first)
    #expect(try AudioAnalyzer.sha256(url: store.mediaDirectory.appendingPathComponent(track.mediaFilename)) == originalHash)
    var preparation = track.preparation
    try preparation.grid?.halveBPM()
    preparation.gridIsManual = true
    _ = try await service.updatePreparation(trackID: track.id, preparation: preparation)
    let reimported = try await service.importAudio(url: source)
    #expect(reimported.tracks.count == 1)
    #expect(reimported.tracks[0].bpm == 60)
    #expect(reimported.tracks[0].analysis.bpm == 120)
    #expect(try AudioAnalyzer.sha256(url: source) == originalHash)
}
