import Dispatch
import Foundation
import Testing

@testable import TDJCore

private func automaticPreparationData(_ bpm: Int = 123) -> Data {
    Data(
        "<NML VERSION=\"17\"><HEAD PROGRAM=\"Traktor DJ\"/><COLLECTION ENTRIES=\"1\"><ENTRY UUID=\"seed\"><ITUNES PERSISTENT_ID=\"0000000000001234\" PLAYTIME=\"16000\"/><TEMPO BPM=\"\(bpm)\"/><MUSICAL_KEY VALUE=\"21\"/><CUE_V2 TYPE=\"4\" START=\"1000\" HOTCUE=\"-1\"/></ENTRY></COLLECTION></NML>"
            .utf8)
}
private func automaticPreparationFixture() throws -> (URL, WorkspaceStore, URL) {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return (
        root, try WorkspaceStore(root: root.appendingPathComponent("workspace")),
        root.appendingPathComponent("seed.nml")
    )
}
private func automaticPreparationPointer(_ store: WorkspaceStore) -> URL {
    store.root.appendingPathComponent("TraktorReferences/current.json")
}

@Test func explicitAutomaticPreparationSeedBootstrapsWithoutSyncedFolderAccess() async throws {
    let (root, store, seed) = try automaticPreparationFixture()
    defer { try? FileManager.default.removeItem(at: root) }
    let data = automaticPreparationData()
    try data.write(to: seed)
    let catalog = try #require(try await TraktorPreparationStorage.discover(store: store, automaticSources: [seed]))
    #expect(catalog.summary.document.entryCount == 1)
    #expect(try Data(contentsOf: seed) == data)
    let archive = store.root.appendingPathComponent("TraktorReferences/\(catalog.summary.sourceSHA256).collection")
    #expect(try Data(contentsOf: archive) == data)
    let repeated = try #require(try await TraktorPreparationStorage.discover(store: store, automaticSources: [seed]))
    #expect(repeated.summary.sourceSHA256 == catalog.summary.sourceSHA256)
}

@Test func automaticPreparationRefreshUsesOrderedSourcesAndUpdatesOnlyAutomaticSelection() async throws {
    let (root, store, seed) = try automaticPreparationFixture()
    defer { try? FileManager.default.removeItem(at: root) }
    try automaticPreparationData().write(to: seed)
    let initial = try #require(try await TraktorPreparationStorage.discover(store: store, automaticSources: [seed]))
    let inbox = root.appendingPathComponent("inbox.nml")
    try automaticPreparationData(127).write(to: inbox)
    let changed = try #require(
        try await TraktorPreparationStorage.discover(store: store, automaticSources: [inbox, seed]))
    #expect(changed.summary.sourceSHA256 != initial.summary.sourceSHA256)
    try FileManager.default.removeItem(at: inbox)
    try FileManager.default.removeItem(at: seed)
    let fallback = try #require(
        try await TraktorPreparationStorage.discover(store: store, automaticSources: [inbox, seed]))
    #expect(fallback.summary.sourceSHA256 == changed.summary.sourceSHA256)
}

@Test func explicitManualPreparationSelectionBeatsLaterAutomaticSeed() async throws {
    let (root, store, seed) = try automaticPreparationFixture()
    defer { try? FileManager.default.removeItem(at: root) }
    try automaticPreparationData().write(to: seed)
    let selected = try await TraktorPreparationStorage.importCollection(at: seed, store: store)
    let pointer = try Data(contentsOf: automaticPreparationPointer(store))
    let replacement = root.appendingPathComponent("replacement.nml")
    try automaticPreparationData(127).write(to: replacement)
    let found = try #require(
        try await TraktorPreparationStorage.discover(store: store, automaticSources: [replacement]))
    #expect(found.summary.sourceSHA256 == selected.summary.sourceSHA256)
    #expect(try Data(contentsOf: automaticPreparationPointer(store)) == pointer)
}

@Test func legacyPreparationPointerRetainsItsExplicitSelection() async throws {
    let (root, store, seed) = try automaticPreparationFixture()
    defer { try? FileManager.default.removeItem(at: root) }
    try automaticPreparationData().write(to: seed)
    let selected = try await TraktorPreparationStorage.importCollection(at: seed, store: store)
    let legacy = Data("{\"digest\":\"\(selected.summary.sourceSHA256)\"}".utf8)
    try legacy.write(to: automaticPreparationPointer(store), options: .atomic)
    try automaticPreparationData(127).write(to: seed)
    let found = try #require(try await TraktorPreparationStorage.discover(store: store, automaticSources: [seed]))
    #expect(found.summary.sourceSHA256 == selected.summary.sourceSHA256)
    #expect(try Data(contentsOf: automaticPreparationPointer(store)) == legacy)
}

