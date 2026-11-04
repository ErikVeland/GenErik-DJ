import AVFoundation
import CTDJTransport
import Foundation
import Testing

@testable import TDJCore

@Test func setRecordingMatchesRenderedMasterAndTransfersAsAIFF() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let core = try SampleTransport()
    let samples = (0..<24000).flatMap { i -> [Float] in
        let sample = Float(sin(Double(i) * 0.1)) * 0.4
        return [sample, -sample]
    }
    let asset = try PCMAsset(interleavedStereo: samples, sampleRate: 48000)
    let a = try core.load(asset, deck: .a, grid: nil, synced: false)
    let b = try core.load(asset, deck: .b, grid: nil, synced: false)
    try core.play(deck: .a, generation: a)
    try core.play(deck: .b, generation: b)
    _ = core.renderOffline(frames: 512)  // Excluded pre-recording audio.
    let recorder = try SetRecorder(directory: root, sampleRate: core.sampleRate, buffer: core.recording)
    var expected: [Float] = []
    for count in [127, 512, 4096, 37] { expected += core.renderOffline(frames: count).left }
    let url = try await recorder.finish()
    _ = core.renderOffline(frames: 1000)  // Excluded post-recording audio.
    let transferred = root.appendingPathComponent("Transferred.aiff")
    try FileManager.default.copyItem(at: url, to: transferred)
    #expect(try Data(contentsOf: url) == Data(contentsOf: transferred))
    let bytes = try Data(contentsOf: transferred)
    #expect(String(data: bytes.prefix(4), encoding: .ascii) == "FORM")
    #expect(String(data: bytes[8..<12], encoding: .ascii) == "AIFF")
    let file = try AVAudioFile(forReading: transferred)
    #expect(file.length == expected.count)
    #expect(file.fileFormat.sampleRate == 48000)
    #expect(file.fileFormat.channelCount == 2)
    #expect(file.fileFormat.streamDescription.pointee.mBitsPerChannel == 24)
    let buffer = try #require(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: UInt32(file.length)))
    try file.read(into: buffer)
    for (i, value) in expected.enumerated() {
        #expect(abs(buffer.floatChannelData![0][i] - value) < 0.000001)
        #expect(abs(buffer.floatChannelData![1][i] + value) < 0.000001)
    }
    #expect(SetRecorder.savedRecordings(in: root).count == 2)
}

@Test func recordingOverflowRetainsIncompleteFileAndRejectsSuccess() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let ring = try RecordingBuffer(capacity: 16)
    let recorder = try SetRecorder(directory: root, sampleRate: 48000, buffer: ring)
    let samples = [Float](repeating: 0.2, count: 32)
    samples.withUnsafeBufferPointer { ring.capture(frames: 32, left: $0.baseAddress!, right: $0.baseAddress!) }
    do {
        _ = try await recorder.finish()
        Issue.record("Overflow must not publish a successful recording")
    } catch RecordingError.overflow(let frames) { #expect(frames == 32) }
    #expect(SetRecorder.savedRecordings(in: root).isEmpty)
    #expect(
        try FileManager.default.contentsOfDirectory(atPath: root.path).contains { $0.hasSuffix(".incomplete.aiff") })
}

@Test func recordingRingWrapsAndStopsWithoutLeakingSamplesIntoNextSet() throws {
    let ring = try RecordingBuffer(capacity: 7)
    let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2))
    let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 5))
    let samples: [Float] = [1, 2, 3, 4, 5]
    func push() {
        samples.withUnsafeBufferPointer { ring.capture(frames: 5, left: $0.baseAddress!, right: $0.baseAddress!) }
    }
    ring.start()
    for _ in 0..<10 {
        push()
        #expect(ring.read(into: buffer) == 5)
        #expect(Array(UnsafeBufferPointer(start: buffer.floatChannelData![0], count: 5)) == samples)
    }
    ring.stop()
    push()
    #expect(ring.read(into: buffer) == 0)
    ring.start()
    #expect(ring.read(into: buffer) == 0)
    push()
    #expect(ring.read(into: buffer) == 5)
    ring.stop()
}

@Test func recordingWriterDrainsConcurrentlyAcrossRingWraps() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let ring = try RecordingBuffer(capacity: 32768)
    let recorder = try SetRecorder(directory: root, sampleRate: 48000, buffer: ring)
    try await Task.detached {
        let left = [Float](repeating: 0.125, count: 128)
        let right = [Float](repeating: -0.25, count: 128)
        for _ in 0..<1024 {
            left.withUnsafeBufferPointer { l in
                right.withUnsafeBufferPointer { r in
                    ring.capture(frames: 128, left: l.baseAddress!, right: r.baseAddress!)
                }
            }
            try await Task.sleep(for: .milliseconds(1))
        }
    }.value
    let url = try await recorder.finish()
    let file = try AVAudioFile(forReading: url)
    #expect(file.length == 131072)
    let buffer = try #require(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 131072))
    try file.read(into: buffer)
    #expect(UnsafeBufferPointer(start: buffer.floatChannelData![0], count: 131072).allSatisfy { $0 == 0.125 })
    #expect(UnsafeBufferPointer(start: buffer.floatChannelData![1], count: 131072).allSatisfy { $0 == -0.25 })
}

