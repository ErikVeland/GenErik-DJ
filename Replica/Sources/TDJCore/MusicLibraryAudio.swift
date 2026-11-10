import AVFoundation
import CoreMedia
import Foundation

/// Decodes library asset URLs to private lossless PCM without changing the system library.
public enum MusicLibraryAudio {
    // Metadata loading finishes before these handles reach the serial PCM worker.
    // The reader and its output are created and used only on that worker.
    private struct DecodeInput: @unchecked Sendable {
        let asset: AVAsset
        let track: AVAssetTrack
        let maximumSeconds: Double?
        let duration: Double?
    }
    private static let pcmWorker = AnalysisWorker(label: "org.generikdj.music-asset-decode")
    /// `maximumSeconds` limits the decode to the opening of the item, for first-minute analysis of mixes.
    public static func decodeAsset(url: URL, destination: URL, maximumSeconds: Double? = nil) async throws {
        let progress = AnalysisWorkProgress.observer
        let worker = Task.detached(priority: .background) {
            try await AnalysisWorkProgress.$observer.withValue(progress) {
                try await decode(url: url, destination: destination, maximumSeconds: maximumSeconds)
            }
        }
        try await withTaskCancellationHandler(operation: { try await worker.value }, onCancel: { worker.cancel() })
    }

    private static func decode(url: URL, destination: URL, maximumSeconds: Double?) async throws {
        try Task.checkCancellation()
        guard url.isFileURL || url.scheme?.lowercased() == "ipod-library" else { throw MusicLibraryError.missingAudio }
        guard !FileManager.default.fileExists(atPath: destination.path) else {
            throw MusicLibraryError.decoding("The preparation file already exists.")
        }
        let asset = AVURLAsset(url: url)
        guard try await !asset.load(.hasProtectedContent) else { throw MusicLibraryError.protected }
        guard let track = try await asset.loadTracks(withMediaType: .audio).first else {
            throw MusicLibraryError.missingAudio
        }
        let duration = AnalysisWorkProgress.observer == nil ? nil : (try? await asset.load(.duration).seconds)
        let input = DecodeInput(
            asset: asset, track: track, maximumSeconds: maximumSeconds,
            duration: duration.map { min($0, maximumSeconds ?? $0) })
        // The decoder checks cancellation before committing its file. A later
        // cancellation must not turn a committed output into an unowned failure.
        try await pcmWorker.run(checkAfterWork: false) { check in
            try decodePCM(input: input, destination: destination, checkCancellation: check)
        }
    }

    private static func decodePCM(input: DecodeInput, destination: URL, checkCancellation: @Sendable () throws -> Void)
        throws
    {
        try checkCancellation()
        guard !FileManager.default.fileExists(atPath: destination.path) else {
            throw MusicLibraryError.decoding("The preparation file already exists.")
        }
        let reader = try AVAssetReader(asset: input.asset)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM, AVLinearPCMBitDepthKey: 32, AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false, AVLinearPCMIsNonInterleaved: false,
        ]
        let output = AVAssetReaderTrackOutput(track: input.track, outputSettings: settings)
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { throw MusicLibraryError.decoding("The audio format is unsupported.") }
        reader.add(output)
        if let seconds = input.maximumSeconds, seconds.isFinite, seconds > 0 {
            reader.timeRange = CMTimeRange(start: .zero, duration: CMTime(seconds: seconds, preferredTimescale: 600))
        }
        guard reader.startReading() else { throw reader.error ?? MusicLibraryError.missingAudio }
        var completed = false
        defer {
            reader.cancelReading()
            if !completed { try? FileManager.default.removeItem(at: destination) }
        }
        var file: AVAudioFile?
        var written: Int64 = 0
        var progress = AnalysisWorkProgress.Step(0...0.20)
        while let sample = output.copyNextSampleBuffer() {
            try checkCancellation()
            try autoreleasepool {
                let count = CMSampleBufferGetNumSamples(sample)
                guard count > 0, count <= Int(Int32.max), let description = CMSampleBufferGetFormatDescription(sample),
                    let stream = CMAudioFormatDescriptionGetStreamBasicDescription(description),
                    let format = AVAudioFormat(
                        standardFormatWithSampleRate: stream.pointee.mSampleRate,
                        channels: stream.pointee.mChannelsPerFrame),
                    let interleaved = AVAudioFormat(
                        commonFormat: .pcmFormatFloat32, sampleRate: format.sampleRate, channels: format.channelCount,
                        interleaved: true),
                    let buffer = AVAudioPCMBuffer(pcmFormat: interleaved, frameCapacity: AVAudioFrameCount(count))
                else { throw MusicLibraryError.decoding("The decoded audio format is invalid.") }
                buffer.frameLength = AVAudioFrameCount(count)
                let status = CMSampleBufferCopyPCMDataIntoAudioBufferList(
                    sample, at: 0, frameCount: Int32(count), into: buffer.mutableAudioBufferList)
                guard status == noErr else {
                    throw MusicLibraryError.decoding("Cannot read decoded audio (\(status)).")
                }
                if file == nil {
                    try FileManager.default.createDirectory(
                        at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                    file = try AVAudioFile(
                        forWriting: destination, settings: interleaved.settings, commonFormat: .pcmFormatFloat32,
                        interleaved: true)
                }
                guard file?.processingFormat == interleaved else {
                    throw MusicLibraryError.decoding("The audio format changed during preparation.")
                }
                try file?.write(from: buffer)
                written += Int64(count)
                if let duration = input.duration, duration.isFinite, duration > 0 {
                    progress.advance(fraction: Double(written) / format.sampleRate / duration)
                }
            }
        }
        try checkCancellation()
        guard reader.status == .completed, written > 0 else { throw reader.error ?? MusicLibraryError.missingAudio }
        file = nil
        completed = true
    }
}