@Test func invalidAutomaticPreparationReplacementPreservesTheActiveArchive() async throws {
    let (root, store, seed) = try automaticPreparationFixture()
    defer { try? FileManager.default.removeItem(at: root) }
    try automaticPreparationData().write(to: seed)
    let initial = try #require(try await TraktorPreparationStorage.discover(store: store, automaticSources: [seed]))
    let pointer = try Data(contentsOf: automaticPreparationPointer(store))
    try Data("<NML>broken".utf8).write(to: seed)
    do {
        _ = try await TraktorPreparationStorage.discover(store: store, automaticSources: [seed])
        Issue.record("An invalid automatic replacement must report its failure.")
    } catch {}
    #expect(try Data(contentsOf: automaticPreparationPointer(store)) == pointer)
    let retained = try #require(try await TraktorPreparationStorage.discover(store: store))
    #expect(retained.summary.sourceSHA256 == initial.summary.sourceSHA256)
}

@Test func missingAutomaticPreparationHasAnExplicitEmptyOutcome() async throws {
    let (root, store, seed) = try automaticPreparationFixture()
    defer { try? FileManager.default.removeItem(at: root) }
    #expect(try await TraktorPreparationStorage.discover(store: store, automaticSources: [seed]) == nil)
    #expect(!FileManager.default.fileExists(atPath: automaticPreparationPointer(store).path))
}

@Test func libraryServiceUsesItsConfiguredAutomaticPreparationSeedOnLaunch() async throws {
    let (root, store, seed) = try automaticPreparationFixture()
    defer { try? FileManager.default.removeItem(at: root) }
    try automaticPreparationData().write(to: seed)
    let service = try LibraryService(store: store, automaticTraktorSources: [seed])
    let first = try #require(try await service.refreshTraktorReferences())
    #expect(first.document.entryCount == 1)
    try automaticPreparationData(127).write(to: seed)
    let refreshed = try #require(try await service.refreshTraktorReferences(force: true))
    #expect(refreshed.sourceSHA256 != first.sourceSHA256)
}

@Test func cancelledAutomaticPreparationReplacementKeepsThePriorSelection() async throws {
    let (root, store, seed) = try automaticPreparationFixture()
    defer { try? FileManager.default.removeItem(at: root) }
    try automaticPreparationData().write(to: seed)
    _ = try #require(try await TraktorPreparationStorage.discover(store: store, automaticSources: [seed]))
    let pointer = try Data(contentsOf: automaticPreparationPointer(store))
    try automaticPreparationData(127).write(to: seed)
    let (entered, signal) = AsyncStream<Void>.makeStream()
    let release = DispatchSemaphore(value: 0)
    let held = Task {
        try await AnalysisWorker.shared.run { _ in
            signal.yield(())
            release.wait()
            return true
        }
    }
    defer {
        release.signal()
        signal.finish()
    }
    var events = entered.makeAsyncIterator()
    _ = await events.next()
    let refresh = Task { try await TraktorPreparationStorage.discover(store: store, automaticSources: [seed]) }
    refresh.cancel()
    release.signal()
    _ = try await held.value
    do {
        _ = try await refresh.value
        Issue.record("Cancelled discovery must not replace the active collection.")
    } catch is CancellationError {}
    #expect(try Data(contentsOf: automaticPreparationPointer(store)) == pointer)
}

@Test func manuallySelectingTheSameAutomaticCollectionLocksItsSelection() async throws {
    let (root, store, seed) = try automaticPreparationFixture()
    defer { try? FileManager.default.removeItem(at: root) }
    try automaticPreparationData().write(to: seed)
    let automatic = try #require(try await TraktorPreparationStorage.discover(store: store, automaticSources: [seed]))
    let manual = try await TraktorPreparationStorage.importCollection(at: seed, store: store)
    #expect(manual.summary.sourceSHA256 == automatic.summary.sourceSHA256)
    let pointer = try Data(contentsOf: automaticPreparationPointer(store))
    try automaticPreparationData(127).write(to: seed)
    let unchanged = try #require(try await TraktorPreparationStorage.discover(store: store, automaticSources: [seed]))
    #expect(unchanged.summary.sourceSHA256 == manual.summary.sourceSHA256)
    #expect(try Data(contentsOf: automaticPreparationPointer(store)) == pointer)
}

@Test func failedAutomaticServiceRefreshKeepsItsPreviousCatalogAndReportsWarning() async throws {
    let (root, store, seed) = try automaticPreparationFixture()
    defer { try? FileManager.default.removeItem(at: root) }
    try automaticPreparationData().write(to: seed)
    let service = try LibraryService(store: store, automaticTraktorSources: [seed])
    let selected = try #require(try await service.refreshTraktorReferences())
    let pointer = try Data(contentsOf: automaticPreparationPointer(store))
    try Data("<NML>broken".utf8).write(to: seed)
    do {
        _ = try await service.refreshTraktorReferences(force: true)
        Issue.record("An invalid configured collection must report its failure.")
    } catch {}
    #expect(await service.traktorReferenceWarning != nil)
    let retained = try #require(try await service.refreshTraktorReferences())
    #expect(retained.sourceSHA256 == selected.sourceSHA256)
    #expect(try Data(contentsOf: automaticPreparationPointer(store)) == pointer)
}
