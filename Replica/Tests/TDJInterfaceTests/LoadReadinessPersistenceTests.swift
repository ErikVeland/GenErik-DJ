import Foundation
import TDJCore
import Testing

@testable import TDJInterface

/// Tests hold the exact persistence tail that saveGrid normally awaits. The 60 s
/// watchdog prevents a deadlocked regression from hanging the runner; it is not
/// an audio/control timing budget. Progress is asserted before explicit release.
private final class PersistenceBarrier: @unchecked Sendable {
    private let entered = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
    private let released = AsyncStream<Void>.makeStream()
    private let lock = NSLock()
    private var opened = false
    private var expired = false
    func wait() async {
        entered.continuation.yield(())
        for await _ in released.stream {}
    }
    func waitUntilEntered() async { for await _ in entered.stream { return } }
    func open(expired: Bool = false) {
        lock.withLock {
            opened = true
            self.expired = self.expired || expired
        }
        released.continuation.finish()
    }
    var isOpen: Bool { lock.withLock { opened } }
    var timedOut: Bool { lock.withLock { expired } }
    func watchdog() -> Task<Void, Never> {
        Task.detached(priority: .background) {
            do { try await Task.sleep(for: .seconds(60)) } catch { return }
            self.open(expired: true)
        }
    }
}

@MainActor private func readinessModel() async throws -> (ReplicaModel, URL, Track, Track) {
    var base = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 { base.deleteLastPathComponent() }
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
    await model.importFiles(
        ["clock-a-120.wav", "clock-b-128.wav"].map {
            base.appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/" + $0)
        })
    #expect(model.library.tracks.count == 2)
    let a = try #require(model.library.tracks.first { $0.title == "clock-a-120" })
    let b = try #require(model.library.tracks.first { $0.title == "clock-b-128" })
    model.load(trackID: a.id, deck: .a)
    await model.flushWrites()
    return (model, root, a, b)
}

private func changedGrid(_ track: Track, bpm: Double, anchor: Double = 0) throws -> BeatGrid {
    try BeatGrid(bpm: bpm, anchorFrame: anchor, sampleRate: track.analysis.sampleRate, downbeatOffset: 1)
}

@Test @MainActor func blockedGridPersistenceCannotHoldColdLoadReadyPlayOrFlushOwnership() async throws {
    let (model, root, a, b) = try await readinessModel()
    defer { try? FileManager.default.removeItem(at: root) }
    let barrier = PersistenceBarrier()
    let deadline = barrier.watchdog()
    defer {
        barrier.open()
        deadline.cancel()
    }
    model.preparationWrites = Task { await barrier.wait() }
    await barrier.waitUntilEntered()
    let oldGrid = a.grid
    let edited = try changedGrid(a, bpm: 123, anchor: 441)
    model.saveGrid(edited, deck: .a)
    let cache = model.store.root.appendingPathComponent("PlaybackCache/\(b.id)-stereo-f32-v1.pcm")
    #expect(!FileManager.default.fileExists(atPath: cache.path))
    model.load(trackID: b.id, deck: .b)
    await model.playbackLoads?.value
    #expect(!barrier.isOpen && !barrier.timedOut)
    #expect(!model.preparingPlayback.contains(.b))
    #expect(model.playback.core.snapshot()?.b.phase == .ready)
    #expect(FileManager.default.fileExists(atPath: cache.path))
    #expect(try model.store.load(includeWaveforms: false).tracks.first { $0.id == a.id }?.grid == oldGrid)
    model.pressPlay(deck: .b)
    await model.flushTransportRequests()
    #expect(model.playback.core.snapshot()?.b.phase == .playing)
    var flushed = false
    let flushStarted = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
    let flush = Task {
        flushStarted.continuation.yield(())
        await model.flushWrites()
        flushed = true
    }
    var started = flushStarted.stream.makeAsyncIterator()
    _ = await started.next()
    #expect(!flushed && !barrier.isOpen)
    barrier.open()
    await flush.value
    #expect(flushed && !barrier.timedOut)
    let disk = try model.store.load(includeWaveforms: false)
    #expect(disk.tracks.first { $0.id == a.id }?.grid == edited)
    #expect(model.library == disk)
    #expect(disk.events.filter { $0.kind == .load && $0.toTrackID == b.id }.count == 1)
    await model.finishForShutdown()
}

