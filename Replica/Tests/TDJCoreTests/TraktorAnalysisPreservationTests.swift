import AVFoundation
import Foundation
import Testing

@testable import TDJCore

private func preservationFixture() -> URL {
    var root = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 { root.deleteLastPathComponent() }
    return root.appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/clock-a-120.wav")
}
private func preservationItem(_ duration: Double) -> MusicLibraryItem {
    .init(
        source: .init(platform: .iosMusic, persistentID: "4660"), title: "Synthetic clock", artist: "Synthetic",
        duration: duration, assetURL: preservationFixture(), availability: .available)
}
private func preservationCatalogue(_ service: LibraryService, root: URL, duration: Double) async throws {
    let xml =
        "<NML VERSION=\"17\"><HEAD PROGRAM=\"Traktor DJ\"/><COLLECTION ENTRIES=\"1\"><ENTRY><ITUNES PERSISTENT_ID=\"0000000000001234\" PLAYTIME=\"\(duration*1000)\"/><TEMPO BPM=\"123\"/><MUSICAL_KEY VALUE=\"21\"/><CUE_V2 TYPE=\"4\" START=\"1000\" HOTCUE=\"-1\"/></ENTRY></COLLECTION></NML>"
    let file = root.appendingPathComponent("analysis-preservation.nml")
    try Data(xml.utf8).write(to: file)
    _ = try await service.importTraktorCollection(url: file)
}

@Test(arguments: [false, true]) func traktorDuplicateWaveformImportPreservesFullAnalysisAndPreparation(
    _ protected: Bool
) async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try WorkspaceStore(root: root)
    let service = try LibraryService(store: store)
    let file = try AVAudioFile(forReading: preservationFixture())
    let duration = Double(file.length) / file.processingFormat.sampleRate
    let item = preservationItem(duration)
    let first = try await service.importAudio(url: preservationFixture(), musicLibrary: .init(item: item))
    let before = try #require(first.tracks.first)
    #expect(before.analysis.musicalAnalysisDeferred != true)
    let energy = try #require(before.analysis.musicalEnergy)
    let energyLevel = try #require(PerformerSuggestions.energyLevel(before.analysis))
    let hydrated = try store.hydrate(before)
    try await preservationCatalogue(service, root: root, duration: duration)
    let duplicate = try await service.importAudio(
        url: preservationFixture(), musicLibrary: .init(item: item),
        preservePreparationFor: protected ? [before.id] : [])
    let after = try #require(duplicate.tracks.first)
    #expect(duplicate.tracks.count == 1)
    #expect(after.traktorPreparation?.normalized.grid?.bpm == 123)
    #expect(after.analysis == before.analysis)
    #expect(after.preparation == before.preparation)
    #expect(after.analysis.musicalAnalysisDeferred != true)
    #expect(after.analysis.musicalEnergy == energy)
    #expect(PerformerSuggestions.energyLevel(after.analysis) == energyLevel)
    #expect(try store.hydrate(after).analysis == hydrated.analysis)
    let disk = try #require(store.load(includeWaveforms: false).tracks.first)
    #expect(disk.analysis == before.analysis && disk.preparation == before.preparation)
}

@Test(arguments: ["duplicate", "reanalyze"]) func traktorDeferredAnalysisStillAcceptsFullDetection(_ method: String)
    async throws
{
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try WorkspaceStore(root: root)
    let service = try LibraryService(store: store)
    let file = try AVAudioFile(forReading: preservationFixture())
    let duration = Double(file.length) / file.processingFormat.sampleRate
    let item = preservationItem(duration)
    try await preservationCatalogue(service, root: root, duration: duration)
    let first = try await service.importAudio(url: preservationFixture(), musicLibrary: .init(item: item))
    let before = try #require(first.tracks.first)
    #expect(before.analysis.musicalAnalysisDeferred == true)
    #expect(PerformerSuggestions.energyLevel(before.analysis) == nil)
    let upgraded: LibrarySnapshot
    if method == "duplicate" {
        upgraded = try await service.importAudio(url: preservationFixture())
    } else {
        upgraded = try await service.reanalyze(trackID: before.id)
    }
    let after = try #require(upgraded.tracks.first)
    #expect(after.id == before.id)
    #expect(after.analysis.musicalAnalysisDeferred != true)
    #expect(after.analysis.configurationID != before.analysis.configurationID)
    #expect(after.analysis.musicalEnergy != nil)
    #expect(PerformerSuggestions.energyLevel(after.analysis) != nil)
    #expect(after.preparation == before.preparation)
    #expect(after.traktorPreparation == before.traktorPreparation)
    #expect(abs((after.analysis.bpm ?? 0) - 120) < 0.25)
}

@Test(arguments: [false, true]) func traktorFullAnalysisVersionUpgradeRemainsAllowed(_ manual: Bool) async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try WorkspaceStore(root: root)
    let service = try LibraryService(store: store)
    let first = try await service.importAudio(url: preservationFixture())
    let before = try #require(first.tracks.first)
    let currentConfiguration = before.analysis.configurationID
    var legacyTrack = try store.hydrate(before)
    var encoded = try #require(
        JSONSerialization.jsonObject(with: JSONEncoder().encode(legacyTrack.analysis)) as? [String: Any])
    encoded["configurationID"] = "earlier-full-detector"
    encoded.removeValue(forKey: "waveformReference")
    legacyTrack.analysis = try JSONDecoder().decode(
        AudioAnalysis.self, from: JSONSerialization.data(withJSONObject: encoded))
    legacyTrack.preparation.grid = try BeatGrid(
        bpm: manual ? 117 : 90, anchorFrame: 0, sampleRate: legacyTrack.analysis.sampleRate)
    legacyTrack.preparation.gridIsManual = manual
    if manual { legacyTrack.preparation.correctedKey = .init(tonic: 6, mode: .minor) }
    var legacy = first
    legacy.tracks = [legacyTrack]
    legacy.revision += 1
    _ = try store.save(legacy)
    let restarted = try LibraryService(store: store)
    let upgraded = try await restarted.importAudio(url: preservationFixture())
    let after = try #require(upgraded.tracks.first)
    #expect(after.analysis.configurationID == currentConfiguration)
    #expect(after.analysis.musicalAnalysisDeferred != true)
    #expect(after.analysis.musicalEnergy != nil)
    #expect(PerformerSuggestions.energyLevel(after.analysis) != nil)
    #expect(after.preparation.correctedKey == legacyTrack.preparation.correctedKey)
    #expect(after.preparation.gridIsManual == manual)
    if manual {
        #expect(after.preparation == legacyTrack.preparation)
    } else {
        #expect(abs((after.preparation.grid?.bpm ?? 0) - 120) < 0.25)
    }
}
