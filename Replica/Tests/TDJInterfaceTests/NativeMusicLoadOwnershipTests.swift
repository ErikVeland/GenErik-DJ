import Foundation
import Testing
import TDJCore
@testable import TDJInterface

@MainActor private final class HeldNativeLoadLibrary: LocalMusicLibraryProviding {
    let item: MusicLibraryItem
    var held = false
    var temporary = false
    var preparedURLs: [URL] = []
    var started = AsyncStream<Void>.makeStream()
    var release: CheckedContinuation<Void, Never>?
    init(url: URL) {
        item = .init(source: .init(platform: .iosMusic, persistentID: "owned-native"),
                     title: "Native selection", artist: "Selected artist", assetURL: url, availability: .available)
    }
    func catalog() async throws -> MusicLibraryCatalog { .init(items: [item], playlists: []) }
    func prepare(_ item: MusicLibraryItem, in directory: URL) async throws -> PreparedMusicLibraryAudio {
        if held {
            started.continuation.yield(())
            await withCheckedContinuation { release = $0 }
        }
        let source = try #require(item.assetURL)
        if temporary {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent(source.lastPathComponent)
            try FileManager.default.copyItem(at: source, to: url)
            preparedURLs.append(url)
            return .init(url: url, metadata: .init(item: item), temporary: true)
        }
        return .init(url: source, metadata: .init(item: item))
    }
}

@MainActor private func nativeOwnershipFixture() async throws -> (ReplicaModel, HeldNativeLoadLibrary, URL, String) {
    var base = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 { base.deleteLastPathComponent() }
    let fixtures = base.appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures")
    let provider = HeldNativeLoadLibrary(url: fixtures.appendingPathComponent("clock-a-120.wav"))
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true), musicLibraryProvider: provider)
    await model.openNativeMusicLibrary()
    await model.flushNativeMusicAnalysis()
    model.nativeMusic.wanted = false
    await model.importFiles([fixtures.appendingPathComponent("clock-b-120.wav")])
    let managed = try #require(model.library.tracks.first { $0.nativeLibraryOnly != true }?.id)
    provider.held = true
    return (model, provider, root, managed)
}

@Test @MainActor func managedSelectionSupersedesHeldNativeLoad() async throws {
    let (model, provider, root, managed) = try await nativeOwnershipFixture()
    defer { try? FileManager.default.removeItem(at: root) }
    model.loadNativeMusic(provider.item, deck: .a)
    var started = provider.started.stream.makeAsyncIterator()
    _ = await started.next()
    model.load(trackID: managed, deck: .a)
    provider.release?.resume(); provider.release = nil
    await model.flushWrites()
    #expect(model.loaded[.a] == managed)
    #expect(model.playback.core.snapshot()?.a.phase == .ready)
    await model.finishForShutdown()
}

@Test @MainActor func nativeLoadHandsOffToTheDeckBeforePreparationFinishes() async throws {
    let (model, provider, root, _) = try await nativeOwnershipFixture()
    defer { try? FileManager.default.removeItem(at: root) }
    model.browserVisible = true
    model.selectedTrackID = "selected"
    model.loadNativeMusic(provider.item, deck: .a)
    #expect(!model.browserVisible)
    #expect(model.selectedTrackID == nil)
    #expect(model.preparingPlayback.contains(.a))
    var started = provider.started.stream.makeAsyncIterator()
    _ = await started.next()
    #expect(model.preparingPlayback.contains(.a))
    provider.release?.resume(); provider.release = nil
    await model.flushWrites()
    #expect(!model.preparingPlayback.contains(.a))
    #expect(model.playback.core.snapshot()?.a.phase == .ready)
    await model.finishForShutdown()
}

@Test @MainActor func stopPreventsHeldNativePreparationFromLoadingLater() async throws {
    let (model, provider, root, _) = try await nativeOwnershipFixture()
    defer { try? FileManager.default.removeItem(at: root) }
    model.loadNativeMusic(provider.item, deck: .a)
    var started = provider.started.stream.makeAsyncIterator()
    _ = await started.next()
    model.stopAudio()
    #expect(!model.preparingPlayback.contains(.a))
    provider.release?.resume(); provider.release = nil
    await model.flushWrites()
    #expect(model.loaded[.a] == nil)
    #expect(model.playback.core.snapshot()?.a.phase == .empty)
    #expect(model.nativeMusic.loads.isEmpty)
    await model.finishForShutdown()
}

