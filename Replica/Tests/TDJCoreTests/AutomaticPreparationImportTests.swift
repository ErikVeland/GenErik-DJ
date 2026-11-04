import AVFoundation
import Foundation
import Testing

@testable import TDJCore

private func importFixture() -> URL {
    var root = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 { root.deleteLastPathComponent() }
    return root.appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/clock-a-120.wav")
}
private func importCollection(duration: Double, bpm: Int = 123) -> Data {
    Data(
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <NML VERSION="17"><HEAD PROGRAM="Traktor DJ"/><COLLECTION ENTRIES="1">
        <ENTRY UUID="original-track" TITLE="Reference clock" ARTIST="Synthetic">
        <ITUNES PERSISTENT_ID="3B3D1D51BE612BD2" PLAYTIME="\(duration * 1000)"/>
        <MUSICAL_KEY VALUE="21"/><TEMPO BPM="\(bpm)"/>
        <CUE_V2 NAME="AutoGrid" HOTCUE="-1" START="1000" TYPE="4"/>
        </ENTRY></COLLECTION></NML>
        """.utf8)
}
private final class ProgressLog: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [[Int]] = []
    func add(_ done: Int, _ total: Int) {
        lock.lock()
        values.append([done, total])
        lock.unlock()
    }
    var all: [[Int]] {
        lock.lock()
        defer { lock.unlock() }
        return values
    }
}

/// A launch with a library that already holds the song: the automatic source is read, never changed.
private func importedLibrary() async throws -> (URL, WorkspaceStore, URL, LibraryService) {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let store = try WorkspaceStore(root: root.appendingPathComponent("workspace"))
    let duration = try {
        let file = try AVAudioFile(forReading: importFixture())
        return Double(file.length) / file.processingFormat.sampleRate
    }()
    let item = MusicLibraryItem(
        source: .init(platform: .iosMusic, persistentID: String(UInt64("3B3D1D51BE612BD2", radix: 16)!)),
        title: "Reference clock", artist: "Synthetic", duration: duration, assetURL: importFixture(),
        availability: .available)
    _ = try await LibraryService(store: store).importAudio(url: importFixture(), musicLibrary: .init(item: item))
    let inbox = root.appendingPathComponent("collection.nml")
    try importCollection(duration: duration).write(to: inbox)
    return (root, store, inbox, try LibraryService(store: store, automaticTraktorSources: [inbox]))
}

@Test func automaticImportAppliesPreparationReportsProgressAndLeavesTheSourceUntouched() async throws {
    let (root, store, inbox, service) = try await importedLibrary()
    defer { try? FileManager.default.removeItem(at: root) }
    let original = try Data(contentsOf: inbox)
    let modified = try FileManager.default.attributesOfItem(atPath: inbox.path)[.modificationDate] as? Date
    let log = ProgressLog()
    _ = try #require(try await service.refreshTraktorReferences())
    let snapshot = try await service.reuseTraktorPreparationForExistingTracks(progress: { log.add($0, $1) })
    #expect(snapshot.tracks.first?.traktorPreparation != nil)
    #expect(log.all == [[0, 1], [1, 1]])
    #expect(try Data(contentsOf: inbox) == original)
    #expect(try FileManager.default.attributesOfItem(atPath: inbox.path)[.modificationDate] as? Date == modified)
    // Saved as it goes: a fresh launch sees the applied preparation without another pass.
    #expect(
        try store.load(includeWaveforms: false).tracks.first?.traktorPreparation
            == snapshot.tracks.first?.traktorPreparation)
}

@Test func repeatedAutomaticImportsNeverDuplicateArchivesOrRewriteTheLibrary() async throws {
    let (root, store, _, service) = try await importedLibrary()
    defer { try? FileManager.default.removeItem(at: root) }
    _ = try await service.refreshTraktorReferences()
    let first = try await service.reuseTraktorPreparationForExistingTracks()
    for _ in 0..<3 {
        let relaunched = try LibraryService(
            store: store, automaticTraktorSources: [root.appendingPathComponent("collection.nml")])
        _ = try await relaunched.refreshTraktorReferences(force: true)
        let again = try await relaunched.reuseTraktorPreparationForExistingTracks()
        #expect(again.revision == first.revision)
        #expect(again.tracks == first.tracks)
    }
    let archives = try FileManager.default.contentsOfDirectory(
        atPath: store.root.appendingPathComponent("TraktorReferences").path
    ).filter { $0.hasSuffix(".collection") }
    #expect(archives.count == 1)
}

@Test func importSavesEachBatchSoARelaunchResumesWithoutRepeatingWork() async throws {
    let (root, store, _, service) = try await importedLibrary()
    defer { try? FileManager.default.removeItem(at: root) }
    _ = try await service.refreshTraktorReferences()
    // Batch size one saves after every applied track, before progress reports it.
    let log = ProgressLog()
    _ = try await service.reuseTraktorPreparationForExistingTracks(batchSize: 1, progress: { log.add($0, $1) })
    let saved = try store.load(includeWaveforms: false)
    #expect(saved.tracks.first?.traktorPreparation != nil)
    let resumed = try LibraryService(
        store: store, automaticTraktorSources: [root.appendingPathComponent("collection.nml")])
    _ = try await resumed.refreshTraktorReferences()
    #expect(try await resumed.reuseTraktorPreparationForExistingTracks().revision == saved.revision)
}

@Test func missingAutomaticSourceReportsNothingAndChangesNothing() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try WorkspaceStore(root: root)
    let service = try LibraryService(store: store, automaticTraktorSources: [root.appendingPathComponent("absent.nml")])
    #expect(try await service.refreshTraktorReferences() == nil)
    let log = ProgressLog()
    let snapshot = try await service.reuseTraktorPreparationForExistingTracks(progress: { log.add($0, $1) })
    #expect(log.all.isEmpty && snapshot.tracks.isEmpty)
}
