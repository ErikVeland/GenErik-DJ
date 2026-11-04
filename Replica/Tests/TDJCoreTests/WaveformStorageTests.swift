import CryptoKit
import Foundation
import Testing

@testable import TDJCore

private func storageTrack(_ number: Int, bins: Int = 1000, level: Float = 0.2) throws -> Track {
    let id = String(format: "%064x", number)
    let waveform = (0..<bins).map { i in
        WaveformBin(
            minimum: -level * Float(i % 17) / 17, maximum: level * Float(i % 23) / 23,
            rms: level * Float(i % 11 + 1) / 11)
    }
    let analysis = AudioAnalysis(
        implementation: "storage-test", configurationID: "storage-test-v1", contentSHA256: id, sampleRate: 48000,
        frameCount: Int64(bins) * 480, channelCount: 2, waveformFramesPerBin: 480, waveform: waveform, bpm: 120,
        beatAnchorFrame: 0, tempoConfidence: 1, key: .init(tonic: 0, mode: .major), keyConfidence: 1,
        chroma: Array(repeating: 0.1, count: 12), timbre: Array(repeating: 0.1, count: 7))
    return try Track(title: "Track \(number)", mediaFilename: id + ".wav", analysis: analysis)
}
private func storageContext(_ library: LibrarySnapshot) -> SuggestionContext {
    .init(
        referenceTrackID: library.tracks[0].id, destination: .b, usePerformanceBPM: false, loadedTrackIDs: [],
        libraryRevision: library.revision, historyRevision: library.adaptiveMemory.revision)
}

@Test func waveformPayloadPreservesSamplesEnergyAndRecommendationOrder() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try WorkspaceStore(root: root)
    var original = LibrarySnapshot()
    original.tracks = try [storageTrack(1), storageTrack(2, level: 0.22), storageTrack(3, level: 0.8)]
    let compact = try store.save(original)
    #expect(compact.schemaVersion == 2)
    #expect(compact.tracks.allSatisfy { $0.analysis.waveform.isEmpty && $0.analysis.waveformReference != nil })
    #expect(try Data(contentsOf: store.libraryURL).count < 10000)
    let restored = try store.load()
    for (a, b) in zip(original.tracks, restored.tracks) {
        #expect(a.analysis.waveform == b.analysis.waveform)
        #expect(a.analysis.waveform.first?.minimum.bitPattern == b.analysis.waveform.first?.minimum.bitPattern)
        #expect(PerformerSuggestions.energyLevel(a.analysis) == PerformerSuggestions.energyLevel(b.analysis))
    }
    #expect(
        try PerformerSuggestions.rank(library: original, context: storageContext(original)).map(\.id)
            == PerformerSuggestions.rank(library: compact, context: storageContext(compact)).map(\.id))
    let reference = try #require(compact.tracks[0].analysis.waveformReference)
    let payload = store.waveformDirectory.appendingPathComponent(reference)
    let old = try Data(contentsOf: payload)
    let date = Date(timeIntervalSince1970: 100)
    try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: payload.path)
    let unchangedDate = try #require(
        FileManager.default.attributesOfItem(atPath: payload.path)[.modificationDate] as? Date)
    var edited = compact
    try edited.tracks[0].preparation.grid?.halveBPM()
    edited.revision += 1
    try store.save(edited)
    #expect(try Data(contentsOf: payload) == old)
    #expect(try FileManager.default.attributesOfItem(atPath: payload.path)[.modificationDate] as? Date == unchangedDate)
    #expect(try store.load().tracks[0].bpm == 60)
}

@Test func legacyWaveformsMigrateWithOriginalLibraryBackup() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try WorkspaceStore(root: root)
    var legacy = LibrarySnapshot()
    legacy.tracks = try [storageTrack(4)]
    let original = try JSONEncoder().encode(legacy)
    try original.write(to: store.libraryURL)
    var compact = try store.load(includeWaveforms: false)
    #expect(compact.tracks[0].analysis.waveform.isEmpty)
    #expect(try Data(contentsOf: store.libraryURL) == original)
    compact.revision += 1
    let saved = try store.save(compact)
    #expect(saved.schemaVersion == 2)
    let backup = root.appendingPathComponent("library.before-waveform-storage.json")
    #expect(try Data(contentsOf: backup) == original)
    #expect(try store.load().tracks[0].analysis.waveform == legacy.tracks[0].analysis.waveform)
    try store.save(saved)
    #expect(try Data(contentsOf: backup) == original)
}

