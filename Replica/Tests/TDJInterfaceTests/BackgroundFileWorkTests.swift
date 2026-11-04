import CoreGraphics
import Darwin
import Foundation
import ImageIO
import Testing

@testable import TDJInterface

private final class WorkObservations: @unchecked Sendable {
    private let lock = NSLock()
    private var entries: [(Int, UInt32, Bool, Int32, Int32, kern_return_t)] = []
    func record(_ value: Int) {
        // qos_class_self reports requested QoS and misses temporary overrides. Also
        // sample public Mach scheduler state; background scheduling priority is at most 4.
        var info = thread_extended_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<thread_extended_info_data_t>.size / MemoryLayout<integer_t>.size)
        let status = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                thread_info(pthread_mach_thread_np(pthread_self()), thread_flavor_t(THREAD_EXTENDED_INFO), $0, &count)
            }
        }
        let entry = (value, qos_class_self().rawValue, Thread.isMainThread, info.pth_priority, info.pth_curpri, status)
        lock.withLock { entries.append(entry) }
    }
    var values: [Int] { lock.withLock { entries.map(\.0) } }
    var allBackground: Bool {
        lock.withLock {
            !entries.isEmpty
                && entries.allSatisfy {
                    $0.1 == QOS_CLASS_BACKGROUND.rawValue && !$0.2 && $0.3 <= 4 && $0.4 <= 4 && $0.5 == KERN_SUCCESS
                }
        }
    }
}

private final class WorkGate: @unchecked Sendable {
    private let entered = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
    private let permit = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var expired = false
    func pause() {
        entered.continuation.yield(())
        let result = permit.wait(timeout: .now() + 60)
        lock.withLock { expired = result == .timedOut }
    }
    func waitUntilPaused() async { for await _ in entered.stream { return } }
    func release() { permit.signal() }
    var timedOut: Bool { lock.withLock { expired } }
}

@Test @MainActor func enforcedFileWorkStaysBackgroundUnderHighPriorityMainActorAwait() async {
    let observations = WorkObservations()
    let gate = WorkGate()
    let worker = BackgroundFileWork(label: "org.generikdj.tests.background-await")
    let producer = Task.detached(priority: .background) {
        await worker.run {
            observations.record(0)
            gate.pause()
            for index in 1...256 { observations.record(index) }
            return 73
        }
    }
    await gate.waitUntilPaused()
    let waiter = Task(priority: .high) { @MainActor in
        #expect(Task.currentPriority == .high)
        return await producer.value
    }
    // The high-priority waiter is live before the synchronous block resumes sampling.
    await Task.yield()
    gate.release()
    #expect(await waiter.value == 73)
    #expect(observations.allBackground)
    #expect(observations.values.count == 257)
    #expect(!gate.timedOut)
}

@Test @MainActor func writerCoalescesWhileBusyAndFlushWaitsForAtomicWriteAtBackgroundQoS() async throws {
    let observations = WorkObservations()
    let gate = WorkGate()
    let writer = CoalescingFileWriter<Int>()
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    let write: @Sendable (Int) throws -> Void = { value in
        observations.record(value)
        if value == 1 {
            gate.pause()
            observations.record(-1)
        }
        try Data(String(value).utf8).write(to: url, options: .atomic)
    }
    var errors: [String] = []
    let submit = Task(priority: .high) { @MainActor in
        writer.enqueue(1, write: write, reportError: { errors.append($0) })
    }
    await submit.value
    await gate.waitUntilPaused()
    writer.enqueue(2, write: write, reportError: { errors.append($0) })
    writer.enqueue(3, write: write, reportError: { errors.append($0) })
    var flushed = false
    let flush = Task(priority: .high) { @MainActor in
        await writer.flush()
        flushed = true
    }
    await Task.yield()
    #expect(!flushed)
    #expect(!FileManager.default.fileExists(atPath: url.path))
    gate.release()
    await flush.value
    #expect(flushed && errors.isEmpty)
    #expect(observations.values == [1, -1, 3])
    #expect(observations.allBackground && !gate.timedOut)
    #expect(try String(contentsOf: url, encoding: .utf8) == "3")
    // A finished writer starts another drain and flush still observes it.
    writer.enqueue(4, write: write, reportError: { errors.append($0) })
    await writer.flush()
    await writer.flush()
    #expect(try String(contentsOf: url, encoding: .utf8) == "4")
    #expect(observations.values == [1, -1, 3, 4])
}

