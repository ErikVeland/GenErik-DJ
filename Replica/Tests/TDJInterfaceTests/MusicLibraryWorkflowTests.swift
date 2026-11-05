import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private final class FixtureMusicLibrary: LocalMusicLibraryProviding {
    var allowsCachedCatalog: Bool { error != .permissionDenied }
    var reads = 0
    var preparations: [String] = []
    var error: MusicLibraryError?
    var holdCatalog = false
    var catalogGate: CheckedContinuation<Void, Never>?
    let snapshot: MusicLibraryCatalog
    init(_ items: [MusicLibraryItem]) { snapshot = .init(items: items, playlists: []) }
    func catalog() async throws -> MusicLibraryCatalog {
        reads += 1
        if holdCatalog { await withCheckedContinuation { catalogGate = $0 } }
        if let error { throw error }
        return snapshot
    }
    func prepare(_ item: MusicLibraryItem, in directory: URL) async throws -> PreparedMusicLibraryAudio {
        preparations.append(item.id)
        return .init(url: try #require(item.assetURL), metadata: .init(item: item))
    }
}

@MainActor private func musicWorkflow() throws -> (ReplicaModel, FixtureMusicLibrary, URL) {
    var root = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 { root.deleteLastPathComponent() }
    let source = root.appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/clock-a-120.wav")
    let items: [MusicLibraryItem] = [
        .init(
            source: .init(platform: .iosMusic, persistentID: "bad"), title: "Missing file", artist: "",
            assetURL: source.deletingLastPathComponent().appendingPathComponent("missing.wav"), availability: .available
        ),
        .init(
            source: .init(platform: .iosMusic, persistentID: "local"), title: "Synced song",
            artist: "Library performer", genre: "House", assetURL: source, availability: .available),
        .init(
            source: .init(platform: .iosMusic, persistentID: "cloud"), title: "Not downloaded", artist: "",
            assetURL: nil, availability: .notDownloaded),
        .init(
            source: .init(platform: .iosMusic, persistentID: "protected"), title: "Protected song", artist: "",
            assetURL: source, availability: .protected),
    ]
    let provider = FixtureMusicLibrary(items)
    let workspace = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let model = try ReplicaModel(
        root: workspace, playback: PlaybackController(offline: true), musicLibraryProvider: provider)
    return (model, provider, workspace)
}

@Test @MainActor func musicLibraryAccessIsExplicitAndDeniedRefreshDoesNotExposeOldCatalog() async throws {
    let (model, provider, root) = try musicWorkflow()
    defer { try? FileManager.default.removeItem(at: root) }
    #expect(provider.reads == 0)
    await model.refreshMusicLibrary()
    #expect(provider.reads == 1)
    #expect(model.musicLibraryCatalog?.items.count == 4)
    provider.error = .permissionDenied
    await model.refreshMusicLibrary()
    #expect(model.musicLibraryCatalog == nil)
    #expect(model.musicLibraryError == MusicLibraryError.permissionDenied.localizedDescription)
    #expect(model.library.tracks.isEmpty)
}

@Test @MainActor func closingLibraryDuringRefreshRetainsOneOwnedRead() async throws {
    let (model, provider, root) = try musicWorkflow()
    defer { try? FileManager.default.removeItem(at: root) }
    provider.holdCatalog = true
    let first = Task { await model.refreshMusicLibrary() }
    while provider.catalogGate == nil { await Task.yield() }
    first.cancel()
    let reopened = Task { await model.refreshMusicLibrary() }
    await Task.yield()
    #expect(model.musicLibraryRefreshing)
    #expect(provider.reads == 1)
    provider.catalogGate?.resume()
    provider.catalogGate = nil
    await first.value
    await reopened.value
    #expect(provider.reads == 1)
    #expect(!model.musicLibraryRefreshing)
    #expect(model.musicLibraryCatalog?.items.count == 4)
    #expect(model.musicLibraryCatalogVersion == 1)
}

@Test @MainActor func relaunchShowsCachedSongsWhileMusicRefreshes() async throws {
    let (first, _, root) = try musicWorkflow()
    defer { try? FileManager.default.removeItem(at: root) }
    await first.refreshMusicLibrary()

    let refreshed = FixtureMusicLibrary([])
    refreshed.holdCatalog = true
    let reopened = try ReplicaModel(
        root: root, playback: PlaybackController(offline: true), musicLibraryProvider: refreshed)
    let refresh = Task { await reopened.refreshMusicLibrary() }
    while refreshed.catalogGate == nil { await Task.yield() }
    #expect(reopened.musicLibraryRefreshing)
    #expect(reopened.musicLibraryCatalog?.songs().contains { $0.title == "Synced song" } == true)
    refreshed.catalogGate?.resume()
    await refresh.value
    #expect(reopened.musicLibraryCatalog?.songs().isEmpty == true)
}

@Test @MainActor func relaunchDoesNotShowCachedSongsWithoutMusicPermission() async throws {
    let (first, _, root) = try musicWorkflow()
    defer { try? FileManager.default.removeItem(at: root) }
    await first.refreshMusicLibrary()

    let denied = FixtureMusicLibrary([])
    denied.error = .permissionDenied
    denied.holdCatalog = true
    let reopened = try ReplicaModel(
        root: root, playback: PlaybackController(offline: true), musicLibraryProvider: denied)
    let refresh = Task { await reopened.refreshMusicLibrary() }
    while denied.catalogGate == nil { await Task.yield() }
    #expect(reopened.musicLibraryCatalog == nil)
    denied.catalogGate?.resume()
    await refresh.value
    #expect(reopened.musicLibraryError == MusicLibraryError.permissionDenied.localizedDescription)
}

@Test @MainActor func musicLibraryBatchContinuesAfterFailureAndPreparedSongReachesDeck() async throws {
    let (model, provider, root) = try musicWorkflow()
    defer { try? FileManager.default.removeItem(at: root) }
    await model.refreshMusicLibrary()
    let catalog = try #require(model.musicLibraryCatalog)
    await model.importMusicLibraryItems(Set(catalog.items.map(\.id)))
    #expect(provider.preparations.count == 2)
    #expect(model.musicLibraryFailures.count == 3)
    #expect(!model.importing)
    #expect(model.library.tracks.count == 1)
    let item = catalog.items[1]
    let track = try #require(model.preparedTrack(for: item))
    #expect(track.title == "Synced song")
    #expect(track.artist == "Library performer")
    #expect(track.genre == "House")
    #expect(track.bpm != nil)
    #expect(model.library.events.isEmpty)
    await model.importMusicLibraryItems([item.id])
    #expect(provider.preparations.count == 2)
    #expect(model.library.tracks.count == 1)
    model.load(trackID: track.id, deck: .a)
    await model.flushWrites()
    model.pressPlay(deck: .a)
    await model.flushTransportRequests()
    let audio = model.playback.core.renderOffline(frames: 48000)
    #expect(audio.left.contains { $0 != 0 })
    #expect(model.playback.core.snapshot()?.a.phase == .playing)
    let restored = try model.store.load()
    #expect(restored.tracks[0].musicLibrarySources == [item.source])
    #expect(
        try FileManager.default.contentsOfDirectory(atPath: root.path).allSatisfy { !$0.hasPrefix(".music-import-") })
    model.stopAudio()
}

