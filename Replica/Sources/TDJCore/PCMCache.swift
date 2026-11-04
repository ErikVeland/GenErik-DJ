import AVFoundation
import Foundation

/// Streams a private playback cache. Original media and NI exports are never rewritten.
public enum PCMCache {
    private static let worker = AnalysisWorker()

    /// Deck loading has its own serial background queue; it never waits for analysis.
    public static func prepareAsync(
        track: Track, store: WorkspaceStore, streamed: Bool = false, outputSampleRate: Double = 48000,
        maximumOutputFrames: UInt32 = 4096, sourceURL: URL? = nil
    ) async throws -> PCMAsset {
        for attempt in 0..<40 {
            do {
                return try await worker.run { check in
                    try prepare(
                        track: track, store: store, streamed: streamed, outputSampleRate: outputSampleRate,
                        maximumOutputFrames: maximumOutputFrames, sourceURL: sourceURL, checkCancellation: check)
                }
            } catch PCMStreamingError.capacity where streamed && attempt < 39 {
                try Task.checkCancellation()
                try await Task.sleep(for: .milliseconds(50))
            }
        }
        throw PCMStreamingError.capacity
    }

    public static func prepare(
        track: Track, store: WorkspaceStore, streamed: Bool = false, outputSampleRate: Double = 48000,
        maximumOutputFrames: UInt32 = 4096, sourceURL: URL? = nil,
        checkCancellation: @Sendable () throws -> Void = { try Task.checkCancellation() }
    ) throws -> PCMAsset {
        try checkCancellation()
        let directory = store.root.appendingPathComponent("PlaybackCache", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let frames = track.analysis.frameCount
        guard frames > 0, frames <= Int64.max / 8 else { throw TransportError.invalid }
        if let sourceURL {
            try verifyNativeSource(
                sourceURL, identity: track.analysis.contentSHA256, checkCancellation: checkCancellation)
        }
        let cache = directory.appendingPathComponent(track.id + "-stereo-f32-v1.pcm")
        let expectedBytes = frames * 8
        if let size = try? cache.resourceValues(forKeys: [.fileSizeKey]).fileSize, Int64(size) == expectedBytes {
            return try asset(
                cache: cache, frames: UInt64(frames), sampleRate: track.analysis.sampleRate, streamed: streamed,
                outputSampleRate: outputSampleRate, maximumOutputFrames: maximumOutputFrames)
        }
        let source = sourceURL ?? store.mediaDirectory.appendingPathComponent(track.mediaFilename)
        if streamed {
            let decoder = try DecodedAudioSource.file(url: source)
            guard decoder.frames == frames, decoder.rate == track.analysis.sampleRate else {
                throw TransportError.nativeSourceChanged
            }
            return try PCMAsset(
                decoder: decoder, outputSampleRate: outputSampleRate, maximumOutputFrames: maximumOutputFrames)
        }
        let file = try AVAudioFile(forReading: source, commonFormat: .pcmFormatFloat32, interleaved: false)
        guard file.processingFormat.sampleRate == track.analysis.sampleRate, file.length == frames,
            file.processingFormat.channelCount > 0, file.processingFormat.channelCount <= 2,
            let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 32768)
        else { throw TransportError.cache("This decoder format needs a reference-compatible mapping.") }
        let temporary = directory.appendingPathComponent(UUID().uuidString + ".partial")
        guard FileManager.default.createFile(atPath: temporary.path, contents: nil) else {
            throw TransportError.allocation
        }
        defer { try? FileManager.default.removeItem(at: temporary) }
        let handle = try FileHandle(forWritingTo: temporary)
        defer { try? handle.close() }
        var interleaved = [Float](repeating: 0, count: 32768 * 2)
        var position: Int64 = 0
        while position < frames {
            try checkCancellation()
            try file.read(into: buffer, frameCount: AVAudioFrameCount(min(32768, frames - position)))
            let count = Int(buffer.frameLength)
            guard count > 0, let channels = buffer.floatChannelData else {
                throw TransportError.cache("Unexpected decoder end.")
            }
            let right = file.processingFormat.channelCount == 2 ? 1 : 0
            for frame in 0..<count {
                let l = channels[0][frame]
                let r = channels[right][frame]
                guard l.isFinite, r.isFinite else { throw TransportError.cache("Non-finite PCM data.") }
                interleaved[2 * frame] = l
                interleaved[2 * frame + 1] = r
            }
            try interleaved.withUnsafeBytes {
                try handle.write(contentsOf: $0.prefix(count * 2 * MemoryLayout<Float>.size))
            }
            position += Int64(count)
        }
        try handle.synchronize()
        try handle.close()
        if let sourceURL {
            try verifyNativeSource(
                sourceURL, identity: track.analysis.contentSHA256, checkCancellation: checkCancellation)
        }
        if FileManager.default.fileExists(atPath: cache.path) {
            // Only a cache owned by this build is replaceable.
            _ = try FileManager.default.replaceItemAt(cache, withItemAt: temporary)
        } else {
            try FileManager.default.moveItem(at: temporary, to: cache)
        }
        return try asset(
            cache: cache, frames: UInt64(frames), sampleRate: track.analysis.sampleRate, streamed: streamed,
            outputSampleRate: outputSampleRate, maximumOutputFrames: maximumOutputFrames)
    }
    private static func verifyNativeSource(
        _ source: URL, identity: String, checkCancellation: @Sendable () throws -> Void
    ) throws {
        guard try AudioAnalyzer.sha256(url: source, checkCancellation: checkCancellation) == identity else {
            throw TransportError.nativeSourceChanged
        }
    }
    private static func asset(
        cache: URL, frames: UInt64, sampleRate: Double, streamed: Bool, outputSampleRate: Double,
        maximumOutputFrames: UInt32
    ) throws -> PCMAsset {
        if streamed {
            return try PCMAsset(
                streamedFile: cache, frames: frames, sampleRate: sampleRate, outputSampleRate: outputSampleRate,
                maximumOutputFrames: maximumOutputFrames)
        }
        return try PCMAsset(mappedFile: cache, frames: frames, sampleRate: sampleRate)
    }
}