@Test @MainActor func pendingManualGridSurvivesSameTrackReloadBothDecksAndABAWriteOrder() async throws {
    let (model, root, a, _) = try await readinessModel()
    defer { try? FileManager.default.removeItem(at: root) }
    let initialRevision = model.library.revision
    let barrier = PersistenceBarrier()
    let middle = PersistenceBarrier()
    let deadline = barrier.watchdog()
    let middleDeadline = middle.watchdog()
    defer {
        barrier.open()
        middle.open()
        deadline.cancel()
        middleDeadline.cancel()
    }
    model.preparationWrites = Task { await barrier.wait() }
    await barrier.waitUntilEntered()
    let first = try changedGrid(a, bpm: 121, anchor: 2205)
    let second = try changedGrid(a, bpm: 127, anchor: 4410)
    model.saveGrid(first, deck: .a)
    model.saveGrid(second, deck: .a)
    let firstTwo = model.preparationWrites
    model.preparationWrites = Task {
        await firstTwo?.value
        await middle.wait()
    }
    model.saveGrid(first, deck: .a)
    model.load(trackID: a.id, deck: .a)
    model.load(trackID: a.id, deck: .b)
    await model.playbackLoads?.value
    await model.flushTransportRequests()
    #expect(!barrier.isOpen && !barrier.timedOut)
    #expect(model.playback.core.snapshot()?.a.grid == first)
    #expect(model.playback.core.snapshot()?.b.grid == first)
    barrier.open()
    await middle.waitUntilEntered()
    // A and B have reached disk; final A is still blocked. Completing the first
    // identical A must not retire the latest A intent or its per-deck draft.
    #expect(try model.store.load(includeWaveforms: false).tracks.first { $0.id == a.id }?.grid == second)
    #expect(model.gridDraft[.a] == first && model.gridDraft[.b] == first)
    model.load(trackID: a.id, deck: .b)
    await model.playbackLoads?.value
    #expect(model.playback.core.snapshot()?.b.grid == first)
    #expect(!middle.isOpen && !middle.timedOut)
    middle.open()
    await model.flushWrites()
    let disk = try model.store.load(includeWaveforms: false)
    let saved = try #require(disk.tracks.first { $0.id == a.id })
    #expect(saved.preparation.gridIsManual && saved.grid == first)
    // Three accepted saves and three accepted loads each retain their own revision.
    #expect(disk.revision == initialRevision + 6)
    #expect(model.gridDraft[.a] == nil && model.gridDraft[.b] == nil)
    #expect(model.library == disk)
    await model.finishForShutdown()
}

@Test @MainActor func gridSaveMayFinishBeforeQueuedLoadWithoutRestoringStaleGrid() async throws {
    let (model, root, a, _) = try await readinessModel()
    defer { try? FileManager.default.removeItem(at: root) }
    let barrier = PersistenceBarrier()
    let deadline = barrier.watchdog()
    defer {
        barrier.open()
        deadline.cancel()
    }
    model.playbackLoads = Task { await barrier.wait() }
    await barrier.waitUntilEntered()
    model.load(trackID: a.id, deck: .a)
    let edited = try changedGrid(a, bpm: 137, anchor: 882)
    model.saveGrid(edited, deck: .a)
    // Persistence no longer waits for the queued source load either.
    await model.preparationWrites?.value
    #expect(!barrier.isOpen && !barrier.timedOut)
    #expect(model.preparingPlayback.contains(.a))
    #expect(model.gridDraft[.a] == nil)
    #expect(try model.store.load(includeWaveforms: false).tracks.first { $0.id == a.id }?.grid == edited)
    barrier.open()
    await model.flushWrites()
    await model.flushTransportRequests()
    #expect(!model.preparingPlayback.contains(.a))
    #expect(model.playback.core.snapshot()?.a.grid == edited)
    #expect(model.grid(.a) == edited)
    await model.finishForShutdown()
}