@MainActor private final class SuspendedMusicLibrary: LocalMusicLibraryProviding {
    let started = AsyncStream<Void>.makeStream()
    let release = AsyncStream<Void>.makeStream()
    let item: MusicLibraryItem
    init(url: URL) {
        item = .init(
            source: .init(platform: .iosMusic, persistentID: "waiting"), title: "Waiting song", artist: "",
            assetURL: url, availability: .available)
    }
    func catalog() async throws -> MusicLibraryCatalog { .init(items: [item], playlists: []) }
    func prepare(_ item: MusicLibraryItem, in directory: URL) async throws -> PreparedMusicLibraryAudio {
        started.continuation.yield(())
        for await _ in release.stream { break }
        try Task.checkCancellation()
        return .init(url: try #require(item.assetURL), metadata: .init(item: item))
    }
}

@Test @MainActor func backgroundMusicPreparationDoesNotHoldTransportControls() async throws {
    var base = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 { base.deleteLastPathComponent() }
    let source = base.appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/clock-a-120.wav")
    let provider = SuspendedMusicLibrary(url: source)
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let model = try ReplicaModel(
        root: root, playback: PlaybackController(offline: true), musicLibraryProvider: provider)
    await model.importFiles([source])
    let id = try #require(model.library.tracks.first?.id)
    model.load(trackID: id, deck: .a)
    await model.flushWrites()
    model.pressPlay(deck: .a)
    await model.flushTransportRequests()
    await model.refreshMusicLibrary()
    model.startMusicLibraryImport([provider.item.id])
    var iterator = provider.started.stream.makeAsyncIterator()
    _ = await iterator.next()
    #expect(model.importing && model.musicLibraryPreparing)
    model.showLibrary()
    model.pressPlay(deck: .a)
    await model.flushTransportRequests()
    #expect(model.playbackSnapshot?.a.phase == .paused)
    model.pressPlay(deck: .a)
    await model.flushTransportRequests()
    #expect(model.playbackSnapshot?.a.phase == .playing)
    model.cancelMusicLibraryImport()
    await model.flushMusicLibraryImport()
    #expect(!model.importing && !model.musicLibraryPreparing)
    #expect(model.loaded[.a] == id)
    #expect(model.playbackSnapshot?.a.phase == .playing)
    await model.finishForShutdown()
}

@Test @MainActor func ownedMusicBatchFinishesAndCoalescesRepeatedStarts() async throws {
    let (model, provider, root) = try musicWorkflow()
    defer { try? FileManager.default.removeItem(at: root) }
    await model.refreshMusicLibrary()
    let item = try #require(model.musicLibraryCatalog?.items.first { $0.source.persistentID == "local" })
    model.startMusicLibraryImport([item.id])
    model.startMusicLibraryImport([item.id])
    #expect(model.musicLibraryPreparing)
    await model.flushMusicLibraryImport()
    #expect(provider.preparations == [item.id])
    #expect(model.preparedTrack(for: item) != nil)
    #expect(!model.importing && !model.musicLibraryPreparing)
    model.startMusicLibraryImport([item.id])
    await model.flushMusicLibraryImport()
    #expect(provider.preparations == [item.id])
}

@Test @MainActor func shutdownCancelsOwnedMusicPreparation() async throws {
    let provider = SuspendedMusicLibrary(url: URL(fileURLWithPath: "/unused.wav"))
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let model = try ReplicaModel(
        root: root, playback: PlaybackController(offline: true), musicLibraryProvider: provider)
    await model.refreshMusicLibrary()
    model.startMusicLibraryImport([provider.item.id])
    var iterator = provider.started.stream.makeAsyncIterator()
    _ = await iterator.next()
    await model.finishForShutdown()
    #expect(!model.importing && !model.musicLibraryPreparing)
    #expect(model.library.tracks.isEmpty)
}

@Test @MainActor func automaticNativeLibraryAnalysisKeepsOriginalAudioInPlace() async throws {
    let (model, provider, root) = try musicWorkflow()
    defer { try? FileManager.default.removeItem(at: root) }
    await model.openNativeMusicLibrary()
    await model.flushNativeMusicAnalysis()
    #expect(model.musicLibraryCatalog?.items.count == 4)
    #expect(provider.preparations.count == 2)
    let track = try #require(model.preparedTrack(for: provider.snapshot.items[1]))
    #expect(track.nativeLibraryOnly == true)
    #expect(
        !FileManager.default.fileExists(
            atPath: model.store.mediaDirectory.appendingPathComponent(track.mediaFilename).path))
    #expect(model.musicLibraryFailures[provider.snapshot.items[0].id] != nil)
    await model.finishForShutdown()
}

