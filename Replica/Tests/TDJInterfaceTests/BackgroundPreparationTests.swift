import AVFoundation
import Foundation
import Testing
import TDJCore
@testable import TDJInterface

@MainActor private final class ClockMusicLibrary: LocalMusicLibraryProviding {
    let snapshot: MusicLibraryCatalog
    init(_ items: [MusicLibraryItem]) { snapshot = .init(items: items, playlists: []) }
    func catalog() async throws -> MusicLibraryCatalog { snapshot }
    func prepare(_ item: MusicLibraryItem, in directory: URL) async throws -> PreparedMusicLibraryAudio {
        .init(url: try #require(item.assetURL), metadata: .init(item: item))
    }
}

private func clockFixture() -> URL {
    var root = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 { root.deleteLastPathComponent() }
    return root.appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/clock-a-120.wav")
}
private func clockItem(_ id: String, duration: Double) -> MusicLibraryItem {
    .init(source: .init(platform: .iosMusic, persistentID: id), title: "Clock \(id)", artist: "Fixture", duration: duration,
          assetURL: clockFixture(), availability: .available)
}
@MainActor private func preparationModel(_ items: [MusicLibraryItem], sources: [URL] = []) throws -> (ReplicaModel, URL) {
    let workspace = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let model = try ReplicaModel(root: workspace, playback: PlaybackController(offline: true),
                                 musicLibraryProvider: ClockMusicLibrary(items), automaticTraktorSources: sources)
    return (model, workspace)
}

@Test @MainActor func analyserStartsWhenTheLibraryOpensAndGivesBPMs() async throws {
    let (model, workspace) = try preparationModel([clockItem("4660", duration: 16)])
    defer { try? FileManager.default.removeItem(at: workspace) }
    await model.openNativeMusicLibrary()
    await model.flushNativeMusicAnalysis()
    let track = try #require(model.library.tracks.first)
    #expect(abs((track.bpm ?? 0) - 120) < 0.5)
    #expect(model.analysisProgress == nil)
    let log = try String(contentsOf: workspace.appendingPathComponent("analysis.log"), encoding: .utf8)
    #expect(log.contains("Analysis queue: 1 songs"))
}

@Test @MainActor func mixesGetOnlyTheirOpeningAnalysedAndAreNotRepeated() async throws {
    let mix = clockItem("4661", duration: 19 * 60 + 1)
    let (model, workspace) = try preparationModel([mix])
    defer { try? FileManager.default.removeItem(at: workspace) }
    await model.openNativeMusicLibrary()
    await model.flushNativeMusicAnalysis()
    let hint = try #require(model.analysisHints.entries[mix.id])
    #expect(hint.isMix && abs((hint.bpm ?? 0) - 120) < 0.5)
    #expect(model.library.tracks.isEmpty)
    #expect(model.browserHints[mix.id]?.isMix == true)
    // No leftover exports, and a later session skips the stored mix.
    let names = try FileManager.default.contentsOfDirectory(atPath: workspace.path)
    #expect(!names.contains { $0.hasPrefix(".native-source-") })
    let reopened = try ReplicaModel(root: workspace, playback: PlaybackController(offline: true), musicLibraryProvider: ClockMusicLibrary([mix]))
    #expect(reopened.analysisHints.entries[mix.id] == hint)
    let catalog = MusicLibraryCatalog(items: [mix], playlists: [])
    #expect(MusicLibraryReconciliation(catalog: catalog, tracks: []).analysisOrder(loaded: [], analysedMixes: [mix.id]).isEmpty)
}

@Test @MainActor func staleTemporaryExportsAreRemovedBeforeAnalysis() async throws {
    let (model, workspace) = try preparationModel([])
    defer { try? FileManager.default.removeItem(at: workspace) }
    let stale = workspace.appendingPathComponent(".native-source-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: stale, withIntermediateDirectories: true)
    try Data(count: 64).write(to: stale.appendingPathComponent("left.caf"))
    await model.removeStaleNativeSources()
    #expect(!FileManager.default.fileExists(atPath: stale.path))
}

private func collectionXML(bpm: Int, persistentHex: String) -> Data {
    Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <NML VERSION="17"><HEAD PROGRAM="Traktor DJ"/><COLLECTION ENTRIES="1">
    <ENTRY UUID="e" TITLE="Clock" ARTIST="Fixture"><ITUNES PERSISTENT_ID="\(persistentHex)" PLAYTIME="16000"/>
    <MUSICAL_KEY VALUE="21"/><TEMPO BPM="\(bpm)"/><CUE_V2 HOTCUE="-1" START="0" TYPE="4"/></ENTRY></COLLECTION></NML>
    """.utf8)
}

@Test @MainActor func collectionImportsAtLaunchAndGivesEverySongItsTempoAndKey() async throws {
    let inbox = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".nml")
    defer { try? FileManager.default.removeItem(at: inbox) }
    try collectionXML(bpm: 127, persistentHex: "0000000000001234").write(to: inbox)
    let item = MusicLibraryItem(source: .init(platform: .iosMusic, persistentID: String(0x1234)), title: "Clock", artist: "Fixture",
                                duration: 16, assetURL: nil, availability: .notDownloaded)
    let (model, workspace) = try preparationModel([item], sources: [inbox])
    defer { try? FileManager.default.removeItem(at: workspace) }
    // The launch sequence: open the Music library and refresh preparation.
    await model.refreshMusicLibrary()
    await model.refreshTraktorPreparation()
    #expect(model.traktorPreparationRecords == 1)
    #expect(model.browserHints[item.id]?.bpm == 127)
    #expect(model.browserHints[item.id]?.key != nil)
}

@Test @MainActor func linkedCollectionIsImportedAgainWhenItChanges() async throws {
    let linked = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".nml")
    defer { try? FileManager.default.removeItem(at: linked) }
    try collectionXML(bpm: 121, persistentHex: "0000000000005678").write(to: linked)
    let item = MusicLibraryItem(source: .init(platform: .iosMusic, persistentID: String(0x5678)), title: "Clock", artist: "Fixture",
                                duration: 16, assetURL: nil, availability: .notDownloaded)
    let (model, workspace) = try preparationModel([item])
    defer { try? FileManager.default.removeItem(at: workspace) }
    await model.refreshMusicLibrary()
    await model.importTraktorPreparation(linked)
    #expect(model.browserHints[item.id]?.bpm == 121)
    try collectionXML(bpm: 125, persistentHex: "0000000000005678").write(to: linked)
    await model.refreshTraktorPreparation(force: true)
    #expect(model.browserHints[item.id]?.bpm == 125)
}