@MainActor private final class BlockedAnalysisLibrary: LocalMusicLibraryProviding {
    let items: [MusicLibraryItem]
    let started = AsyncStream<Void>.makeStream()
    var releases: [CheckedContinuation<Void, Never>] = []
    var backgroundPreparations = 0
    var releasedByWatchdog = false
    init(url: URL) {
        items = ["background", "performer"].map {
            .init(source: .init(platform: .iosMusic, persistentID: $0),
                  title: $0, artist: "Alias artist", assetURL: url, availability: .available)
        }
    }
    func catalog() async throws -> MusicLibraryCatalog { .init(items: items, playlists: []) }
    func prepare(_ item: MusicLibraryItem, in directory: URL) async throws -> PreparedMusicLibraryAudio {
        if item.id == items[0].id {
            backgroundPreparations += 1
            started.continuation.yield(())
            await withCheckedContinuation { releases.append($0) }
        }
        return .init(url: try #require(item.assetURL), metadata: .init(item: item))
    }
    func open(watchdog: Bool = false) {
        releasedByWatchdog = releasedByWatchdog || watchdog
        let waiting = releases; releases.removeAll()
        for gate in waiting { gate.resume() }
    }
}

@Test @MainActor func performerLoadDoesNotJoinAnUncooperativeBackgroundPreparation() async throws {
    var base = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 { base.deleteLastPathComponent() }
    let fixtures = base.appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures")
    let provider = BlockedAnalysisLibrary(url: fixtures.appendingPathComponent("clock-a-120.wav"))
    let roots = (0..<2).map { _ in FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString) }
    defer { for root in roots { try? FileManager.default.removeItem(at: root) } }
    let model = try ReplicaModel(root: roots[0], playback: PlaybackController(offline: true), musicLibraryProvider: provider)
    let control = try ReplicaModel(root: roots[1], playback: PlaybackController(offline: true))
    for player in [model, control] {
        await player.importFiles([fixtures.appendingPathComponent("clock-b-128.wav")])
        player.load(trackID: try #require(player.library.tracks.first?.id), deck: .a)
        await player.flushWrites()
        player.pressPlay(deck: .a); await player.flushTransportRequests()
    }
    await model.openNativeMusicLibrary()
    var started = provider.started.stream.makeAsyncIterator()
    _ = await started.next()
    let watchdog = Task { @MainActor in
        do { try await Task.sleep(for: .seconds(3)); provider.open(watchdog: true) } catch { }
    }
    defer { watchdog.cancel(); provider.open() }
    model.loadNativeMusic(provider.items[1], deck: .b)
    await model.flushWrites()
    #expect(!provider.releasedByWatchdog)
    for _ in 0..<20 { await Task.yield() }
    #expect(provider.backgroundPreparations == 1)
    let track = try #require(model.preparedTrack(for: provider.items[1]))
    #expect(model.loaded[.b] == track.id)
    let actual = model.playback.core.renderOffline(frames: 4096)
    let expected = control.playback.core.renderOffline(frames: 4096)
    #expect(actual.left == expected.left)
    #expect(actual.right == expected.right)
    model.nativeMusic.wanted = false
    provider.open(); watchdog.cancel()
    await model.finishForShutdown(); await control.finishForShutdown()
}

@Test @MainActor func nativeTemporarySourceLivesThroughLoadAndIsRemovedAfterwards() async throws {
    let (model, provider, root, _) = try await nativeOwnershipFixture()
    defer { try? FileManager.default.removeItem(at: root) }
    provider.held = false; provider.temporary = true
    model.loadNativeMusic(provider.item, deck: .b)
    await model.flushWrites()
    #expect(model.playback.core.snapshot()?.b.phase == .ready)
    #expect(provider.preparedURLs.count == 1)
    #expect(provider.preparedURLs.allSatisfy { !FileManager.default.fileExists(atPath: $0.path) })
    #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).allSatisfy { !$0.hasPrefix(".native-source-") })
    model.pressPlay(deck: .b); await model.flushTransportRequests()
    #expect(model.playback.core.renderOffline(frames: 1024).left.contains { $0 != 0 })
    await model.finishForShutdown()
}

@Test(arguments: [true, false]) @MainActor
func nativeSourceLookupIsOwnedBeforeItsBackgroundResultReturns(stop: Bool) async throws {
    let (model, provider, root, managed) = try await nativeOwnershipFixture()
    defer { try? FileManager.default.removeItem(at: root) }
    let native = try #require(model.preparedTrack(for: provider.item))
    let entered = AsyncStream<Void>.makeStream(), gate = DispatchSemaphore(value: 0)
    let held = Task { await model.nativeMusic.projection.run { entered.continuation.yield(()); gate.wait() } }
    for await _ in entered.stream { break }
    model.load(trackID: native.id, deck: .a)
    #expect(model.nativeMusic.loads.count == 1)
    if stop { model.stopAudio() } else { model.load(trackID: managed, deck: .a) }
    gate.signal(); await held.value
    await model.flushWrites()
    #expect(model.loaded[.a] == (stop ? nil : managed))
    #expect(model.nativeMusic.loads.isEmpty)
    await model.finishForShutdown()
}

@Test @MainActor func managedNativeAliasUsesSelectedRecordingTitleWithoutPreparingTheSource() async throws {
    let (model, provider, root, managed) = try await nativeOwnershipFixture()
    defer { try? FileManager.default.removeItem(at: root) }
    let track = try #require(model.library.tracks.first { $0.id == managed })
    let alias = MusicLibraryItem(source: .init(platform: .iosMusic, persistentID: "selected-alias"),
        title: "Chosen playlist title", artist: "Chosen playlist artist", assetURL: nil, availability: .notDownloaded)
    let entry = LibraryBrowserEntry(nativeItem: alias, track: track)
    #expect(entry.canLoad)
    await model.toggleRecording()
    model.loadLibraryEntry(entry, deck: .a)
    await model.flushWrites()
    model.pressPlay(deck: .a); await model.flushTransportRequests()
    _ = model.playback.core.renderOffline(frames: 4096)
    await model.toggleRecording()
    let recording = try #require(model.recordings.first)
    let text = try String(contentsOf: recording.deletingPathExtension().appendingPathExtension("txt"), encoding: .utf8)
    #expect(text.contains("Chosen playlist artist"))
    #expect(text.contains("Chosen playlist title"))
    #expect(provider.release == nil)
    #expect(provider.preparedURLs.isEmpty)
    await model.finishForShutdown()
}

@Test @MainActor func repeatedRecordingsRetainTheAcceptedNativeAliasWithoutReloading() async throws {
    let (model, provider, root, managed) = try await nativeOwnershipFixture()
    defer { try? FileManager.default.removeItem(at: root) }
    let track = try #require(model.library.tracks.first { $0.id == managed })
    let alias = MusicLibraryItem(source: .init(platform: .iosMusic, persistentID: "repeat-recording-alias"),
        title: "Selected title for both recordings", artist: "Selected recording artist", assetURL: nil, availability: .notDownloaded)
    model.loadLibraryEntry(.init(nativeItem: alias, track: track), deck: .a)
    await model.flushWrites()
    model.pressPlay(deck: .a); await model.flushTransportRequests()
    for _ in 0..<2 {
        let previous = Set(model.recordings)
        await model.toggleRecording()
        _ = model.playback.core.renderOffline(frames: 48000)
        await model.toggleRecording()
        let recording = try #require(model.recordings.first { !previous.contains($0) })
        let text = try String(contentsOf: recording.deletingPathExtension().appendingPathExtension("txt"), encoding: .utf8)
        #expect(text.contains("Selected title for both recordings"))
        #expect(text.contains("Selected recording artist"))
        #expect(!text.contains(track.title))
    }
    #expect(provider.release == nil)
    await model.finishForShutdown()
}
