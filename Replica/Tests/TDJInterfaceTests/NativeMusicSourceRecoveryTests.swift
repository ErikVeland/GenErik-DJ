import Foundation
import Observation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private final class ReplacedNativeLibrary: LocalMusicLibraryProviding {
    let original: URL
    var current: URL
    var temporary = false
    var temporaryURLs: [URL] = []
    var prepareCheckpoint: (() async -> Void)?
    let primary: MusicLibraryItem
    let alias: MusicLibraryItem
    init(url: URL) {
        original = url
        current = url
        primary = .init(
            source: .init(platform: .iosMusic, persistentID: "replacement-primary"), title: "Mutable Music song",
            artist: "Library artist", assetURL: url, availability: .available)
        alias = .init(
            source: .init(platform: .iosMusic, persistentID: "unchanged-alias"), title: "Unchanged Music alias",
            artist: "Alias artist", assetURL: url, availability: .available)
    }
    func catalog() async throws -> MusicLibraryCatalog { .init(items: [primary, alias], playlists: []) }
    func prepare(_ item: MusicLibraryItem, in directory: URL) async throws -> PreparedMusicLibraryAudio {
        await prepareCheckpoint?()
        let source = item.id == primary.id ? current : original
        if temporary {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent(source.lastPathComponent)
            try FileManager.default.copyItem(at: source, to: url)
            temporaryURLs.append(url)
            return .init(url: url, metadata: .init(item: item), temporary: true)
        }
        return .init(url: source, metadata: .init(item: item))
    }
}

@Test @MainActor func replacedNativeAudioRebindsItsSourceWithoutChangingTheOtherPlayingDeck() async throws {
    var base = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 { base.deleteLastPathComponent() }
    let fixtures = base.appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures")
    let provider = ReplacedNativeLibrary(url: fixtures.appendingPathComponent("clock-a-120.wav"))
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let model = try ReplicaModel(
        root: root, playback: PlaybackController(offline: true), musicLibraryProvider: provider)
    await model.openNativeMusicLibrary()
    await model.flushNativeMusicAnalysis()
    model.nativeMusic.wanted = false
    let original = try #require(model.preparedTrack(for: provider.primary))
    var manual = original.preparation
    manual.grid = try BeatGrid(bpm: 123, anchorFrame: 256, sampleRate: original.analysis.sampleRate)
    manual.gridIsManual = true
    model.adoptLibrary(try await model.service.updatePreparation(trackID: original.id, preparation: manual))
    model.loadNativeMusic(provider.primary, deck: .a)
    await model.flushWrites()
    model.pressPlay(deck: .a)
    await model.flushTransportRequests()
    let pinned = try #require(model.track(.a))
    let reference = try PlaybackController(offline: true)
    try await reference.load(track: pinned, store: model.store, deck: .a, sourceURL: provider.original)
    try reference.play(.a)
    let generation = try #require(model.playback.core.snapshot()?.a.generation)
    provider.current = fixtures.appendingPathComponent("clock-b-128.wav")
    let replacementID = try AudioAnalyzer.sha256(url: provider.current)
    #expect(replacementID != original.id)
    model.loadNativeMusic(provider.primary, deck: .b)
    await model.flushWrites()
    #expect(model.loaded[.b] == replacementID)
    #expect(model.preparedTrack(for: provider.primary)?.id == replacementID)
    #expect(model.preparedTrack(for: provider.alias)?.id == original.id)
    #expect(model.loaded[.a] == original.id)
    #expect(model.track(.a)?.preparation == manual)
    #expect(model.playback.core.snapshot()?.a.generation == generation)
    #expect(model.playback.core.snapshot()?.a.phase == .playing)
    let actual = model.playback.core.renderOffline(frames: 48000)
    let expected = reference.core.renderOffline(frames: 48000)
    #expect(actual.left == expected.left && actual.right == expected.right)
    let restored = try model.store.load()
    #expect(restored.tracks.first { $0.id == original.id }?.preparation == manual)
    #expect(restored.tracks.first { $0.id == replacementID }?.musicLibrarySources == [provider.primary.source])
    #expect(
        try FileManager.default.contentsOfDirectory(atPath: model.store.mediaDirectory.path).allSatisfy {
            !$0.hasSuffix(".wav")
        })
    reference.stopAudio()
    await model.finishForShutdown()
}

@MainActor private final class RecoveryDecodedGate {
    let entered = AsyncStream<Void>.makeStream()
    var release: CheckedContinuation<Void, Never>?
    func hold() async {
        entered.continuation.yield(())
        await withCheckedContinuation { release = $0 }
    }
    func open() {
        release?.resume()
        release = nil
    }
}

