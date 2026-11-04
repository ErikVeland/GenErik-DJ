import AVFoundation
import Foundation
import Testing

@testable import TDJCore
@testable import TDJInterface
@testable import TDJRuntimeChecks

private func fixturePCM(_ url: URL) throws -> [Float] {
    let file = try AVAudioFile(forReading: url)
    let buffer = try #require(
        AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)))
    try file.read(into: buffer)
    return (0..<Int(buffer.frameLength)).flatMap { [buffer.floatChannelData![0][$0], buffer.floatChannelData![1][$0]] }
}

@Test func fractionalFixturePresetsPreserveEveryExistingMode() throws {
    let original: [(AudioRuntimeCheckLaunch, Double, Bool, Bool, Bool, AudioRuntimeKeylockStress)] = [
        (.loop60, 60, false, false, false, .detectedGrid), (.loop300, 300, false, false, false, .detectedGrid),
        (.sequential300, 300, true, false, false, .detectedGrid), (.ui60, 60, false, true, false, .detectedGrid),
        (.uiLoop300Panels, 300, false, true, true, .detectedGrid),
        (.uiSequential300Panels, 300, true, true, true, .detectedGrid),
        (.loop60Near2x, 60, false, false, false, .manual60BPM),
        (.loop300Near2x, 300, false, false, false, .manual60BPM),
        (.uiLoop300PanelsNear2x, 300, false, true, true, .manual60BPM),
    ]
    for (mode, seconds, sequential, live, motion, stress) in original {
        #expect(mode.durationSeconds == seconds && mode.sequential == sequential)
        #expect(mode.liveInterface == live && mode.panelMotion == motion)
        #expect(mode.keylockStress == stress && mode.fixtureSampleRate == 48000)
    }
    for (mode, seconds, motion) in [
        (AudioRuntimeCheckLaunch.loop60Near2x44100, 60.0, false), (.loop300Near2x44100, 300.0, false),
        (.uiLoop300PanelsNear2x44100, 300.0, true),
    ] {
        #expect(try AudioRuntimeCheckLaunch.parse(arguments: ["app", "--audio-check=" + mode.rawValue]) == mode)
        #expect(mode.durationSeconds == seconds && mode.fixtureSampleRate == 44100)
        #expect(
            mode.keylockStress == .manual60BPM && !mode.sequential && mode.liveInterface == motion
                && mode.panelMotion == motion)
    }
}

@Test func fractionalFixtureGeneratorWritesActualWAVRatesFramesAndDeterministicDefaultPCM() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    for rate in [44100.0, 48000.0] {
        let url = root.appendingPathComponent("source-\(Int(rate)).wav")
        try AudioRuntimeChecks.createSource(at: url, seconds: 0.125, sampleRate: rate)
        let file = try AVAudioFile(forReading: url)
        let metadata = try RuntimeFixtureFile(url: url)
        #expect(file.fileFormat.sampleRate == rate && file.processingFormat.sampleRate == rate)
        #expect(file.length == Int64(0.125 * rate) && file.fileFormat.channelCount == 2)
        #expect(metadata.sampleRate == rate && metadata.frames == file.length && metadata.channels == 2)
        let samples = try fixturePCM(url)
        #expect(samples.count == Int(file.length) * 2 && samples.allSatisfy(\.isFinite))
        #expect(samples.contains { abs($0) > 0.001 })
    }
    let url = root.appendingPathComponent("default.wav")
    try AudioRuntimeChecks.createSource(at: url, seconds: 0.125)
    #expect(try fixturePCM(url) == fixturePCM(root.appendingPathComponent("source-48000.wav")))
}

@Test @MainActor func fractionalFixtureInvalidRunInputsCreateNoOutput() async {
    for rate in [Double.nan, Double.infinity, -44100, 0, 44100.5, 48000.5, 96000] {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        do {
            _ = try await AudioRuntimeChecks.run(
                outputDirectory: root, seconds: 60, keylockStress: .manual60BPM, fixtureSampleRate: rate,
                searchCatalogTracks: 1)
            Issue.record("An invalid fixture rate was accepted.")
        } catch {}
        #expect(!FileManager.default.fileExists(atPath: root.path))
    }
    for (seconds, sequential, stress) in [
        (30.0, false, AudioRuntimeKeylockStress.manual60BPM), (60.0, true, .manual60BPM), (300.0, false, .detectedGrid),
    ] {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        do {
            _ = try await AudioRuntimeChecks.run(
                outputDirectory: root, seconds: seconds, sequential: sequential, keylockStress: stress,
                fixtureSampleRate: 44100, searchCatalogTracks: 1)
            Issue.record("An invalid fractional stress scenario was accepted.")
        } catch {}
        #expect(!FileManager.default.fileExists(atPath: root.path))
    }
}

