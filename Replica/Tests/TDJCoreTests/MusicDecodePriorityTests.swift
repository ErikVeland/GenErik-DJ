import AVFoundation
import Darwin
import Foundation
import Testing

@testable import TDJCore

@Test func concurrentMusicDecodesCannotReplaceAnotherCompletedPreparation() async throws {
    var workspace = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 { workspace.deleteLastPathComponent() }
    let source = workspace.appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/routing-left440-right880.wav")
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let destination = root.appendingPathComponent("prepared.caf")
    var successes = 0
    var failures = 0
    try await withThrowingTaskGroup(of: Bool.self) { group in
        for _ in 0..<8 {
            group.addTask(priority: .high) {
                do {
                    try await MusicLibraryAudio.decodeAsset(url: source, destination: destination)
                    return true
                } catch MusicLibraryError.decoding(let reason) {
                    #expect(reason == "The preparation file already exists.")
                    return false
                }
            }
        }
        for try await success in group { if success { successes += 1 } else { failures += 1 } }
    }
    #expect(successes == 1 && failures == 7)
    let original = try AVAudioFile(forReading: source)
    let prepared = try AVAudioFile(forReading: destination)
    #expect(prepared.length == original.length)
    #expect(prepared.processingFormat == original.processingFormat)
}

@Test @MainActor func decodeWorkerBoundaryStaysBackgroundUnderHighPriorityAwait() async throws {
    let worker = AnalysisWorker(label: "org.generikdj.tests.decode-priority")
    for _ in 0..<32 {
        let priority = try await Task.detached(priority: .high) {
            try await worker.run { check in
                try check()
                var info = thread_extended_info_data_t()
                var count = mach_msg_type_number_t(
                    MemoryLayout<thread_extended_info_data_t>.size / MemoryLayout<integer_t>.size)
                let status = withUnsafeMutablePointer(to: &info) { pointer in
                    pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                        thread_info(
                            pthread_mach_thread_np(pthread_self()), thread_flavor_t(THREAD_EXTENDED_INFO), $0, &count)
                    }
                }
                return (qos_class_self().rawValue, info.pth_priority, info.pth_curpri, status, Thread.isMainThread)
            }
        }.value
        #expect(priority.0 == QOS_CLASS_BACKGROUND.rawValue)
        #expect(priority.1 <= 4 && priority.2 <= 4 && priority.3 == KERN_SUCCESS && !priority.4)
    }
}

@Test func completedFileRemainsOwnedWhenCancellationArrivesAfterCommit() async throws {
    let worker = AnalysisWorker(label: "org.generikdj.tests.decode-commit")
    let committed = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
    let resume = DispatchSemaphore(value: 0)
    let destination = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: destination) }
    let task = Task {
        try await worker.run(checkAfterWork: false) { check in
            try check()
            try Data("committed".utf8).write(to: destination, options: .atomic)
            committed.continuation.yield(())
            guard resume.wait(timeout: .now() + 60) == .success else { throw CancellationError() }
            return destination
        }
    }
    for await _ in committed.stream { break }
    task.cancel()
    resume.signal()
    let owned = try await task.value
    #expect(owned == destination)
    #expect(try Data(contentsOf: owned) == Data("committed".utf8))
}
