import Foundation
import Observation
import Testing

@testable import TDJCore
@testable import TDJInterface

private final class StorageNotificationCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var stored = 0
    func increment() { lock.withLock { stored += 1 } }
    var value: Int { lock.withLock { stored } }
}
private func storageMilliseconds(_ duration: Duration) -> Double {
    let value = duration.components
    return Double(value.seconds) * 1000 + Double(value.attoseconds) / 1e15
}
private func storageTrack(_ number: Int) throws -> Track {
    let hex = String(number, radix: 16)
    let identity = String(repeating: "0", count: 64 - hex.count) + hex
    let analysis = AudioAnalysis(
        implementation: "storage-test", configurationID: "storage-test", contentSHA256: identity, sampleRate: 48000,
        frameCount: 48000, channelCount: 2, waveformFramesPerBin: 512, waveform: [], bpm: 120, beatAnchorFrame: 0,
        tempoConfidence: 1, key: nil, keyConfidence: 0, chroma: [], timbre: [])
    return try Track(
        title: "Storage \(number): " + String(repeating: "s", count: 96), mediaFilename: "storage.caf",
        analysis: analysis)
}
@MainActor private func storageModel() throws -> (ReplicaModel, URL) {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    return (try ReplicaModel(root: root, playback: PlaybackController(offline: true)), root)
}
@inline(never) @MainActor private func populateStorageModel(
    _ model: ReplicaModel, count: Int, worker: BackgroundFileWork
) async throws {
    let store = model.store
    let prepared = await worker.run {
        Result {
            var snapshot = LibrarySnapshot()
            snapshot.tracks = try (1...count).map(storageTrack)
            return try store.metadataSnapshot(snapshot)
        }
    }
    model.library = try prepared.get()
}
@MainActor private func storageNotification(_ model: ReplicaModel, change: () -> Void) -> Int {
    let counter = StorageNotificationCounter()
    withObservationTracking {
        _ = model.library.revision
        _ = model.library.tracks.count
    } onChange: {
        counter.increment()
    }
    change()
    return counter.value
}
@Test @MainActor func modelLibraryStoragePreservesObservationAndPublicMutation() async throws {
    let (model, root) = try storageModel()
    defer { try? FileManager.default.removeItem(at: root) }
    var original = LibrarySnapshot()
    original.revision = 7
    original.tracks = [try storageTrack(1)]
    model.library = original
    #expect(storageNotification(model) { model.library = original } == 0)
    var changed = original
    changed.tracks[0].title = "Same revision change"
    #expect(storageNotification(model) { model.library = changed } == 1)
    #expect(model.library.tracks[0].title == "Same revision change")
    #expect(storageNotification(model) { model.library.tracks[0].artist = "Nested" } == 1)
    let second = try storageTrack(2)
    #expect(storageNotification(model) { model.library.tracks.append(second) } == 1)
    #expect(original.tracks.count == 1 && original.tracks[0].artist.isEmpty)
    let catalogue = StorageNotificationCounter()
    withObservationTracking {
        _ = model.musicLibraryCatalog
    } onChange: {
        catalogue.increment()
    }
    let version = model.musicLibraryCatalogVersion
    model.musicLibraryCatalog = nil
    #expect(catalogue.value == 1)
    #expect(model.musicLibraryCatalogVersion == version + 1)
    await model.finishForShutdown()
}
@Test @MainActor func modelLibraryPublicMutationsKeepBaselineGrowth() async throws {
    let (model, root) = try storageModel()
    defer { try? FileManager.default.removeItem(at: root) }
    let values = try (1...5000).map(storageTrack)
    let clock = ContinuousClock()
    var append: [Double] = []
    var nested: [Double] = []
    for count in [1024, 5000] {
        model.library = LibrarySnapshot()
        model.library.tracks.reserveCapacity(count)
        let began = clock.now
        for value in values.prefix(count) { model.library.tracks.append(value) }
        append.append(storageMilliseconds(began.duration(to: clock.now)))
        #expect(model.library.tracks.count == count)
        let edits = clock.now
        for index in 0..<count { model.library.tracks[index].artist = "Edited" }
        nested.append(storageMilliseconds(edits.duration(to: clock.now)))
        #expect(model.library.tracks.allSatisfy { $0.artist == "Edited" })
    }
    print("MODEL_STORAGE_MUTATION append=\(append) nested=\(nested) diagnosticScaling=true audioAcceptance=false")
    #expect(append[1] < max(append[0], 0.001) * 12)
    #expect(nested[1] < max(nested[0], 0.001) * 12)
    await model.finishForShutdown()
}
@Test @MainActor func modelWholeLibraryReplacementDoesNotRetireLargeArraysOnMain() async throws {
    let (model, root) = try storageModel()
    defer { try? FileManager.default.removeItem(at: root) }
    let worker = BackgroundFileWork(label: "test.model-storage-input")
    let clock = ContinuousClock()
    var timings: [Double] = []
    for _ in 0..<3 {
        try await populateStorageModel(model, count: 115000, worker: worker)
        _ = await worker.run { true }
        let began = clock.now
        model.library = LibrarySnapshot()
        timings.append(storageMilliseconds(began.duration(to: clock.now)))
    }
    print("MODEL_STORAGE_REPLACE noDeliberateAlias=\(timings) diagnosticScaling=true audioAcceptance=false")
    #expect(
        timings.sorted()[1] < 2,
        "Whole-value publication must not synchronously dispose of a large model-owned snapshot. This 2 ms scalability guard is separate from the unchanged 20 ms audio/control gate."
    )
    await model.finishForShutdown()
}
@inline(never) @MainActor private func captureMainRawAlias(_ model: ReplicaModel) -> LibrarySnapshot { model.library }
@inline(never) private func dropMainRawAlias(_ alias: inout LibrarySnapshot?) { alias = nil }
private func waitForQueuedStorageRetirement() async { await drainQueuedBackgroundRetirements() }
@Test @MainActor func modelRawMainAliasRemainsAnExplicitRetirementLimit() async throws {
    let (model, root) = try storageModel()
    defer { try? FileManager.default.removeItem(at: root) }
    let worker = BackgroundFileWork(label: "test.model-storage-raw-alias")
    try await populateStorageModel(model, count: 115000, worker: worker)
    var rawAlias: LibrarySnapshot? = captureMainRawAlias(model)
    withExtendedLifetime(rawAlias) { model.library = LibrarySnapshot() }
    await waitForQueuedStorageRetirement()
    await Task.yield()
    #expect(rawAlias?.tracks.count == 115000)
    let clock = ContinuousClock()
    let began = clock.now
    dropMainRawAlias(&rawAlias)
    let elapsed = storageMilliseconds(began.duration(to: clock.now))
    print(
        "MODEL_STORAGE_RAW_ALIAS explicitMainDropMilliseconds=\(elapsed) guaranteeExcludesRawAliases=true audioAcceptance=false"
    )
    #expect(rawAlias == nil && model.library.tracks.isEmpty)
    await model.finishForShutdown()
}

