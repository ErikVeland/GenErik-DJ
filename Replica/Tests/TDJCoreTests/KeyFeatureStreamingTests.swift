import AVFoundation
import Foundation
import Testing
@testable import TDJCore

@Suite struct KeyFeatureStreamingTests {
    @Test(arguments: [44100.0, 48000.0])
    func decodesOnceAndBoundsMemoryWhenSkippingCachedWindows(_ rate: Double) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("pulses.caf")
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2))
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 8192))
        let total = Int(rate * 60)
        do {
            let file = try AVAudioFile(forWriting: url, settings: format.settings)
            for first in stride(from: 0, to: total, by: 8192) {
                buffer.frameLength = AVAudioFrameCount(min(8192, total - first))
                for i in 0..<Int(buffer.frameLength) {
                    buffer.floatChannelData![0][i] = (first + i) % 4410 < 10 ? 0.25 : 0
                    buffer.floatChannelData![1][i] = (first + i) % 6600 < 5 ? 0.125 : 0
                }
                try file.write(from: buffer)
            }
        }
        let filters = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/TDJCore/KeyModelAssets/cqt.json")
        let measurement = AnalysisMeasurement(runID: "test", jobID: "stream", pass: "key", duration: 60)
        try AnalysisMeasurement.$current.withValue(measurement) {
            let audio = try KeyCQTAudio(url: url, filtersURL: filters)
            var values = [Float](repeating: 0, count: 50 * 105)
            try values.withUnsafeMutableBufferPointer { buffer in
                try audio.fill(0..<10, into: buffer.baseAddress!)
                try audio.fill((audio.frameCount - 50)..<audio.frameCount, into: buffer.baseAddress!)
            }
            let finite = values.allSatisfy { $0.isFinite }
            #expect(finite)
            #expect(values.max()! > 0)
        }
        let record = measurement.finish(outcome: "success")
        let decoded = try #require(record.counters["keySourceDecodedFrames"])
        #expect(decoded > Int64(total * 9 / 10))
        #expect(decoded <= Int64(total))
        let peak = try #require(record.counters["keySourcePeakBufferedFrames"])
        #expect(peak <= 131072)
        let cancelled = AnalysisMeasurement(runID: "test", jobID: "cancel", pass: "key", duration: 60)
        try AnalysisMeasurement.$current.withValue(cancelled) {
            let audio = try KeyCQTAudio(url: url, filtersURL: filters,
                checkCancellation: { throw CancellationError() })
            var values = [Float](repeating: -1, count: 105)
            #expect(throws: CancellationError.self) {
                try values.withUnsafeMutableBufferPointer {
                    try audio.fill((audio.frameCount - 1)..<audio.frameCount, into: $0.baseAddress!)
                }
            }
            #expect(values == [Float](repeating: -1, count: 105))
        }
        #expect(cancelled.finish(outcome: "cancelled").counters["keySourceDecodedFrames"] == nil)
    }
}
