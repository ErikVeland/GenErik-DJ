import AVFoundation
import CTDJTransport
import CoreMedia
import CryptoKit
import Foundation

private final class DecodedSourceLease: @unchecked Sendable {
    let close: @Sendable () -> Void
    init(_ close: @escaping @Sendable () -> Void) { self.close = close }
    deinit { close() }
}

private final class DecoderInput: @unchecked Sendable {
    let url: URL
    let asset: AVURLAsset?
    let track: AVAssetTrack?
    let rate: Double
    let frames: Int64
    let channels: Int
    let lease: DecodedSourceLease
    init(
        url: URL, asset: AVURLAsset? = nil, track: AVAssetTrack? = nil, rate: Double, frames: Int64, channels: Int,
        lease: DecodedSourceLease
    ) {
        self.url = url
        self.asset = asset
        self.track = track
        self.rate = rate
        self.frames = frames
        self.channels = channels
        self.lease = lease
    }
}

/// Only the opening producer and then one serial read-ahead worker use a decoder.
final class DecodedAudioSource: @unchecked Sendable {
    private let input: DecoderInput
    private var file: AVAudioFile?
    private var reader: AVAssetReader?
    private var output: AVAssetReaderTrackOutput?
    private var pending = [Float]()
    private var pendingOffset = 0
    private var position: Int64 = -1
    var rate: Double { input.rate }
    var frames: Int64 { input.frames }
    var channels: Int { input.channels }

    private init(input: DecoderInput) throws {
        self.input = input
        if input.asset == nil {
            file = try AVAudioFile(forReading: input.url, commonFormat: .pcmFormatFloat32, interleaved: false)
        }
    }
    static func file(url: URL) throws -> DecodedAudioSource {
        let file = try AVAudioFile(forReading: url, commonFormat: .pcmFormatFloat32, interleaved: false)
        return try DecodedAudioSource(
            input: DecoderInput(
                url: url, rate: file.processingFormat.sampleRate, frames: file.length,
                channels: Int(file.processingFormat.channelCount), lease: DecodedSourceLease({})))
    }
    static func open(url: URL, cleanup: @escaping @Sendable () -> Void) async throws -> DecodedAudioSource {
        let lease = DecodedSourceLease(cleanup)
        if url.isFileURL {
            let file = try AVAudioFile(forReading: url, commonFormat: .pcmFormatFloat32, interleaved: false)
            return try DecodedAudioSource(
                input: DecoderInput(
                    url: url, rate: file.processingFormat.sampleRate, frames: file.length,
                    channels: Int(file.processingFormat.channelCount), lease: lease))
        }
        guard url.scheme?.lowercased() == "ipod-library" else { throw MusicLibraryError.missingAudio }
        return try await asset(url: url, lease: lease)
    }
    static func asset(url: URL, cleanup: @escaping @Sendable () -> Void = {}) async throws -> DecodedAudioSource {
        try await asset(url: url, lease: DecodedSourceLease(cleanup))
    }
    private static func asset(url: URL, lease: DecodedSourceLease) async throws -> DecodedAudioSource {
        let asset = AVURLAsset(url: url)
        guard try await !asset.load(.hasProtectedContent) else { throw MusicLibraryError.protected }
        guard let track = try await asset.loadTracks(withMediaType: .audio).first,
            let format = try await track.load(.formatDescriptions).first,
            let description = CMAudioFormatDescriptionGetStreamBasicDescription(format)
        else { throw MusicLibraryError.missingAudio }
        let rate = description.pointee.mSampleRate
        let channels = Int(description.pointee.mChannelsPerFrame)
        let duration = try await track.load(.timeRange).duration.seconds
        guard rate.isFinite, rate > 0, duration.isFinite, duration > 0, duration * rate < Double(Int64.max / 8) else {
            throw PCMStreamingError.invalid
        }
        return try DecodedAudioSource(
            input: DecoderInput(
                url: url, asset: asset, track: track, rate: rate, frames: Int64((duration * rate).rounded()),
                channels: channels, lease: lease))
    }
    private func reset(to first: Int64) throws {
        pending.removeAll(keepingCapacity: true)
        pendingOffset = 0
        reader?.cancelReading()
        reader = nil
        output = nil
        guard let asset = input.asset, let track = input.track else { throw PCMStreamingError.invalid }
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(
            track: track,
            outputSettings: [
                AVFormatIDKey: kAudioFormatLinearPCM, AVLinearPCMBitDepthKey: 32, AVLinearPCMIsFloatKey: true,
                AVLinearPCMIsBigEndianKey: false, AVLinearPCMIsNonInterleaved: false,
            ])
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { throw PCMStreamingError.unsupported }
        reader.add(output)
        reader.timeRange = CMTimeRange(
            start: CMTime(value: first, timescale: Int32(rate.rounded())),
            duration: CMTime(value: frames - first, timescale: Int32(rate.rounded())))
        guard reader.startReading() else { throw reader.error ?? PCMStreamingError.readFailed }
        self.reader = reader
        self.output = output
        position = first
    }
    func read(first: Int64, count: Int, into stereo: UnsafeMutablePointer<Float>) throws {
        guard first >= 0, count > 0, count <= 32768, first <= frames - Int64(count), (1...2).contains(channels) else {
            throw PCMStreamingError.invalid
        }
        if let file {
            if file.framePosition != first { file.framePosition = first }
            guard
                let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(count))
            else { throw TransportError.allocation }
            try file.read(into: buffer, frameCount: AVAudioFrameCount(count))
            guard Int(buffer.frameLength) == count, let data = buffer.floatChannelData else {
                throw PCMStreamingError.readFailed
            }
            for n in 0..<count {
                stereo[2 * n] = data[0][n]
                stereo[2 * n + 1] = data[channels == 1 ? 0 : 1][n]
            }
        } else {
            if position != first { try reset(to: first) }
            var copied = 0
            while copied < count {
                if pendingOffset >= pending.count {
                    guard let sample = output?.copyNextSampleBuffer() else {
                        if reader?.status == .completed, first + Int64(copied) >= frames - 4096 {
                            stereo.advanced(by: copied * 2).update(repeating: 0, count: (count - copied) * 2)
                            position = first + Int64(count)
                            return
                        }
                        throw reader?.error ?? PCMStreamingError.readFailed
                    }
                    try autoreleasepool {
                        let length = CMSampleBufferGetNumSamples(sample)
                        guard length > 0, length <= 32768,
                            let format = AVAudioFormat(
                                commonFormat: .pcmFormatFloat32, sampleRate: rate,
                                channels: AVAudioChannelCount(channels), interleaved: true),
                            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(length))
                        else { throw PCMStreamingError.invalid }
                        buffer.frameLength = AVAudioFrameCount(length)
                        guard
                            CMSampleBufferCopyPCMDataIntoAudioBufferList(
                                sample, at: 0, frameCount: Int32(length), into: buffer.mutableAudioBufferList) == noErr
                        else { throw PCMStreamingError.readFailed }
                        let data = buffer.floatChannelData![0]
                        pending = [Float](repeating: 0, count: length * 2)
                        for n in 0..<length {
                            pending[2 * n] = data[n * channels]
                            pending[2 * n + 1] = data[n * channels + (channels == 1 ? 0 : 1)]
                        }
                        pendingOffset = 0
                    }
                }
                let available = min(count - copied, (pending.count - pendingOffset) / 2)
                pending.withUnsafeBufferPointer { buffer in
                    stereo.advanced(by: copied * 2).update(
                        from: buffer.baseAddress!.advanced(by: pendingOffset), count: available * 2)
                }
                copied += available
                pendingOffset += available * 2
                position += Int64(available)
            }
        }
        for n in 0..<count * 2 where !stereo[n].isFinite { throw PCMStreamingError.readFailed }
    }
    func duplicate() throws -> DecodedAudioSource { try DecodedAudioSource(input: input) }
    deinit { reader?.cancelReading() }
}

