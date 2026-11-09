import Foundation
@testable import TDJCore
import Testing

@testable import TDJInterface

private func displayAnalysis(count: Int, content: String = "same-audio", level: Float = 0.4) -> AudioAnalysis {
    AudioAnalysis(
        implementation: "test", configurationID: "opening", contentSHA256: content, sampleRate: 48000,
        frameCount: 48000 * 1200, channelCount: 2, waveformFramesPerBin: 480,
        waveform: Array(repeating: WaveformBin(minimum: -level, maximum: level, rms: level / 2), count: count),
        bpm: nil, beatAnchorFrame: nil, tempoConfidence: 0, key: nil, keyConfidence: 0, chroma: [], timbre: [])
}

@Test func growingWaveformKeepsItsLastDrawingUntilTheReplacementIsReady() {
    let first = displayAnalysis(count: 400)
    let prepared = (WaveformIndexKey(first), WaveformRangeIndex(first.waveform))
    var next = displayAnalysis(count: 800)
    let growing = WaveformIndexes.visible(next, prepared: prepared)
    #expect(growing.count == 400)
    #expect(growing.extent(from: 0, to: 400).maximum == 0.4)
    next = next.replacingWaveform(next.waveform, configurationID: "opening-waveform", frameCount: next.frameCount, decodedFrames: nil)
    #expect(WaveformIndexes.visible(next, prepared: prepared).count == 400)
    let ready = WaveformIndexes.visible(next, prepared: (WaveformIndexKey(next), WaveformRangeIndex(next.waveform)))
    #expect(ready.count == 800)
}

@Test func waveformDrawingNeverReusesAnotherSourcesIndexOrStartsBlank() {
    let first = displayAnalysis(count: 400)
    let prepared = (WaveformIndexKey(first), WaveformRangeIndex(first.waveform))
    let replacement = displayAnalysis(count: 800, content: "other-audio", level: 0.2)
    let initial = WaveformIndexes.visible(replacement, prepared: prepared)
    #expect(initial.count == 128)
    #expect(initial.extent(from: 0, to: 128).maximum == 0.2)
    #expect(WaveformIndexes.visible(first, prepared: nil).count == 128)
    let differentLength = first.replacingWaveform(first.waveform, configurationID: first.configurationID, frameCount: 48000, decodedFrames: nil)
    #expect(WaveformIndexes.visible(differentLength, prepared: prepared).count == 128)
}

@Test @MainActor func bandWaveformWaitsForPlaybackBeforePreparingItsPCMCache() async throws {
    let (model, root, track) = try await loadPlayheadFixture()
    defer { try? FileManager.default.removeItem(at: root) }
    let core = model.playback.core
    let asset = try PCMAsset(interleavedStereo: [Float](repeating: 0.2, count: 48000 * 4), sampleRate: 48000)
    let generation = try core.load(asset, deck: .b, grid: nil)
    try core.play(deck: .b, generation: generation)
    _ = core.renderOffline(frames: 128)
    let cache = BandWaveforms.cacheURL(track: track, store: model.store)
    let bands = BandWaveforms()
    let work = Task { await bands.load(track: track, store: model.store, core: core) }
    try await Task.sleep(for: .milliseconds(150))
    #expect(!FileManager.default.fileExists(atPath: cache.path))
    try core.play(deck: .b, generation: generation)
    core.processControlsWhileIdle()
    let result = await work.value
    #expect(result?.frameCount == Int(track.analysis.frameCount))
    #expect(FileManager.default.fileExists(atPath: cache.path))
    await model.finishForShutdown()
}

@Test @MainActor func cancelledBandWaveformDoesNotResumeUnneededWorkAfterPlayback() async throws {
    let (model, root, track) = try await loadPlayheadFixture()
    defer { try? FileManager.default.removeItem(at: root) }
    let core = model.playback.core
    let asset = try PCMAsset(interleavedStereo: [Float](repeating: 0.2, count: 48000 * 4), sampleRate: 48000)
    let generation = try core.load(asset, deck: .b, grid: nil)
    try core.play(deck: .b, generation: generation)
    _ = core.renderOffline(frames: 128)
    let bands = BandWaveforms()
    let work = Task { await bands.load(track: track, store: model.store, core: core) }
    try await Task.sleep(for: .milliseconds(50))
    work.cancel()
    #expect(await work.value == nil)
    #expect(core.snapshot()?.b.phase == .playing)
    try core.play(deck: .b, generation: generation)
    core.processControlsWhileIdle()
    #expect(!FileManager.default.fileExists(atPath: BandWaveforms.cacheURL(track: track, store: model.store).path))
    let replacement = await bands.load(track: track, store: model.store, core: core)
    #expect(replacement?.frameCount == Int(track.analysis.frameCount))
    await model.finishForShutdown()
}

@Test @MainActor func cancellingOneBandWaveformReaderKeepsTheOtherDecksRequest() async throws {
    let (model, root, track) = try await loadPlayheadFixture()
    defer { try? FileManager.default.removeItem(at: root) }
    let core = model.playback.core
    let asset = try PCMAsset(interleavedStereo: [Float](repeating: 0.2, count: 48000 * 4), sampleRate: 48000)
    let generation = try core.load(asset, deck: .b, grid: nil)
    try core.play(deck: .b, generation: generation)
    _ = core.renderOffline(frames: 128)
    let bands = BandWaveforms()
    let first = Task { await bands.load(track: track, store: model.store, core: core) }
    let second = Task { await bands.load(track: track, store: model.store, core: core) }
    try await Task.sleep(for: .milliseconds(50))
    first.cancel()
    try core.play(deck: .b, generation: generation)
    core.processControlsWhileIdle()
    #expect(await first.value == nil)
    #expect(await second.value?.frameCount == Int(track.analysis.frameCount))
    await model.finishForShutdown()
}
