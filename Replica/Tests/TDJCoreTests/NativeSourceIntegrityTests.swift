import AVFoundation
import Foundation
import Testing
@testable import TDJCore

private func nativeIntegrityAudio(_ url: URL, sample: Float, frames: AVAudioFrameCount = 512) throws {
    let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2))
    let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames))
    buffer.frameLength = frames
    for channel in 0..<2 { buffer.floatChannelData![channel].initialize(repeating: sample, count: Int(frames)) }
    var settings = format.settings
    settings[AVLinearPCMIsNonInterleaved] = false
    var file: AVAudioFile? = try AVAudioFile(forWriting: url, settings: settings)
    try file!.write(from: buffer)
    file = nil
}

@Test(arguments: [false, true])
func nativeSourceMustMatchAnalysisBeforeCreatingOrReusingPCMCache(cached: Bool) throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try WorkspaceStore(root: root)
    let a = root.appendingPathComponent("source-a.caf")
    let b = root.appendingPathComponent("source-b.caf")
    try nativeIntegrityAudio(a, sample: 0.1)
    try nativeIntegrityAudio(b, sample: 0.3)
    let analysis = try AudioAnalyzer.waveformOnly(url: a)
    let track = try Track(title: "Source A", mediaFilename: "not-copied.caf", analysis: analysis)
    #expect(try AudioAnalyzer.sha256(url: b) != track.id)
    if cached { _ = try PCMCache.prepare(track: track, store: store, sourceURL: a) }
    #expect(throws: TransportError.self) {
        _ = try PCMCache.prepare(track: track, store: store, sourceURL: b)
    }
}

@Test func filesImportPromotesAnExistingNativeReferenceToManagedMedia() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try WorkspaceStore(root: root)
    let service = try LibraryService(store: store)
    let source = root.appendingPathComponent("original.caf")
    try nativeIntegrityAudio(source, sample: 0.1)
    let item = MusicLibraryItem(source: .init(platform: .macMusic, persistentID: "promotion"),
        title: "Original", artist: "Artist", assetURL: source, availability: .available)
    let native = try await service.analyzeNativeMusic(url: source, musicLibrary: .init(item: item), quickLoad: true)
    #expect(native.tracks.first?.nativeLibraryOnly == true)
    let imported = try await service.importAudio(url: source)
    let track = try #require(imported.tracks.first)
    #expect(imported.tracks.count == 1)
    #expect(track.nativeLibraryOnly != true)
    #expect(track.musicLibrarySources == [item.source])
    let managed = store.mediaDirectory.appendingPathComponent(track.mediaFilename)
    #expect(FileManager.default.fileExists(atPath: managed.path))
    #expect(try AudioAnalyzer.sha256(url: source) == track.id)
    #expect(try store.load().tracks.first?.nativeLibraryOnly != true)
}

private final class NativeMutationOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var changed = false
    func claim() -> Bool { lock.withLock { if changed { return false }; changed = true; return true } }
    var didChange: Bool { lock.withLock { changed } }
}

@Test func nativeSourceChangeDuringConversionCannotPublishTheOldIdentityCache() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try WorkspaceStore(root: root)
    let source = root.appendingPathComponent("mutable.caf")
    let replacementURL = root.appendingPathComponent("replacement.caf")
    try nativeIntegrityAudio(source, sample: 0.1, frames: 65536)
    try nativeIntegrityAudio(replacementURL, sample: 0.3, frames: 65536)
    let replacement = try Data(contentsOf: replacementURL)
    let analysis = try AudioAnalyzer.waveformOnly(url: source)
    let track = try Track(title: "Before mutation", mediaFilename: "not-copied.caf", analysis: analysis)
    let cacheDirectory = root.appendingPathComponent("PlaybackCache")
    let mutation = NativeMutationOnce()
    #expect(throws: TransportError.self) {
        _ = try PCMCache.prepare(track: track, store: store, sourceURL: source, checkCancellation: {
            let partials = (try? FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey])) ?? []
            if partials.contains(where: { $0.pathExtension == "partial" && ((try? $0.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) > 0 }), mutation.claim() {
                try replacement.write(to: source)
            }
        })
    }
    #expect(mutation.didChange)
    #expect(!FileManager.default.fileExists(atPath: cacheDirectory.appendingPathComponent(track.id + "-stereo-f32-v1.pcm").path))
}

private final class NativeAnalysisHold: @unchecked Sendable {
    private let entered = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
    private let release = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var opened = false
    private var expired = false
    func hold() { entered.continuation.yield(()); release.wait() }
    func waitUntilEntered() async { for await _ in entered.stream { return } }
    func open(expired: Bool = false) {
        let signal = lock.withLock { self.expired = self.expired || expired; if opened { return false }; opened = true; return true }
        if signal { release.signal() }
    }
    var timedOut: Bool { lock.withLock { expired } }
}

@Test func nativeQuickPreparationDoesNotJoinHeldFullAnalysis() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let source = root.appendingPathComponent("quick.caf")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try nativeIntegrityAudio(source, sample: 0.1)
    let service = try LibraryService(store: WorkspaceStore(root: root))
    let item = MusicLibraryItem(source: .init(platform: .macMusic, persistentID: "quick"),
        title: "Quick", artist: "Artist", assetURL: source, availability: .available)
    let held = NativeAnalysisHold()
    let full = Task { try await AnalysisWorker.shared.run { _ in held.hold(); return true } }
    await held.waitUntilEntered()
    // The watchdog releases the held worker. It is not an audio deadline.
    let watchdog = Task.detached {
        do { try await Task.sleep(for: .seconds(2)) } catch { return }
        held.open(expired: true)
    }
    defer { held.open(); watchdog.cancel() }
    let snapshot = try await service.analyzeNativeMusic(url: source, musicLibrary: .init(item: item), quickLoad: true)
    #expect(!held.timedOut)
    #expect(snapshot.tracks.first?.analysis.musicalAnalysisDeferred == true)
    held.open()
    _ = try await full.value
}

@Test func repeatedNativeDecodesKeepTheSameContentIdentity() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let source = root.appendingPathComponent("source.caf")
    try nativeIntegrityAudio(source, sample: 0.125, frames: 65536)
    let a = root.appendingPathComponent("first.caf"), b = root.appendingPathComponent("second.caf")
    try await MusicLibraryAudio.decodeAsset(url: source, destination: a)
    try await MusicLibraryAudio.decodeAsset(url: source, destination: b)
    #expect(try AudioAnalyzer.sha256(url: a) == AudioAnalyzer.sha256(url: b))
}
