import Foundation
import Testing
@testable import TDJCore
@testable import TDJInterface

@Suite(.serialized)
struct RecoveryIntegrationTests {
    @Test(.timeLimit(.minutes(1)), arguments: [true, false]) @MainActor func recoveryPreparesColdStreamedDropBeforeTheFinalBeat(manualMarker: Bool) async throws {
        var project = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 { project.deleteLastPathComponent() }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = try WorkspaceStore(root: root)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = project.appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/clock-a-120.wav")
        try FileManager.default.copyItem(at: source, to: store.mediaDirectory.appendingPathComponent("source.wav"))
        let analysis = AudioAnalysis(implementation: "recovery-test", configurationID: "fixture", contentSHA256: "recovery",
            sampleRate: 44100, frameCount: 705600, channelCount: 2, waveformFramesPerBin: 441,
            waveform: .init(repeating: .init(minimum: -0.5, maximum: 0.5, rms: 0.5), count: 1600),
            bpm: 120, beatAnchorFrame: 0, tempoConfidence: 1, key: nil, keyConfidence: 0, chroma: [], timbre: [])
        let track = try Track(title: "Recovery", mediaFilename: "source.wav", analysis: analysis)
        let controller = try PlaybackController(offline: true, streamingPlayback: true)
        defer { controller.stopAudio() }
        try await controller.load(track: track, store: store, deck: .a)
        try controller.play(.a)
        try controller.perform(.jump, deck: .a, value: 700000)
        await controller.flushSourcePreparations()
        let timing = try #require(track.timing)
        let plan = try #require(RecoveryPlan(waveform: analysis.waveform, framesPerBin: 441,
            frameCount: 705600, timing: timing, dropOverride: manualMarker ? 176400 : nil))
        #expect(plan.dropFrame == (manualMarker ? 176400 : 0))
        try await controller.prepareRecoveryReplay(plan, deck: .a)
        #expect(controller.core.snapshot()?.a.recoveryArmed == true)
        try controller.setMasterBPM(144)
        await controller.flushSourcePreparations()
        #expect(controller.core.snapshot()?.masterBPM == 144)
        #expect(controller.core.snapshot()?.a.recoveryArmed == true)
        for _ in 0..<16 {
            _ = controller.core.renderOffline(frames: 512)
            try await Task.sleep(for: .milliseconds(1))
        }
        #expect(controller.core.snapshot()?.a.recoveryActive == true)
        #expect(controller.core.snapshot()?.a.phase == .playing)
        #expect(!controller.core.streamingSummary().continuityFailed)
        try controller.play(.a)
        #expect(controller.core.snapshot()?.a.recoveryArmed == false)
    }

    @Test @MainActor func recoverySettingsPersistAndDefaultInLegacyFiles() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("performance.json")
        var settings = PerformancePreparation()
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(settings)) as? [String: Any])
        object.removeValue(forKey: "recoveryValue")
        try JSONSerialization.data(withJSONObject: object).write(to: url)
        #expect(try PerformancePreparation.load(from: url).recovery.mode == .replayLastDrop)
        settings.recovery.mode = .autoMix; settings.recovery.leadBars = 8
        settings.recovery.dropFrames["track"] = 1234
        try settings.save(to: url)
        #expect(try PerformancePreparation.load(from: url).recovery == settings.recovery)
        settings.recovery.leadBars = 12
        #expect(throws: TransportError.invalid) { try settings.save(to: url) }
    }
}
