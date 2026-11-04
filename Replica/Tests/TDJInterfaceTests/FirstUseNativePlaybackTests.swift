import Foundation
import Testing
import TDJCore
@testable import TDJInterface

@MainActor private final class DirectNativeLibrary: LocalMusicLibraryProviding {
    let item: MusicLibraryItem
    var exports = 0
    var directOpens = 0
    init(url: URL) {
        item = .init(source: .init(platform: .iosMusic, persistentID: "direct-first-use"),
            title: "Direct first use", artist: "Fixture", assetURL: url, availability: .available)
    }
    func catalog() async throws -> MusicLibraryCatalog { .init(items: [item], playlists: []) }
    func playbackSource(_ item: MusicLibraryItem) async throws -> PreparedMusicLibraryAudio? {
        directOpens += 1
        return .init(url: try #require(item.assetURL), metadata: .init(item: item))
    }
    func prepare(_ item: MusicLibraryItem, in directory: URL) async throws -> PreparedMusicLibraryAudio {
        exports += 1
        return .init(url: try #require(item.assetURL), metadata: .init(item: item))
    }
}

@MainActor private func directNativeModel() async throws -> (ReplicaModel, DirectNativeLibrary, URL) {
    var base = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 { base.deleteLastPathComponent() }
    let provider = DirectNativeLibrary(url: base.appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/clock-a-120.wav"))
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true), musicLibraryProvider: provider)
    await model.refreshMusicLibrary()
    return (model, provider, root)
}

@Test @MainActor func firstNativeLoadShowsRealWaveformAndAcceptsPlayBeforeExportOrFullPCM() async throws {
    let (model, provider, root) = try await directNativeModel()
    defer { try? FileManager.default.removeItem(at: root) }
    let reached = AsyncStream<Void>.makeStream()
    let released = AsyncStream<Void>.makeStream()
    model.playback.loadCheckpoint = { checkpoint in
        if case .decoded = checkpoint {
            reached.continuation.yield(())
            for await _ in released.stream {}
        }
    }
    model.loadNativeMusic(provider.item, deck: .a)
    model.pressPlay(deck: .a)
    for await _ in reached.stream { break }
    let initial = try #require(model.track(.a))
    #expect(provider.directOpens == 1 && provider.exports == 0)
    #expect(initial.analysis.musicalAnalysisDeferred == true)
    #expect(initial.analysis.waveform.count == 50)
    #expect(initial.analysis.waveformDecodedFrames == 22050)
    #expect(model.playWhenReady.contains(.a))
    #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("PlaybackCache/\(initial.id)-stereo-f32-v1.pcm").path))
    released.continuation.finish()
    await model.flushWrites()
    #expect(model.playback.core.snapshot()?.a.phase == .playing)
    #expect(provider.exports == 0)
    let generation = model.playback.generations[.a]
    let cue = PerformanceCue(frame: 88200)
    model.performance.cues[initial.id] = [2: cue]
    model.savePerformance()
    let manual = try BeatGrid(bpm: 123, anchorFrame: 441, sampleRate: initial.analysis.sampleRate)
    model.saveGrid(manual, deck: .a)
    await model.flushNativeWaveforms()
    #expect(model.track(.a)?.analysis.waveformDecodedFrames == nil)
    #expect(model.track(.a)?.analysis.waveform.count ?? 0 > 50)
    #expect(model.playback.generations[.a] == generation)
    model.pressPlay(deck: .a, vinylStop: false)
    await model.flushWrites()
    await model.flushDeckAnalysis()
    #expect(provider.exports == 1)
    #expect(model.track(.a)?.id == initial.id)
    #expect(model.track(.a)?.analysis.musicalAnalysisDeferred != true)
    #expect(model.performance.cues[initial.id]?[2] == cue)
    #expect(model.track(.a)?.grid == manual)
    #expect(model.playback.generations[.a] == generation)
    await model.finishForShutdown()
}

@Test @MainActor func directNativeReplacementCannotConsumeEarlierQueuedPlay() async throws {
    let (model, provider, root) = try await directNativeModel()
    defer { try? FileManager.default.removeItem(at: root) }
    model.loadNativeMusic(provider.item, deck: .b)
    model.pressPlay(deck: .b)
    model.loadNativeMusic(provider.item, deck: .b)
    #expect(model.playWhenReady.isEmpty)
    await model.flushWrites()
    #expect(model.playback.core.snapshot()?.b.phase == .ready)
    #expect(model.playWhenReady.isEmpty)
    await model.finishForShutdown()
}
