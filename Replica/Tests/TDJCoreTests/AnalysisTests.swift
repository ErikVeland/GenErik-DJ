import AVFoundation
import Foundation
import Testing

@testable import TDJCore

private var fixtures: URL {
    var url = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 { url.deleteLastPathComponent() }
    return url.appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures")
}

@Test func knownClockTemposAndPickup() throws {
    for (name, bpm, anchor) in [
        ("clock-a-120.wav", 120.0, 0.0), ("clock-b-128.wav", 128.0, 0.0), ("clock-b-120-pickup.wav", 120.0, 11025.0),
    ] {
        let result = try AudioAnalyzer.analyze(url: fixtures.appendingPathComponent(name))
        #expect(abs(try #require(result.bpm) - bpm) < 0.25)
        #expect(abs(try #require(result.beatAnchorFrame) - anchor) <= 441)
        #expect(result.channelCount == 2)
        #expect(result.waveform.count == Int(ceil(Double(result.frameCount) / Double(result.waveformFramesPerBin))))
    }
}

@Test func aSingleToneDoesNotInventABeatOrKey() throws {
    let result = try AudioAnalyzer.analyze(url: fixtures.appendingPathComponent("tone-stereo-440.wav"))
    #expect(result.bpm == nil)
    #expect(result.key == nil)
    #expect(result.chroma[9] == result.chroma.max())
    #expect(result.contentSHA256 == "888d8a4d5503243a2f4b39b20a4b0341f5100cc7493c024d85b5f046a0f5ba38")
}

@Test func silenceAndATonalChord() throws {
    for silent in [true, false] {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
        defer { try? FileManager.default.removeItem(at: url) }
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2))
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44100 * 3))
        buffer.frameLength = buffer.frameCapacity
        let channels = try #require(buffer.floatChannelData)
        for i in 0..<Int(buffer.frameLength) {
            let time = Double(i) / 44100
            let sample =
                silent ? 0 : [261.6256, 329.6276, 391.9954].reduce(0.0) { $0 + sin(2 * .pi * $1 * time) * 0.1 }
            channels[0][i] = Float(sample)
            channels[1][i] = -Float(sample)
        }
        do {
            let file = try AVAudioFile(forWriting: url, settings: format.settings)
            try file.write(from: buffer)
        }
        let result = try AudioAnalyzer.analyze(url: url)
        #expect(result.bpm == nil)
        if silent {
            #expect(result.key == nil)
        } else {
            #expect(result.key == MusicalKey(tonic: 0, mode: .major))
            #expect(result.waveform.contains { $0.rms > 0.01 })
        }
    }
}

@Test func missingAndNonAudioFilesFail() throws {
    #expect(throws: (any Error).self) { try AudioAnalyzer.analyze(url: URL(fileURLWithPath: "/no-such-tdj-audio.wav")) }
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try Data("not audio".utf8).write(to: url)
    #expect(throws: (any Error).self) { try AudioAnalyzer.analyze(url: url) }
}

@Test func aacDecodeAndEmbeddedMetadata() async throws {
    let url = try #require(
        Bundle.module.url(forResource: "metadata-clock", withExtension: "m4a", subdirectory: "Fixtures"))
    let result = try AudioAnalyzer.analyze(url: url)
    #expect(abs(try #require(result.bpm) - 120) < 0.25)
    let metadata = try await EmbeddedMetadata.read(url: url)
    #expect(metadata.title == "Metadata clock")
    #expect(metadata.artist == "Synthetic fixture")
    #expect(metadata.genre == "House")
}

@Test func aacPlaybackCacheProducesAudioWithoutRewritingTheSource() async throws {
    let source = try #require(
        Bundle.module.url(forResource: "metadata-clock", withExtension: "m4a", subdirectory: "Fixtures"))
    let hash = try AudioAnalyzer.sha256(url: source)
    let analysis = try AudioAnalyzer.analyze(url: source)
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try WorkspaceStore(root: root)
    try FileManager.default.copyItem(at: source, to: store.mediaDirectory.appendingPathComponent("clock.m4a"))
    let track = try Track(title: "AAC playback clock", mediaFilename: "clock.m4a", analysis: analysis)
    #expect(throws: CancellationError.self) {
        try PCMCache.prepare(track: track, store: store, checkCancellation: { throw CancellationError() })
    }
    let asset = try await PCMCache.prepareAsync(track: track, store: store)
    let cached = try await PCMCache.prepareAsync(track: track, store: store)
    #expect(asset.frames == cached.frames)
    let core = try SampleTransport()
    let generation = try core.load(cached, deck: .a, grid: track.grid)
    try core.play(deck: .a, generation: generation)
    let rendered = core.renderOffline(frames: 48000)
    #expect(rendered.left.contains { abs($0) > 0.001 })
    #expect(abs(try #require(core.snapshot()?.a.sourceFrame) - 44100) < 0.001)
    #expect(try AudioAnalyzer.sha256(url: source) == hash)
}
