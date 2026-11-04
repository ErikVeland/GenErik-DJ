import AVFoundation
import CTDJTransport
import Foundation

/// One audio producer and one serial file consumer. Lifetime follows the transport.
public final class RecordingBuffer: @unchecked Sendable {
    private let pointer: OpaquePointer
    public init(capacity: UInt32) throws {
        guard let pointer = tdj_recording_create(capacity) else { throw TransportError.allocation }
        self.pointer = pointer
    }
    var nativeAudioRenderPointer: OpaquePointer { pointer }
    deinit { tdj_recording_destroy(pointer) }
    func start() { tdj_recording_start(pointer) }
    func requestStop() { tdj_recording_request_stop(pointer) }
    func stop() { tdj_recording_stop(pointer) }
    public var hasFailed: Bool { tdj_recording_failed(pointer) }
    func markWriteFailure() { tdj_recording_mark_failed(pointer) }
    public var capturedFrames: UInt64 { tdj_recording_captured(pointer) }
    public var droppedFrames: UInt64 { tdj_recording_dropped(pointer) }
    func capture(frames: UInt32, left: UnsafePointer<Float>, right: UnsafePointer<Float>) {
        tdj_recording_push(pointer, frames, left, right)
    }
    func read(into buffer: AVAudioPCMBuffer) -> UInt32 {
        let channels = buffer.floatChannelData!
        let count = tdj_recording_read(pointer, buffer.frameCapacity, channels[0], channels[1])
        buffer.frameLength = count
        return count
    }
}

public enum RecordingError: Error, LocalizedError {
    case overflow(UInt64)
    case empty, sizeLimit, tracklistOverflow
    public var errorDescription: String? {
        switch self {
        case .overflow(let frames):
            "Recording could not keep up with audio (\(frames) lost frames). The incomplete AIFF was retained."
        case .empty: "No audio frames were recorded."
        case .sizeLimit: "Recording reached the AIFF file size limit. The incomplete file was retained."
        case .tracklistOverflow: "The tracklist exceeded its capacity. The incomplete AIFF was retained."
        }
    }
}

/// File, timer and counters belong to writerQueue. Call finish once per recording.
public final class SetRecorder: @unchecked Sendable {
    public let url: URL
    public var hasFailed: Bool { ring.hasFailed }
    private let partialURL: URL
    private let ring: RecordingBuffer
    private let writerQueue: DispatchQueue
    private var file: AIFFWriter?
    private var finished = false
    private let buffer: AVAudioPCMBuffer
    private var timer: DispatchSourceTimer?
    private var failure: Error?
    private var frames: Int64 = 0
    private let sampleRate: Double
    private var tracklist: [(UInt64, String)] = []
    private var trackMetadata: [String: (String, String)] = [:]

