import Foundation
import Observation
import Testing
@testable import TDJCore
@testable import TDJInterface

@Test func extendedWaveformCacheHasAByteBudget() async throws {
    let samples = [Float](repeating: 0.1, count: 8192)
    let band = try samples.withUnsafeBufferPointer { try BandWaveform(interleavedStereo: $0, sampleRate: 48000) }
    let cache = BandWaveforms(byteBudget: 1020)
    await cache.retain(band, trackID: "first")
    await cache.retain(band, trackID: "second")
    #expect(await cache.cachedCount == 1)
    #expect(await cache.cachedBytes == 1020)
    let longer = try [Float](repeating: 0.1, count: 16384).withUnsafeBufferPointer {
        try BandWaveform(interleavedStereo: $0, sampleRate: 48000)
    }
    await cache.retain(longer, trackID: "too-large")
    #expect(await cache.cachedCount == 1)
    #expect(await cache.cachedBytes == 1020)
    await cache.trimCache()
    #expect(await cache.cachedBytes == 0)
    #expect(await cache.cachedCount == 0)
}

@Test @MainActor func extendedPerformanceDoesNotNotifyUnchangedStatus() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
    model.refreshPlayback()
    withObservationTracking {
        _ = model.isRecording
        _ = model.recordingFinishing
        _ = model.preparingSourceActions
        _ = model.viewport
    } onChange: {
        Issue.record("An unchanged status must not invalidate its observers.")
    }
    for _ in 0..<128 { model.refreshPlayback() }
}

@Test @MainActor func extendedHealthReportIsBoundedAndRetainsEarlierPeaks() throws {
    let health = PerformanceHealthRecorder(sampleLimit: 3, interval: 30)
    var captures = 0
    func capture(_ elapsed: Double) -> PerformanceHealthReport.Sample {
        captures += 1
        return .init(elapsedSeconds: elapsed, footprintBytes: elapsed == 0 ? 1000 : 100,
                     thermalState: elapsed == 0 ? 3 : 0, sampleRate: 48000, audio: nil,
                     streaming: .init(), recordingCapturedFrames: 0, recordingDroppedFrames: 0,
                     recording: false, output: "test", controllers: [])
    }
    _ = health.observe(at: 100, capture: capture)
    for tick in 101..<130 { #expect(health.observe(at: Double(tick), capture: capture) == nil) }
    _ = health.observe(at: 130, capture: capture)
    _ = health.observe(at: 160, capture: capture)
    _ = health.observe(at: 190, capture: capture)
    #expect(captures == 4)
    #expect(health.report.totalSamples == 4)
    #expect(health.report.samples.count == 3)
    #expect(health.report.peakFootprintBytes == 1000)
    #expect(health.report.worstThermalState == 3)
    #expect(health.report.firstSample?.elapsedSeconds == 0)
    health.resetMonitorClock()
    _ = health.observe(at: 10000, force: true, capture: capture)
    #expect(health.report.maximumMonitorGapSeconds == 30)
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let url = root.appendingPathComponent("report.json")
    try health.report.write(to: url)
    let object = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    let samples = try #require(object["samples"] as? [[String: Any]])
    #expect(samples.compactMap { $0["elapsedSeconds"] as? Double } == [60, 90, 9900])
}