@Test func waveformCorruptionAndUnsafeReferencesDoNotRewriteTheLibrary() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try WorkspaceStore(root: root)
    var source = LibrarySnapshot()
    source.tracks = try [storageTrack(5)]
    let compact = try store.save(source)
    let original = try Data(contentsOf: store.libraryURL)
    let reference = try #require(compact.tracks[0].analysis.waveformReference)
    let payload = store.waveformDirectory.appendingPathComponent(reference)
    var damaged = try Data(contentsOf: payload)
    damaged[48] ^= 0x40
    try damaged.write(to: payload, options: .atomic)
    #expect(try store.load(includeWaveforms: false).tracks.count == 1)
    #expect(throws: (any Error).self) { try store.hydrate(compact.tracks[0]) }
    var invalid = compact
    invalid.tracks[0].analysis.waveformReference = "../outside.tdjwave"
    #expect(throws: (any Error).self) { try store.save(invalid) }
    #expect(try Data(contentsOf: store.libraryURL) == original)
}

@Test func libraryIndexSizeDoesNotScaleWithWaveformLength() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let short = try WorkspaceStore(root: root.appendingPathComponent("short"))
    let long = try WorkspaceStore(root: root.appendingPathComponent("long"))
    var a = LibrarySnapshot()
    var b = LibrarySnapshot()
    a.tracks = try (10..<15).map { try storageTrack($0, bins: 600) }
    b.tracks = try (10..<15).map { try storageTrack($0, bins: 60000) }
    try short.save(a)
    try long.save(b)
    let compact = try long.load(includeWaveforms: false)
    #expect(compact.tracks.allSatisfy { $0.analysis.waveform.isEmpty })
    #expect(try Data(contentsOf: long.libraryURL).count < Data(contentsOf: short.libraryURL).count + 100)
    #expect(try long.hydrate(compact.tracks[0]).analysis.waveform.count == 60000)
}

@Test func incompleteWaveformWithValidChecksumIsRejected() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try WorkspaceStore(root: root)
    var source = LibrarySnapshot()
    source.tracks = try [storageTrack(6, bins: 10)]
    let compact = try store.save(source)
    let track = compact.tracks[0]
    let filename = try #require(track.analysis.waveformReference)
    let payload = store.waveformDirectory.appendingPathComponent(filename)
    let original = try Data(contentsOf: payload)
    for count in [0, 9] {
        var shortened = Data(original.prefix(40 + count * 12))
        var word = UInt64(count).littleEndian
        withUnsafeBytes(of: &word) { shortened.replaceSubrange(32..<40, with: $0) }
        shortened.append(contentsOf: SHA256.hash(data: shortened))
        try shortened.write(to: payload, options: .atomic)
        #expect(throws: (any Error).self) { try store.hydrate(track) }
    }
    try original.write(to: payload, options: .atomic)
    #expect(try store.hydrate(track).analysis.waveform.count == 10)
}

@Test func missingWaveformCacheRebuildsWithoutChangingPreparationOrRankMetadata() async throws {
    var base = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 { base.deleteLastPathComponent() }
    let source = base.appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/clock-a-120.wav")
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try WorkspaceStore(root: root)
    let service = try LibraryService(store: store)
    let library = try await service.importAudio(url: source)
    var track = try #require(library.tracks.first)
    try track.preparation.grid?.halveBPM()
    track.preparation.gridIsManual = true
    let filename = try #require(track.analysis.waveformReference)
    try FileManager.default.removeItem(at: store.waveformDirectory.appendingPathComponent(filename))
    let restored = try await store.hydrateAsync(track)
    #expect(!restored.analysis.waveform.isEmpty)
    #expect(restored.preparation == track.preparation)
    #expect(restored.analysis.cachedEnergyLevel == track.analysis.cachedEnergyLevel)
    #expect(restored.analysis.waveformReference == filename)
    #expect(try store.hydrate(track).analysis.waveform == restored.analysis.waveform)
}