public struct NativePlaybackOpening: Sendable {
    private let decoder: DecodedAudioSource
    public let analysis: AudioAnalysis
    public static func open(url: URL, sourceIdentity: String, cleanup: @escaping @Sendable () -> Void = {}) async throws
        -> Self
    {
        let decoder = try await DecodedAudioSource.open(url: url, cleanup: cleanup)
        let worker = Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            guard decoder.frames > 0, decoder.rate >= 8000, decoder.rate <= 384000, (1...2).contains(decoder.channels)
            else { throw PCMStreamingError.unsupported }
            let count = min(decoder.frames, min(32768, Int64(decoder.rate / 2)))
            var data = [Float](repeating: 0, count: Int(count) * 2)
            try data.withUnsafeMutableBufferPointer {
                try decoder.read(first: 0, count: Int(count), into: $0.baseAddress!)
            }
            let stamp =
                url.isFileURL ? try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]) : nil
            let revision =
                sourceIdentity + "|" + url.absoluteString
                + "|\(decoder.rate)|\(decoder.frames)|\(stamp?.fileSize ?? 0)|\(stamp?.contentModificationDate?.timeIntervalSince1970 ?? 0)"
            let identity = SHA256.hash(data: Data(revision.utf8)).map { String(format: "%02x", $0) }.joined()
            let binFrames = max(1, Int((decoder.rate / 100).rounded()))
            let bins = waveformBins(data, binFrames: binFrames)
            var analysis = AudioAnalysis(
                implementation: "Native playback identity; full content analysis is pending.",
                configurationID: "native-opening-1", contentSHA256: identity, sampleRate: decoder.rate,
                frameCount: decoder.frames, channelCount: decoder.channels, waveformFramesPerBin: binFrames,
                waveform: bins, bpm: nil, beatAnchorFrame: nil, tempoConfidence: 0, key: nil, keyConfidence: 0,
                chroma: [], timbre: [])
            analysis.musicalAnalysisDeferred = true
            analysis.waveformDecodedFrames = count
            return Self(decoder: decoder, analysis: analysis)
        }
        return try await withTaskCancellationHandler {
            try await worker.value
        } onCancel: {
            worker.cancel()
        }
    }
    public func asset(outputSampleRate: Double = 48000, maximumOutputFrames: UInt32 = 4096) throws -> PCMAsset {
        try PCMAsset(decoder: decoder, outputSampleRate: outputSampleRate, maximumOutputFrames: maximumOutputFrames)
    }
    public func waveform(
        cache: URL, matching initial: AudioAnalysis, progress: @escaping @Sendable (AudioAnalysis) -> Void
    ) async throws -> AudioAnalysis {
        let worker = Task.detached(priority: .background) {
            let source = try decoder.duplicate()
            try FileManager.default.createDirectory(
                at: cache.deletingLastPathComponent(), withIntermediateDirectories: true)
            let temporary = cache.deletingLastPathComponent().appendingPathComponent(UUID().uuidString + ".partial")
            FileManager.default.createFile(atPath: temporary.path, contents: nil)
            defer { try? FileManager.default.removeItem(at: temporary) }
            let handle = try FileHandle(forWritingTo: temporary)
            defer { try? handle.close() }
            let bin = initial.waveformFramesPerBin
            let chunk = max(bin, (16384 / bin) * bin)
            var position: Int64 = 0
            var bins = [WaveformBin]()
            var lastReport = Date.distantPast
            while position < source.frames {
                try Task.checkCancellation()
                let count = Int(min(Int64(chunk), source.frames - position))
                var data = [Float](repeating: 0, count: count * 2)
                try data.withUnsafeMutableBufferPointer {
                    try source.read(first: position, count: count, into: $0.baseAddress!)
                }
                bins.append(contentsOf: waveformBins(data, binFrames: bin))
                try data.withUnsafeBytes { try handle.write(contentsOf: $0) }
                position += Int64(count)
                if Date().timeIntervalSince(lastReport) >= 0.1 {
                    var value = initial.replacingWaveform(bins)
                    value.waveformDecodedFrames = position
                    progress(value)
                    lastReport = Date()
                }
                try await Task.sleep(for: .milliseconds(1))
            }
            try Task.checkCancellation()
            try handle.close()
            if FileManager.default.fileExists(atPath: cache.path) {
                _ = try FileManager.default.replaceItemAt(cache, withItemAt: temporary)
            } else {
                try FileManager.default.moveItem(at: temporary, to: cache)
            }
            return initial.replacingWaveform(
                bins, configurationID: initial.configurationID + "-waveform", frameCount: source.frames,
                decodedFrames: nil)
        }
        return try await withTaskCancellationHandler {
            try await worker.value
        } onCancel: {
            worker.cancel()
        }
    }
}