@Test func fractionalFixtureInvalidGeneratorInputsCreateNoFile() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    for (seconds, rate) in [
        (0.125, 0.0), (0.125, Double.nan), (0.0, 44100.0), (Double.nan, 44100.0), (Double.infinity, 48000.0),
        (8116.1, 48000.0), (0.000001, 44100.0),
    ] {
        let url = root.appendingPathComponent(UUID().uuidString + ".wav")
        #expect(throws: TransportError.self) {
            try AudioRuntimeChecks.createSource(at: url, seconds: seconds, sampleRate: rate)
        }
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }
}

@Test @MainActor func fractionalFixtureProductionModelKeepsNative44100GridAndAssetsWith48000Output() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let model = try ReplicaModel(
        root: root.appendingPathComponent("Workspace"), playback: PlaybackController(offline: true))
    defer {
        model.stopAudio()
        try? FileManager.default.removeItem(at: root)
    }
    let source = root.appendingPathComponent("dense44100.wav")
    try AudioRuntimeChecks.createSource(
        at: source, seconds: 16, sampleRate: AudioRuntimeCheckLaunch.loop60Near2x44100.fixtureSampleRate)
    await model.importFiles([source])
    let original = try #require(model.library.tracks.first)
    #expect(original.analysis.sampleRate == 44100 && original.analysis.frameCount == 705600)
    for deck in DeckID.allCases { model.load(trackID: original.id, deck: deck) }
    await model.flushWrites()
    try await model.prepareLoadedWaveforms()
    let configured = try AudioRuntimeKeylockStress.manual60BPM.configuredFixture(original)
    try await AudioRuntimeKeylockStress.manual60BPM.prepareLoadedFixture(configured, model: model)
    let core = model.playback.core
    let initial = try #require(core.snapshot())
    let metadata = try RuntimeFixtureSourceReport(
        requestedSampleRate: 44100, sourceSeconds: 16, generated: RuntimeFixtureFile(url: source), track: configured,
        core: core, snapshot: initial)
    #expect(metadata.matchesRequestedSource && metadata.outputRenderSampleRate == 48000)
    #expect(metadata.nativeAssetSampleRateA == 44100 && metadata.nativeAssetSampleRateB == 44100)
    #expect(metadata.nativeAssetFramesA == 705600 && metadata.nativeAssetFramesB == 705600)
    #expect(metadata.nativeGridSampleRateA == 44100 && metadata.nativeGridSampleRateB == 44100)
    #expect(initial.a.grid?.bpm == 60 && initial.b.grid?.bpm == 60)
    #expect(initial.a.grid?.anchorFrame == 0 && initial.b.grid?.downbeatOffset == 0)
    var observation = RuntimeKeylockStressObservation(
        policy: .manual60BPM, original: original, configured: configured, initial: initial)
    #expect(observation.configurationMatches)
    for bpm in [112.0, 120.0, 128.0] {
        try model.playback.setMasterBPM(bpm)
        await model.playback.flushSourcePreparations()
        model.refreshPlayback()
        observation.observe(model.playbackSnapshot)
        for deck in DeckID.allCases {
            #expect(model.playbackSnapshot?[deck].grid?.sampleRate == 44100)
            #expect(abs((model.playbackSnapshot?[deck].speed ?? 0) - bpm / 60) < 1e-9)
        }
    }
    #expect(observation.report.observedWorkloadMatches)
    #expect(!(try JSONEncoder().encode(metadata)).isEmpty)
    try core.play(deck: .a, generation: initial.a.generation)
    let audio = core.renderOffline(frames: 4096)
    #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
    #expect(audio.left.contains { abs($0) > 0.0001 })
    #expect(core.snapshot()?.sampleRate == 48000)
    await model.finishForShutdown()
}

@Test @MainActor func fractionalFixtureMetadataRejectsMissingNativeAssets() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let model = try ReplicaModel(
        root: root.appendingPathComponent("Workspace"), playback: PlaybackController(offline: true))
    defer {
        model.stopAudio()
        try? FileManager.default.removeItem(at: root)
    }
    let source = root.appendingPathComponent("source.wav")
    try AudioRuntimeChecks.createSource(at: source, seconds: 1, sampleRate: 44100)
    await model.importFiles([source])
    let track = try #require(model.library.tracks.first)
    let core = model.playback.core
    let report = try RuntimeFixtureSourceReport(
        requestedSampleRate: 44100, sourceSeconds: 1, generated: RuntimeFixtureFile(url: source), track: track,
        core: core, snapshot: core.snapshot())
    #expect(
        !report.matchesRequestedSource && report.nativeAssetSampleRateA == nil && report.nativeAssetSampleRateB == nil)
    #expect(report.generated.sampleRate == 44100 && report.outputRenderSampleRate == 48000)
}
