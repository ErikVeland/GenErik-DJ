import Foundation
import Testing

@testable import TDJCore

@Test func measurementCrossesWorkerBoundaryAndRetainsFailureTime() async throws {
    let measurement = AnalysisMeasurement(runID: "run", jobID: "track", pass: "matching", duration: 120)
    enum Failure: Error { case expected }
    do {
        try await AnalysisMeasurement.$current.withValue(measurement) {
            try await AnalysisWorker().run { _ in
                try AnalysisMeasurement.measure("sourceHash") {
                    AnalysisMeasurement.current?.count("hashBytesRead", 42)
                    throw Failure.expected
                }
            }
        }
        Issue.record("The worker did not return the expected error.")
    } catch Failure.expected {}
    let record = measurement.finish(outcome: "failed")
    #expect(record.outcome == "failed")
    #expect(record.counters["hashBytesRead"] == 42)
    #expect(record.stageCalls["sourceHash"] == 1)
    #expect(record.stageCalls["analysisQueueWait"] == 1)
    #expect(try #require(record.stageSeconds["sourceHash"]) >= 0)
    #expect(record.realTimeFactor == record.wallSeconds / 120)
    #expect(AnalysisMeasurement.current == nil)
}

@Test func measurementRecordsCancellationUntilWorkerReturns() async throws {
    let measurement = AnalysisMeasurement(runID: "run", jobID: "track", pass: "matching", duration: .infinity)
    let (started, signal) = AsyncStream<Void>.makeStream()
    let task = Task {
        try await AnalysisMeasurement.$current.withValue(measurement) {
            try await AnalysisWorker().run { check in
                signal.yield(())
                while true {
                    try check()
                    Thread.sleep(forTimeInterval: 0.001)
                }
            }
        }
    }
    for await _ in started { break }
    task.cancel()
    do { try await task.value } catch is CancellationError {}
    let record = measurement.finish(outcome: "cancelled")
    #expect(try #require(record.cancellationResponseSeconds) >= 0)
    #expect(record.durationSeconds == nil)
    #expect(record.realTimeFactor == nil)
    _ = try JSONEncoder().encode(record)
}

@Test func measurementLogAppendsAttemptsAndPreservesFullEvidence() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    let measurement = AnalysisMeasurement(runID: "run", jobID: "track", pass: "matching", duration: 60)
    let record = measurement.finish(outcome: "success")
    #expect(try AnalysisMeasurementLog.append([record], to: url))
    #expect(try AnalysisMeasurementLog.append([record], to: url))
    let lines = try String(contentsOf: url, encoding: .utf8).split(separator: "\n")
    #expect(lines.count == 2)
    let decoded = try JSONDecoder().decode(AnalysisMeasurement.Record.self, from: Data(lines[0].utf8))
    #expect(decoded.jobID == "track")
    let handle = try FileHandle(forWritingTo: url)
    try handle.truncate(atOffset: AnalysisMeasurementLog.maximumBytes)
    try handle.close()
    #expect(try AnalysisMeasurementLog.append([record], to: url) == false)
    let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize
    #expect(size == Int(AnalysisMeasurementLog.maximumBytes))
}
