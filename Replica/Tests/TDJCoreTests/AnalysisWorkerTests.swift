import Foundation
import Testing

@testable import TDJCore

private final class WorkerProbe: @unchecked Sendable {
    let lock = NSLock()
    var active = 0
    var maximum = 0
    func begin() {
        lock.withLock {
            active += 1
            maximum = max(maximum, active)
        }
    }
    func end() { lock.withLock { active -= 1 } }
}

@Test func backgroundAnalysisSerializesConcurrentRequestsAndCancelsRunningWork() async throws {
    let worker = AnalysisWorker()
    let probe = WorkerProbe()
    try await withThrowingTaskGroup(of: Int.self) { group in
        for index in 0..<8 {
            group.addTask {
                try await worker.run { check in
                    probe.begin()
                    defer { probe.end() }
                    try check()
                    Thread.sleep(forTimeInterval: 0.005)
                    return index
                }
            }
        }
        var values = Set<Int>()
        for try await value in group { values.insert(value) }
        #expect(values.count == 8)
    }
    #expect(probe.maximum == 1)
    let started = AsyncStream<Void>.makeStream()
    let task = Task {
        try await worker.run { check in
            started.continuation.yield(())
            for _ in 0..<2000 {
                try check()
                Thread.sleep(forTimeInterval: 0.001)
            }
            return 1
        }
    }
    var iterator = started.stream.makeAsyncIterator()
    _ = await iterator.next()
    task.cancel()
    do {
        _ = try await task.value
        Issue.record("Cancelled analysis completed successfully.")
    } catch is CancellationError {}
    let next = try await worker.run { _ in 2 }
    #expect(next == 2)
}
