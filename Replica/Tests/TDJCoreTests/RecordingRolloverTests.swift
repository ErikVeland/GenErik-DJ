import AVFoundation
import Foundation
import Testing
@testable import TDJCore

@Test func extendedRecordingRolloverPreservesEverySample() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let queue = DispatchQueue(label: "test.recording-rollover")
    queue.suspend()
    let ring = try RecordingBuffer(capacity: 50000)
    let recorder: SetRecorder
    do {
        recorder = try SetRecorder(directory: root, sampleRate: 48000, buffer: ring, location: "Long set",
                                   writerQueue: queue, maximumPartFrames: 16384)
    } catch { queue.resume(); throw error }
    let samples = (0..<40000).map { Float($0 % 127) / 128 }
    samples.withUnsafeBufferPointer { ring.capture(frames: 40000, left: $0.baseAddress!, right: $0.baseAddress!) }
    recorder.stopCapture()
    queue.resume()
    let first = try await recorder.finish().resolvingSymlinksInPath()
    let files = SetRecorder.savedRecordings(in: root).map { $0.resolvingSymlinksInPath() }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
    #expect(files.count == 3)
    #expect(files.contains(first))
    var joined: [Float] = []
    // The first part has the base name. Numbered parts follow it in capture order.
    let ordered = [first] + files.filter { $0 != first }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    for url in ordered {
        let file = try AVAudioFile(forReading: url)
        #expect(file.length <= 16384)
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: UInt32(file.length)))
        try file.read(into: buffer)
        let channels = try #require(buffer.floatChannelData)
        joined.append(contentsOf: UnsafeBufferPointer(start: channels[0], count: Int(buffer.frameLength)))
        #expect(FileManager.default.fileExists(atPath: url.deletingPathExtension().appendingPathExtension("txt").path))
    }
    let samplesMatch = joined == samples
    #expect(samplesMatch, "Joining the parts must reproduce every captured sample exactly.")
    #expect(ring.droppedFrames == 0)
}