@Test @MainActor func stoppedNativeRecoveryCannotSubmitAudioOrReplaceNewerStatus() async throws {
    var base = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 { base.deleteLastPathComponent() }
    let fixtures = base.appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures")
    let provider = ReplacedNativeLibrary(url: fixtures.appendingPathComponent("clock-a-120.wav"))
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let model = try ReplicaModel(
        root: root, playback: PlaybackController(offline: true), musicLibraryProvider: provider)
    await model.openNativeMusicLibrary()
    await model.flushNativeMusicAnalysis()
    model.nativeMusic.wanted = false
    provider.current = fixtures.appendingPathComponent("clock-b-128.wav")
    provider.temporary = true
    let gate = RecoveryDecodedGate()
    model.playback.loadCheckpoint = { checkpoint in if case .decoded = checkpoint { await gate.hold() } }
    model.loadNativeMusic(provider.primary, deck: .b)
    for await _ in gate.entered.stream { break }
    model.stopAudio()
    model.status = "Stopped by performer"
    gate.open()
    await model.flushWrites()
    model.playback.loadCheckpoint = nil
    #expect(model.loaded[.b] == nil)
    #expect(model.playback.core.snapshot()?.b.phase == .empty)
    #expect(model.status == "Stopped by performer")
    #expect(provider.temporaryURLs.count == 1)
    #expect(provider.temporaryURLs.allSatisfy { !FileManager.default.fileExists(atPath: $0.path) })
    #expect(
        try FileManager.default.contentsOfDirectory(atPath: root.path).allSatisfy { !$0.hasPrefix(".native-source-") })
    await model.finishForShutdown()
}

@MainActor private final class NativeProtectedStatusGate {
    let entered = AsyncStream<Void>.makeStream()
    let model: ReplicaModel
    var finished = false
    var timedOut = false
    init(_ model: ReplicaModel) { self.model = model }
    func observe() {
        guard !finished else { return }
        withObservationTracking {
            _ = model.status
        } onChange: { [weak self] in
            Task { @MainActor in self?.changed() }
        }
    }
    private func changed() {
        if model.status == TransportError.protectedDeck.localizedDescription { open() } else { observe() }
    }
    func open(timeout: Bool = false) {
        guard !finished else { return }
        timedOut = timeout
        finished = true
        entered.continuation.yield(())
    }
}

@Test @MainActor func protectedNativeAttemptCannotAcquireOrCancelTheOtherDeckLoad() async throws {
    var base = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 { base.deleteLastPathComponent() }
    let fixtures = base.appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures")
    let provider = ReplacedNativeLibrary(url: fixtures.appendingPathComponent("clock-a-120.wav"))
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let model = try ReplicaModel(
        root: root, playback: PlaybackController(offline: true), musicLibraryProvider: provider)
    await model.openNativeMusicLibrary()
    await model.flushNativeMusicAnalysis()
    model.nativeMusic.wanted = false
    model.loadNativeMusic(provider.primary, deck: .a)
    await model.flushWrites()
    await model.importFiles([fixtures.appendingPathComponent("clock-b-120.wav")])
    let managed = try #require(model.library.tracks.first { $0.nativeLibraryOnly != true }?.id)
    let preparation = RecoveryDecodedGate()
    let decoded = RecoveryDecodedGate()
    provider.prepareCheckpoint = { await preparation.hold() }
    model.loadNativeMusic(provider.primary, deck: .a)
    let owner = try #require(model.nativeMusic.loadOwners[.a])
    for await _ in preparation.entered.stream { break }
    model.playback.loadCheckpoint = { checkpoint in if case .decoded = checkpoint { await decoded.hold() } }
    model.load(trackID: managed, deck: .b)
    for await _ in decoded.entered.stream { break }
    model.pressPlay(deck: .a)
    await model.flushTransportRequests()
    #expect(model.playback.core.snapshot()?.a.phase == .playing)
    let status = NativeProtectedStatusGate(model)
    status.observe()
    let watchdog = Task { @MainActor in
        do {
            try await Task.sleep(for: .seconds(3))
            status.open(timeout: true)
        } catch {}
    }
    defer {
        watchdog.cancel()
        preparation.open()
        decoded.open()
    }
    preparation.open()
    for await _ in status.entered.stream { break }
    #expect(!status.timedOut)
    #expect(model.nativeMusic.rootLoads[owner] == nil)
    model.cancelNativeMusicLoad(deck: .a)
    decoded.open()
    await model.flushWrites()
    model.playback.loadCheckpoint = nil
    provider.prepareCheckpoint = nil
    #expect(model.loaded[.b] == managed)
    #expect(model.playback.core.snapshot()?.b.phase == .ready)
    #expect(model.playback.core.snapshot()?.a.phase == .playing)
    await model.finishForShutdown()
}