@Test func recordingFaultFlagResetsForTheNextSet() throws {
    let ring = try RecordingBuffer(capacity: 16)
    ring.start()
    #expect(!ring.hasFailed)
    ring.markWriteFailure()
    #expect(ring.hasFailed)
    ring.stop()
    ring.start()
    #expect(!ring.hasFailed)
    ring.stop()
}

@Test func recordingStopRequestRejectsLaterBlocksAndRetainsAcceptedFrames() throws {
    let ring = try RecordingBuffer(capacity: 7)
    let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2))
    let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 7))
    let accepted: [Float] = [0.125, 0.25, 0.375]
    let rejected: [Float] = [-0.5, -0.75]
    ring.start()
    accepted.withUnsafeBufferPointer { ring.capture(frames: 3, left: $0.baseAddress!, right: $0.baseAddress!) }
    ring.requestStop()
    rejected.withUnsafeBufferPointer { ring.capture(frames: 2, left: $0.baseAddress!, right: $0.baseAddress!) }
    ring.stop()
    #expect(ring.capturedFrames == 3 && ring.droppedFrames == 0)
    #expect(ring.read(into: buffer) == 3)
    #expect(Array(UnsafeBufferPointer(start: buffer.floatChannelData![0], count: 3)) == accepted)
    ring.start()
    #expect(ring.capturedFrames == 0 && !ring.hasFailed)
    rejected.withUnsafeBufferPointer { ring.capture(frames: 2, left: $0.baseAddress!, right: $0.baseAddress!) }
    ring.stop()
    #expect(ring.read(into: buffer) == 2)
    #expect(Array(UnsafeBufferPointer(start: buffer.floatChannelData![1], count: 2)) == rejected)
}

@Test func recordingCaptureStopsBeforeFinalisationWhilePlaybackContinues() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let core = try SampleTransport()
    let asset = try PCMAsset(interleavedStereo: Array(repeating: Float(0.25), count: 12000), sampleRate: 48000)
    let generation = try core.load(asset, deck: .a, grid: nil, synced: false)
    try core.play(deck: .a, generation: generation)
    let recorder = try SetRecorder(directory: root, sampleRate: core.sampleRate, buffer: core.recording)
    let accepted = core.renderOffline(frames: 639).left
    recorder.stopCapture()
    let continuing = core.renderOffline(frames: 1024)
    #expect(core.snapshot()?.a.phase == .playing)
    #expect(core.snapshot()?.a.sourceFrame == 1663)
    #expect(continuing.left.allSatisfy { abs($0 - 0.125) < 0.000001 })
    #expect(core.recording.capturedFrames == 639 && core.recording.droppedFrames == 0)
    let url = try await recorder.finish()
    let file = try AVAudioFile(forReading: url)
    #expect(file.length == 639)
    let buffer = try #require(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 639))
    try file.read(into: buffer)
    for (index, sample) in accepted.enumerated() {
        #expect(abs(buffer.floatChannelData![0][index] - sample) < 0.000001)
        #expect(abs(buffer.floatChannelData![1][index] - sample) < 0.000001)
    }
}

@Test func completedRecordingCreatesMatchingEmptyTracklist() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let ring = try RecordingBuffer(capacity: 1024)
    let recorder = try SetRecorder(directory: root, sampleRate: 48000, buffer: ring)
    let samples = [Float](repeating: 0.2, count: 64)
    samples.withUnsafeBufferPointer { ring.capture(frames: 64, left: $0.baseAddress!, right: $0.baseAddress!) }
    let recording = try await recorder.finish()
    let tracklist = recording.deletingPathExtension().appendingPathExtension("txt")
    #expect(FileManager.default.fileExists(atPath: tracklist.path))
    #expect((try? String(contentsOf: tracklist, encoding: .utf8)) == "")
}

@Test func recordingTracklistUsesCapturedTimeAndPreservesVersion() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let core = try SampleTransport()
    let asset = try PCMAsset(interleavedStereo: [Float](repeating: 0.1, count: 200000), sampleRate: 48000)
    let a = try core.load(asset, deck: .a, grid: nil, synced: false)
    let b = try core.load(asset, deck: .b, grid: nil, synced: false)
    let recorder = try SetRecorder(directory: root, sampleRate: 48000, buffer: core.recording)
    recorder.registerTrack(deck: 0, generation: a, artist: "Artist 1", title: "Track Title 1 (Version)")
    recorder.registerTrack(deck: 1, generation: b, artist: "Artist 2", title: "Track Title 2")
    try core.play(deck: .a, generation: a)
    _ = core.renderOffline(frames: 96000)
    try core.play(deck: .b, generation: b)
    _ = core.renderOffline(frames: 1024)
    let recording = try await recorder.finish()
    let contents = try String(
        contentsOf: recording.deletingPathExtension().appendingPathExtension("txt"), encoding: .utf8)
    #expect(contents == "00:00:00 - Artist 1 - Track Title 1 (Version)\n00:00:02 - Artist 2 - Track Title 2\n")
}

