import AVFoundation
import Dispatch
import Foundation
import Testing
@testable import TDJCore

@Test @MainActor func recordingFinalDrainPreservesBacklogLargerThanTwoNormalPasses() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let queue = DispatchQueue(label: "test.recording-held-writer", qos: .utility)
    queue.suspend()
    var suspended = true
    defer { if suspended { queue.resume() } }
    let ring = try RecordingBuffer(capacity: 1_500_000)
    let recorder = try SetRecorder(directory: root, sampleRate: 48000, buffer: ring,
        location: "Final drain regression", writerQueue: queue)
    let frames = 1_200_000
    let left = (0..<frames).map { Float($0 % 127) / 128 }
    let right = left.map { -$0 / 2 }
    left.withUnsafeBufferPointer { l in
        right.withUnsafeBufferPointer { r in
            ring.capture(frames: UInt32(frames), left: l.baseAddress!, right: r.baseAddress!)
        }
    }
    #expect(ring.capturedFrames == UInt64(frames) && ring.droppedFrames == 0)
    let (enqueued, signal) = AsyncStream<Void>.makeStream()
    let finalise = Task {
        try await recorder.finish(onWriterEnqueued: { signal.yield(()); signal.finish() })
    }
    var events = enqueued.makeAsyncIterator()
    _ = await events.next()
    queue.resume(); suspended = false
    let url = try await finalise.value
    let file = try AVAudioFile(forReading: url)
    #expect(file.length == Int64(ring.capturedFrames), "Finalisation must save every accepted frame after capture stops.")
    let buffer = try #require(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: UInt32(frames)))
    try file.read(into: buffer)
    #expect(buffer.frameLength == UInt32(frames))
    let channels = try #require(buffer.floatChannelData)
    #expect((0..<Int(buffer.frameLength)).allSatisfy { channels[0][$0] == left[$0] && channels[1][$0] == right[$0] })
    #expect(SetRecorder.savedRecordings(in: root).map { $0.resolvingSymlinksInPath() } == [url.resolvingSymlinksInPath()])
}
