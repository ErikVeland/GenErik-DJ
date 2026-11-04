import Foundation
import Testing

@testable import TDJCore

@Test(arguments: [
    "A" + String(repeating: "\u{0301}", count: 300), "A" + String(repeating: "\u{0344}", count: 100),
    String(repeating: "🎛️", count: 100),
]) func recordingUnicodeLocationCannotExceedFilesystemNameLimit(location: String) async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let ring = try RecordingBuffer(capacity: 128)
    let recorder = try SetRecorder(directory: root, sampleRate: 48000, buffer: ring, location: location)
    let samples = [Float](repeating: 0.1, count: 64)
    samples.withUnsafeBufferPointer { ring.capture(frames: 64, left: $0.baseAddress!, right: $0.baseAddress!) }
    let recording = try await recorder.finish()
    #expect(
        SetRecorder.savedRecordings(in: root).map { $0.resolvingSymlinksInPath() } == [
            recording.resolvingSymlinksInPath()
        ])
    #expect(
        FileManager.default.fileExists(atPath: recording.deletingPathExtension().appendingPathExtension("txt").path))
}