    public convenience init(directory: URL, sampleRate: Double, buffer ring: RecordingBuffer, location: String = "")
        throws
    {
        try self.init(
            directory: directory, sampleRate: sampleRate, buffer: ring, location: location,
            writerQueue: DispatchQueue(label: "org.generikdj.set-recording", qos: .utility))
    }
    init(directory: URL, sampleRate: Double, buffer ring: RecordingBuffer, location: String, writerQueue: DispatchQueue)
        throws
    {
        self.writerQueue = writerQueue
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let allowed = CharacterSet.controlCharacters.union(CharacterSet(charactersIn: "/:"))
        let cleaned = location.components(separatedBy: allowed).joined(separator: " ").trimmingCharacters(
            in: .whitespacesAndNewlines)
        var bounded = String.UnicodeScalarView()
        var locationBytes = 0
        var nonstarters = 0
        for scalar in cleaned.decomposedStringWithCanonicalMapping.prefix(100).unicodeScalars {
            if scalar.properties.canonicalCombiningClass.rawValue == 0 {
                nonstarters = 0
            } else {
                guard nonstarters < 30 else { continue }
                nonstarters += 1
            }
            let count = scalar.utf8.count
            guard locationBytes + count <= 180 else { break }
            bounded.append(scalar)
            locationBytes += count
        }
        let place = bounded.isEmpty ? "Unknown Location" : String(bounded).precomposedStringWithCanonicalMapping
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH-mm-ss"
        let name = "\(place) - \(formatter.string(from: Date())) - \(UUID().uuidString.prefix(8))"
        url = directory.appendingPathComponent(name + ".aiff")
        partialURL = directory.appendingPathComponent(name + ".incomplete.aiff")
        self.ring = ring
        self.sampleRate = sampleRate
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2),
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 8192)
        else { throw TransportError.allocation }
        self.buffer = buffer
        file = try AIFFWriter(url: partialURL, format: format)
        let timer = DispatchSource.makeTimerSource(queue: writerQueue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(20))
        timer.setEventHandler { [weak self] in self?.drain() }
        self.timer = timer
        ring.start()
        timer.resume()
    }
    deinit {
        timer?.cancel()
        if !finished { ring.stop() }
    }

    private func drain(finishing: Bool = false) {
        // Keep timer work bounded. A stopped producer leaves a finite final backlog.
        var batches = 0
        while finishing || batches < 64 {
            batches += 1
            let count = ring.read(into: buffer)
            guard count > 0 else { return }
            if failure == nil {
                do {
                    guard (frames + Int64(count)) * 6 < Int64(UInt32.max) - 4096 else { throw RecordingError.sizeLimit }
                    try file?.write(buffer)
                    frames += Int64(count)
                } catch {
                    failure = error
                    ring.stop()
                    ring.markWriteFailure()
                }
            }
        }
    }
    /// Close capture immediately. Finish before reusing the recording buffer.
    public func stopCapture() { ring.requestStop() }
    public func registerTrack(deck: UInt32, generation: UInt64, artist: String, title: String) {
        writerQueue.async { [self] in
            guard !finished else { return }
            trackMetadata["\(deck):\(generation)"] = (artist, title)
        }
    }
    private func trackLine(frame: UInt64, artist: String, title: String) -> String {
        let seconds = Int(Double(frame) / sampleRate)
        let cleanArtist = artist.components(separatedBy: .newlines).joined(separator: " ").trimmingCharacters(
            in: .whitespaces)
        let cleanTitle = title.components(separatedBy: .newlines).joined(separator: " ").trimmingCharacters(
            in: .whitespaces)
        return String(
            format: "%02d:%02d:%02d - %@ - %@", seconds / 3600, (seconds / 60) % 60, seconds % 60,
            cleanArtist.isEmpty ? "Unknown Artist" : cleanArtist, cleanTitle.isEmpty ? "Unknown Track" : cleanTitle)
    }
    public func finish() async throws -> URL { try await finish(onWriterEnqueued: {}) }
    func finish(onWriterEnqueued: @Sendable () -> Void) async throws -> URL {
        stopCapture()
        return try await withCheckedThrowingContinuation { continuation in
            writerQueue.async(qos: .utility, flags: .enforceQoS) { [self] in
                timer?.cancel()
                timer = nil
                // Join an accepted sample copy on the writer, before the final drain.
                ring.stop()
                drain(finishing: true)
                do { try file?.close() } catch { if failure == nil { failure = error } }
                file = nil
                finished = true
                do {
                    if let failure { throw failure }
                    if ring.droppedFrames > 0 { throw RecordingError.overflow(ring.droppedFrames) }
                    if tdj_recording_tracks_overflowed(ring.nativeAudioRenderPointer) {
                        throw RecordingError.tracklistOverflow
                    }
                    guard frames > 0 else {
                        try? FileManager.default.removeItem(at: partialURL)
                        throw RecordingError.empty
                    }
                    let tracklistURL = url.deletingPathExtension().appendingPathExtension("txt")
                    for index in 0..<tdj_recording_track_count(ring.nativeAudioRenderPointer) {
                        var event = tdj_recorded_track()
                        guard tdj_recording_track(ring.nativeAudioRenderPointer, index, &event) else { continue }
                        let metadata = trackMetadata["\(event.deck):\(event.generation)"] ?? ("", "")
                        tracklist.append(
                            (event.frame, trackLine(frame: event.frame, artist: metadata.0, title: metadata.1)))
                    }
                    tracklist.sort { $0.0 < $1.0 }
                    let text = tracklist.isEmpty ? "" : tracklist.map(\.1).joined(separator: "\n") + "\n"
                    try text.write(to: tracklistURL, atomically: true, encoding: .utf8)
                    do { try FileManager.default.moveItem(at: partialURL, to: url) } catch {
                        try? FileManager.default.removeItem(at: tracklistURL)
                        throw error
                    }
                    continuation.resume(returning: url)
                } catch { continuation.resume(throwing: error) }
            }
            onWriterEnqueued()
        }
    }
    public static func savedRecordings(in directory: URL) -> [URL] {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return recordingURLs(in: files)
    }
    public static func savedRecordingSnapshot(in directory: URL) -> (recordings: [URL], tracklists: [URL: URL]) {
        let files =
            (try? FileManager.default.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: [.isRegularFileKey])) ?? []
        let recordings = recordingURLs(in: files)
        let sidecarNames = Set(
            files.filter {
                $0.pathExtension == "txt"
                    && (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
            }.map(\.lastPathComponent))
        let tracklists = Dictionary(
            uniqueKeysWithValues: recordings.compactMap { audio -> (URL, URL)? in
                let sidecar = audio.deletingPathExtension().appendingPathExtension("txt")
                let regular =
                    sidecarNames.contains(sidecar.lastPathComponent)
                    || (try? sidecar.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
                return regular ? (audio, sidecar) : nil
            })
        return (recordings, tracklists)
    }
    private static func recordingURLs(in files: [URL]) -> [URL] {
        files.filter { $0.pathExtension == "aiff" && !$0.lastPathComponent.hasSuffix(".incomplete.aiff") }.sorted {
            $0.lastPathComponent > $1.lastPathComponent
        }
    }
}

// Explicit AIFF container selection avoids AVAudioFile's default AIFC container.
private final class AIFFWriter {
    private var file: ExtAudioFileRef?
    init(url: URL, format: AVAudioFormat) throws {
        var output = AudioStreamBasicDescription(
            mSampleRate: format.sampleRate, mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsBigEndian | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 6, mFramesPerPacket: 1, mBytesPerFrame: 6, mChannelsPerFrame: 2, mBitsPerChannel: 24,
            mReserved: 0)
        try check(ExtAudioFileCreateWithURL(url as CFURL, kAudioFileAIFFType, &output, nil, 0, &file))
        do {
            var client = format.streamDescription.pointee
            try check(
                ExtAudioFileSetProperty(
                    file!, kExtAudioFileProperty_ClientDataFormat,
                    UInt32(MemoryLayout<AudioStreamBasicDescription>.size), &client))
        } catch {
            if let file { ExtAudioFileDispose(file) }
            file = nil
            throw error
        }
    }
    deinit { if let file { ExtAudioFileDispose(file) } }
    func write(_ buffer: AVAudioPCMBuffer) throws {
        try check(ExtAudioFileWrite(file!, buffer.frameLength, buffer.audioBufferList))
    }
    func close() throws {
        guard let file else { return }
        self.file = nil
        try check(ExtAudioFileDispose(file))
    }
    private func check(_ status: OSStatus) throws {
        if status != noErr { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
    }
}