@Test func recordingNameIncludesLocationDateAndTime() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let ring = try RecordingBuffer(capacity: 128)
    let recorder = try SetRecorder(directory: root, sampleRate: 48000, buffer: ring)
    let samples = [Float](repeating: 0.1, count: 64)
    samples.withUnsafeBufferPointer { ring.capture(frames: 64, left: $0.baseAddress!, right: $0.baseAddress!) }
    let recording = try await recorder.finish()
    #expect(recording.lastPathComponent.hasPrefix("Unknown Location - "))
    #expect(
        recording.deletingPathExtension().appendingPathExtension("txt").lastPathComponent
            == recording.deletingPathExtension().lastPathComponent + ".txt")
}

@Test func recordingNameSanitisesLocationAndMatchesTracklist() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let ring = try RecordingBuffer(capacity: 128)
    let recorder = try SetRecorder(directory: root, sampleRate: 48000, buffer: ring, location: "Brisbane / The Venue")
    let samples = [Float](repeating: 0.1, count: 64)
    samples.withUnsafeBufferPointer { ring.capture(frames: 64, left: $0.baseAddress!, right: $0.baseAddress!) }
    let recording = try await recorder.finish()
    #expect(recording.lastPathComponent.hasPrefix("Brisbane   The Venue - "))
    #expect(
        FileManager.default.fileExists(atPath: recording.deletingPathExtension().appendingPathExtension("txt").path))
}

@Test func tracklistExcludesMutedDeckUntilItEntersMaster() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let core = try SampleTransport()
    let asset = try PCMAsset(interleavedStereo: [Float](repeating: 0.2, count: 400000), sampleRate: 48000)
    let a = try core.load(asset, deck: .a, grid: nil, synced: false)
    let b = try core.load(asset, deck: .b, grid: nil, synced: false)
    try core.setMixer(.crossfader, value: 0)
    try core.play(deck: .a, generation: a)
    try core.play(deck: .b, generation: b)
    _ = core.renderOffline(frames: 512)
    let recorder = try SetRecorder(directory: root, sampleRate: 48000, buffer: core.recording)
    recorder.registerTrack(deck: 0, generation: a, artist: "First", title: "Track")
    recorder.registerTrack(deck: 1, generation: b, artist: "Second", title: "Track")
    _ = core.renderOffline(frames: 96000)
    try core.setMixer(.crossfader, value: 0.5)
    _ = core.renderOffline(frames: 1024)
    let recording = try await recorder.finish()
    let contents = try String(
        contentsOf: recording.deletingPathExtension().appendingPathExtension("txt"), encoding: .utf8)
    #expect(contents == "00:00:00 - First - Track\n00:00:02 - Second - Track\n")
}

@Test func tracklistCapacityFailureRetainsIncompleteAudio() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let ring = try RecordingBuffer(capacity: 8192)
    let recorder = try SetRecorder(directory: root, sampleRate: 48000, buffer: ring)
    var sample: Float = 0.1
    let offsets: [UInt32] = [0, UInt32.max]
    for generation in 1...4097 {
        let generations: [UInt64] = [UInt64(generation), 0]
        generations.withUnsafeBufferPointer { ids in
            offsets.withUnsafeBufferPointer { positions in
                withUnsafePointer(to: &sample) { pointer in
                    tdj_recording_push_tracks(
                        ring.nativeAudioRenderPointer, 1, pointer, pointer, ids.baseAddress!, positions.baseAddress!)
                }
            }
        }
    }
    do {
        _ = try await recorder.finish()
        Issue.record("An overflowing tracklist must not publish an incomplete list as successful")
    } catch RecordingError.tracklistOverflow {
        #expect(SetRecorder.savedRecordings(in: root).isEmpty)
        #expect(
            try FileManager.default.contentsOfDirectory(atPath: root.path).contains { $0.hasSuffix(".incomplete.aiff") }
        )
    }
}

@Test func tracklistWriteFailureRetainsIncompleteRecording() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let ring = try RecordingBuffer(capacity: 128)
    let recorder = try SetRecorder(directory: root, sampleRate: 48000, buffer: ring)
    let tracklist = recorder.url.deletingPathExtension().appendingPathExtension("txt")
    try FileManager.default.createDirectory(at: tracklist, withIntermediateDirectories: false)
    let samples = [Float](repeating: 0.1, count: 64)
    samples.withUnsafeBufferPointer { ring.capture(frames: 64, left: $0.baseAddress!, right: $0.baseAddress!) }
    do {
        _ = try await recorder.finish()
        Issue.record("A failed tracklist write must not publish a successful recording")
    } catch {
        #expect(SetRecorder.savedRecordings(in: root).isEmpty)
        #expect(
            try FileManager.default.contentsOfDirectory(atPath: root.path).contains { $0.hasSuffix(".incomplete.aiff") }
        )
    }
}