@Test @MainActor func modelBackgroundReadOwnersKeepOldInputsWhilePublicEditsStayIndependent() async throws {
    let (model, root) = try storageModel()
    defer { try? FileManager.default.removeItem(at: root) }
    var initial = LibrarySnapshot()
    initial.tracks = [try storageTrack(1)]
    model.library = initial
    let oldLibrary = model.libraryReadSource()
    let item = MusicLibraryItem(
        source: .init(platform: .iosMusic, persistentID: "captured"), title: "Captured", artist: "Artist",
        assetURL: nil, availability: .available)
    model.musicLibraryCatalog = .init(items: [item], playlists: [])
    let oldCatalog = model.catalogReadSource()
    let worker = BackgroundFileWork(label: "test.model-owned-read")
    let (started, continuation) = AsyncStream<Void>.makeStream()
    let release = DispatchSemaphore(value: 0)
    let read = Task {
        await worker.run {
            continuation.yield(())
            let resumed = release.wait(timeout: .now() + 5) == .success
            return (oldLibrary.withValue { $0.tracks[0].title }, oldCatalog?.withValue { $0.items.first?.id }, resumed)
        }
    }
    var starts = started.makeAsyncIterator()
    _ = await starts.next()
    model.library.tracks[0].title = "New title"
    model.musicLibraryCatalog = nil
    release.signal()
    let result = await read.value
    continuation.finish()
    #expect(result.2)
    #expect(result.0 != model.library.tracks[0].title)
    #expect(result.0 == initial.tracks[0].title)
    #expect(result.1 == item.id)
    #expect(model.musicLibraryCatalog == nil)
    await model.finishForShutdown()
}