@Test @MainActor func loadTailKeepsLatestTokenAndFailureRollbackIndependentOfGridWrites() async throws {
    let (model, root, a, b) = try await readinessModel()
    defer { try? FileManager.default.removeItem(at: root) }
    let barrier = PersistenceBarrier()
    let deadline = barrier.watchdog()
    defer {
        barrier.open()
        deadline.cancel()
    }
    model.playbackLoads = Task { await barrier.wait() }
    await barrier.waitUntilEntered()
    model.load(trackID: a.id, deck: .a)
    model.load(trackID: b.id, deck: .a)
    model.load(trackID: a.id, deck: .b)
    barrier.open()
    await model.flushWrites()
    #expect(model.loaded[.a] == b.id && model.loaded[.b] == a.id)
    #expect(model.playback.core.snapshot()?.a.phase == .ready && model.playback.core.snapshot()?.b.phase == .ready)
    #expect(model.preparingPlayback.isEmpty)
    let before = model.playback.generations[.a]
    // A distinct metadata entry with missing private media forces source-preparation failure.
    var unavailable = try Track(
        title: a.title, artist: a.artist, mediaFilename: "missing-test-audio.wav", analysis: a.analysis)
    unavailable.preparation = a.preparation
    model.library.tracks[model.library.tracks.firstIndex { $0.id == a.id }!] = unavailable
    try? FileManager.default.removeItem(
        at: model.store.root.appendingPathComponent("PlaybackCache/\(a.id)-stereo-f32-v1.pcm"))
    model.load(trackID: a.id, deck: .a)
    await model.playbackLoads?.value
    #expect(model.loaded[.a] == b.id && model.playback.generations[.a] == before)
    #expect(model.preparingPlayback.isEmpty && !model.status.isEmpty)
    await model.finishForShutdown()
}

@Test @MainActor func failedGridWriteReportsErrorRetainsIntentAndAllowsLaterRecovery() async throws {
    let (model, root, a, _) = try await readinessModel()
    defer { try? FileManager.default.removeItem(at: root) }
    let original = try Data(contentsOf: model.store.libraryURL)
    try FileManager.default.removeItem(at: model.store.libraryURL)
    try FileManager.default.createDirectory(at: model.store.libraryURL, withIntermediateDirectories: false)
    let edited = try changedGrid(a, bpm: 131, anchor: 1102)
    model.saveGrid(edited, deck: .a)
    await model.flushWrites()
    #expect(!model.status.isEmpty && model.gridDraft[.a] == edited)
    // The unresolved manual intent still reaches a newly prepared deck after failure.
    model.load(trackID: a.id, deck: .b)
    await model.playbackLoads?.value
    await model.flushHistoryWrites()
    #expect(model.playback.core.snapshot()?.b.grid == edited && model.grid(.b) == edited)
    try FileManager.default.removeItem(at: model.store.libraryURL)
    try original.write(to: model.store.libraryURL, options: .atomic)
    let recovered = try changedGrid(a, bpm: 133, anchor: 1764)
    model.saveGrid(recovered, deck: .b)
    await model.flushWrites()
    #expect(try model.store.load(includeWaveforms: false).tracks.first { $0.id == a.id }?.grid == recovered)
    #expect(model.gridDraft[.b] == nil)
    await model.finishForShutdown()
}

@Test @MainActor func shutdownRetainsBlockedGridWritesAndNewLoadHistory() async throws {
    let (model, root, a, b) = try await readinessModel()
    defer { try? FileManager.default.removeItem(at: root) }
    let barrier = PersistenceBarrier()
    let deadline = barrier.watchdog()
    defer {
        barrier.open()
        deadline.cancel()
    }
    model.preparationWrites = Task { await barrier.wait() }
    await barrier.waitUntilEntered()
    let edited = try changedGrid(a, bpm: 129, anchor: 1323)
    model.saveGrid(edited, deck: .a)
    model.load(trackID: b.id, deck: .b)
    await model.playbackLoads?.value
    var finished = false
    let shutdownEntered = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
    let shutdown = Task {
        shutdownEntered.continuation.yield(())
        await model.finishForShutdown()
        finished = true
    }
    var started = shutdownEntered.stream.makeAsyncIterator()
    _ = await started.next()
    #expect(!finished && !barrier.isOpen)
    barrier.open()
    await shutdown.value
    #expect(finished && !barrier.timedOut && !model.playback.outputActive)
    let disk = try model.store.load(includeWaveforms: false)
    #expect(disk.tracks.first { $0.id == a.id }?.grid == edited)
    #expect(disk.events.contains { $0.kind == .load && $0.toTrackID == b.id })
    #expect(model.preparingPlayback.isEmpty && model.library == disk)
}