@Test @MainActor func nativeAnalysedSongLoadsFromTheMusicFileWithoutAnImportedCopy() async throws {
    let (model, provider, root) = try musicWorkflow()
    defer { try? FileManager.default.removeItem(at: root) }
    await model.openNativeMusicLibrary()
    await model.flushNativeMusicAnalysis()
    let item = provider.snapshot.items[1]
    let track = try #require(model.preparedTrack(for: item))
    model.loadNativeMusic(item, deck: .a)
    await model.flushWrites()
    model.pressPlay(deck: .a)
    await model.flushTransportRequests()
    let audio = model.playback.core.renderOffline(frames: 48000)
    #expect(audio.left.contains { $0 != 0 })
    #expect(model.playback.core.snapshot()?.a.phase == .playing)
    #expect(
        !FileManager.default.fileExists(
            atPath: model.store.mediaDirectory.appendingPathComponent(track.mediaFilename).path))
    await model.finishForShutdown()
}

@Test @MainActor func loadingAnUnanalysedSongPrioritisesItOverTheBackgroundQueue() async throws {
    let (model, provider, root) = try musicWorkflow()
    defer { try? FileManager.default.removeItem(at: root) }
    await model.openNativeMusicLibrary()
    let item = provider.snapshot.items[1]
    model.loadNativeMusic(item, deck: .a)
    await model.flushWrites()
    #expect(model.preparedTrack(for: item) != nil)
    model.pressPlay(deck: .a)
    await model.flushTransportRequests()
    #expect(model.playback.core.renderOffline(frames: 48000).left.contains { $0 != 0 })
    await model.finishForShutdown()
}
