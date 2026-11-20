import AVFoundation
import Foundation
import Testing
@testable import TDJCore

@Test func extendedRecordingRolloverCarriesTrackNamesAndSessionTimes() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let core = try SampleTransport(sampleRate: 8192)
    let asset = try PCMAsset(interleavedStereo: [Float](repeating: 0.1, count: 120000), sampleRate: 8192)
    let a = try core.load(asset, deck: .a, grid: nil, synced: false)
    let b = try core.load(asset, deck: .b, grid: nil, synced: false)
    let queue = DispatchQueue(label: "test.recording-track-rollover")
    queue.suspend()
    var suspended = true
    defer { if suspended { queue.resume() } }
    let recorder = try SetRecorder(directory: root, sampleRate: 8192, buffer: core.recording, location: "Tracks",
                                   writerQueue: queue, maximumPartFrames: 16384)
    recorder.registerTrack(deck: 0, generation: a, artist: "First", title: "A")
    recorder.registerTrack(deck: 1, generation: b, artist: "Second", title: "B")
    try core.play(deck: .a, generation: a)
    _ = core.renderOffline(frames: 20000)
    try core.play(deck: .b, generation: b)
    _ = core.renderOffline(frames: 20000)
    recorder.stopCapture()
    queue.resume()
    suspended = false
    let first = try await recorder.finish().resolvingSymlinksInPath()
    let other = SetRecorder.savedRecordings(in: root).map { $0.resolvingSymlinksInPath() }
        .filter { $0 != first }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    #expect(other.count == 2)
    #expect(try String(contentsOf: first.deletingPathExtension().appendingPathExtension("txt"), encoding: .utf8)
            == "00:00:00 - First - A\n")
    for part in other {
        #expect(try String(contentsOf: part.deletingPathExtension().appendingPathExtension("txt"), encoding: .utf8)
                == "00:00:00 - First - A\n00:00:00 - Second - B\n")
    }
    #expect(try String(contentsOf: first.deletingPathExtension().appendingPathExtension("session.txt"), encoding: .utf8)
            == "00:00:00 - First - A\n00:00:02 - Second - B\n")
    #expect(core.snapshot()?.a.phase == .playing)
    #expect(core.snapshot()?.b.phase == .playing)
}

@Test func extendedRecordingRolloverRetainsIncompleteAudioOnOpenFailure() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let queue = DispatchQueue(label: "test.recording-rollover-failure")
    queue.suspend()
    var suspended = true
    defer { if suspended { queue.resume() } }
    let ring = try RecordingBuffer(capacity: 40000)
    let recorder = try SetRecorder(directory: root, sampleRate: 48000, buffer: ring, location: "Failure",
                                   writerQueue: queue, maximumPartFrames: 16384)
    let blocked = root.appendingPathComponent(recorder.url.deletingPathExtension().lastPathComponent + "-part-002.incomplete.aiff")
    try FileManager.default.createDirectory(at: blocked, withIntermediateDirectories: false)
    let samples = [Float](repeating: 0.25, count: 40000)
    samples.withUnsafeBufferPointer { ring.capture(frames: 40000, left: $0.baseAddress!, right: $0.baseAddress!) }
    recorder.stopCapture()
    queue.resume()
    suspended = false
    do {
        _ = try await recorder.finish()
        Issue.record("A failed part creation must not report a complete recording.")
    } catch {
        #expect(recorder.hasFailed)
        #expect(SetRecorder.savedRecordings(in: root).isEmpty)
        let partial = recorder.url.deletingPathExtension().appendingPathExtension("incomplete.aiff")
        #expect(try AVAudioFile(forReading: partial).length == 16384)
    }
}