private func waveformBins(_ data: [Float], binFrames: Int) -> [WaveformBin] {
    let frames = data.count / 2
    var result = [WaveformBin]()
    for first in stride(from: 0, to: frames, by: binFrames) {
        let end = min(frames, first + binFrames)
        var low: Float = 0
        var high: Float = 0
        var power = 0.0
        for n in first..<end {
            let left = data[n * 2]
            let right = data[n * 2 + 1]
            low = min(low, left, right)
            high = max(high, left, right)
            power += (Double(left) * Double(left) + Double(right) * Double(right)) * 0.5
        }
        result.append(WaveformBin(minimum: low, maximum: high, rms: Float(sqrt(power / Double(end - first)))))
    }
    return result
}

extension PCMAsset {
    convenience init(decoder: DecodedAudioSource, outputSampleRate: Double, maximumOutputFrames: UInt32) throws {
        var config = tdj_stream_config()
        config.output_rate = outputSampleRate
        config.forward_seconds = 2
        config.backward_seconds = 1
        config.max_output_frames = maximumOutputFrames
        let ownership = Unmanaged.passRetained(decoder)
        var status = Int32(TDJ_STREAM_INVALID.rawValue)
        let pointer = tdj_asset_open_decoder(
            UInt64(decoder.frames), decoder.rate, &config,
            { context, first, count, stereo in
                guard let context, let stereo else { return Int32(TDJ_STREAM_INVALID.rawValue) }
                do {
                    try Unmanaged<DecodedAudioSource>.fromOpaque(context).takeUnretainedValue().read(
                        first: Int64(first), count: Int(count), into: stereo)
                    return Int32(TDJ_STREAM_READY.rawValue)
                } catch { return Int32(TDJ_STREAM_IO_ERROR.rawValue) }
            }, { context in if let context { Unmanaged<DecodedAudioSource>.fromOpaque(context).release() } },
            ownership.toOpaque(), &status)
        guard let pointer else {
            ownership.release()
            try PCMStreamingError.check(status)
            throw TransportError.allocation
        }
        self.init(streamPointer: pointer, frames: UInt64(decoder.frames), sampleRate: decoder.rate)
    }
}
