import Darwin
import Foundation
import Testing

@testable import TDJCore

private func residentBytes() throws -> UInt64 {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<integer_t>.size)
    let result = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
        }
    }
    try #require(result == KERN_SUCCESS)
    return info.resident_size
}

private final class HashMemoryProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var peak: UInt64 = 0
    private var checks = 0

    func sample() throws {
        let bytes = try residentBytes()
        lock.withLock {
            peak = max(peak, bytes)
            checks += 1
        }
    }

    var result: (peak: UInt64, checks: Int) { lock.withLock { (peak, checks) } }
}

// Run this process-wide memory check alone with GENERIK_DJ_CHECK_HASH_MEMORY=1.
@Test(.enabled(if: ProcessInfo.processInfo.environment["GENERIK_DJ_CHECK_HASH_MEMORY"] == "1"))
func largeSourceHashReleasesChunksBeforeTheWorkerFinishes() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    try #require(FileManager.default.createFile(atPath: url.path, contents: nil))
    let writer = try FileHandle(forWritingTo: url)
    try writer.truncate(atOffset: 256 * 1024 * 1024)
    try writer.close()
    let probe = HashMemoryProbe()
    let baseline = try residentBytes()
    let hash = try await AnalysisWorker.shared.run { check in
        try AudioAnalyzer.sha256(url: url) {
            try check()
            try probe.sample()
        }
    }
    let growth = probe.result.peak > baseline ? probe.result.peak - baseline : 0
    print("Large-source hash peak growth: \(growth) bytes")
    #expect(growth < 64 * 1024 * 1024)
    #expect(probe.result.checks == 256)
    #expect(hash == "a6d72ac7690f53be6ae46ba88506bd97302a093f7108472bd9efc3cefda06484")
}

@Test func sourceHashPreservesPartialChunksAndRecoversAfterCancellation() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    try Data(repeating: 0xa5, count: 1_048_593).write(to: url)
    do {
        _ = try await AnalysisWorker.shared.run { _ in
            try AudioAnalyzer.sha256(url: url) { throw CancellationError() }
        }
        Issue.record("Cancelled hashing returned a digest.")
    } catch is CancellationError {}
    let hash = try await AnalysisWorker.shared.run { check in
        try AudioAnalyzer.sha256(url: url, checkCancellation: check)
    }
    #expect(hash == "9ad443c1bd7a28b33711e7454b91549ebe6b6915be2c3bebbb28e0c415aab4ef")
    try Data().write(to: url)
    #expect(try AudioAnalyzer.sha256(url: url) == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
}