@Test @MainActor func writerReportsFailureOnMainActorAndContinuesThroughCancelledFlushWaiter() async {
    enum Failure: LocalizedError {
        case expected
        var errorDescription: String? { "expected-write-failure" }
    }
    let writer = CoalescingFileWriter<Int>()
    let gate = WorkGate()
    let observations = WorkObservations()
    var errors: [String] = []
    let report: (String) -> Void = { message in
        MainActor.preconditionIsolated()
        errors.append(message)
    }
    let write: @Sendable (Int) throws -> Void = { value in
        observations.record(value)
        if value == 1 {
            gate.pause()
            throw Failure.expected
        }
    }
    writer.enqueue(1, write: write, reportError: { _ in Issue.record("Replaced error callback must not run") })
    await gate.waitUntilPaused()
    writer.enqueue(2, write: write, reportError: report)
    let flush = Task(priority: .high) { @MainActor in await writer.flush() }
    flush.cancel()
    gate.release()
    await flush.value
    await writer.flush()
    #expect(errors == ["expected-write-failure"])
    #expect(observations.values == [1, 2])
    #expect(observations.allBackground && !gate.timedOut)
}

private func artworkFixture() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
    let context = try #require(
        CGContext(
            data: nil, width: 512, height: 256, bitsPerComponent: 8, bytesPerRow: 2048,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    let image = try #require(context.makeImage())
    let output = try #require(CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil))
    CGImageDestinationAddImage(output, image, nil)
    #expect(CGImageDestinationFinalize(output))
    return url
}

@Test @MainActor func artworkDecodeRemainsBackgroundAndSharedCacheSurvivesCancelledWaiter() async throws {
    let observations = WorkObservations()
    let gate = WorkGate()
    let url = try artworkFixture()
    defer { try? FileManager.default.removeItem(at: url) }
    let cache = ArtworkThumbnails { url in
        observations.record(1)
        gate.pause()
        let result = ArtworkThumbnails.decodeThumbnail(url)
        observations.record(2)
        return result
    }
    let owner = Task(priority: .high) { @MainActor in await cache.load(url) }
    await gate.waitUntilPaused()
    let other = Task(priority: .high) { @MainActor in await cache.load(url) }
    owner.cancel()
    await Task.yield()
    gate.release()
    let a = await owner.value
    let b = await other.value
    let image = try #require(b?.image)
    #expect(image === a?.image)
    #expect(image.width == 192 && image.height == 96)
    // Successful decode belongs to the cache, even if its original UI waiter was cancelled.
    try FileManager.default.removeItem(at: url)
    #expect(await cache.load(url)?.image === image)
    #expect(observations.values == [1, 2])
    #expect(observations.allBackground && !gate.timedOut)
}

@Test func artworkFailureIsRetriedAndOldestEntryIsEvictedAtThirtyTwo() async throws {
    let observations = WorkObservations()
    let fixture = try artworkFixture()
    defer { try? FileManager.default.removeItem(at: fixture) }
    let cache = ArtworkThumbnails { url in
        observations.record(url.lastPathComponent == "missing" ? -1 : 1)
        guard url.lastPathComponent != "missing", let result = ArtworkThumbnails.decodeThumbnail(fixture) else {
            return nil
        }
        return ArtworkThumbnail(url: url, image: result.image)
    }
    let missing = URL(fileURLWithPath: "/synthetic/missing")
    #expect(await cache.load(missing) == nil)
    #expect(await cache.load(missing) == nil)
    let urls = (0..<33).map { URL(fileURLWithPath: "/synthetic/artwork-\($0)") }
    let first = try #require(await cache.load(urls[0]))
    for url in urls.dropFirst() { #expect(await cache.load(url) != nil) }
    let before = observations.values.count
    #expect(await cache.load(urls[1]) != nil)
    #expect(observations.values.count == before)
    let reloaded = try #require(await cache.load(urls[0]))
    #expect(first.image !== reloaded.image)
    #expect(observations.values.count == before + 1)
    #expect(observations.values.prefix(2) == [-1, -1])
    #expect(observations.allBackground)
}
