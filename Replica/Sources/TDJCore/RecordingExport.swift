import AVFoundation
import AudioToolbox
import CLame
import Foundation

public enum RecordingExportFormat: String, CaseIterable, Identifiable, Sendable {
    case aiff, alac, mp3, m4a
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .aiff: "AIFF · Lossless"
        case .alac: "ALAC · Lossless"
        case .mp3: "MP3 · 320 kbps"
        case .m4a: "M4A · AAC 256 kbps"
        }
    }
    public var fileExtension: String { self == .alac ? "m4a" : rawValue }
}

public enum RecordingExportError: Error, LocalizedError {
    case performanceActive, invalidContainer, fileTooLarge
    case encoder(Int32)
    case missingArtwork, missingTracklist
    public var errorDescription: String? {
        switch self {
        case .performanceActive: "Export stopped to protect playback. End the performance, then export again."
        case .invalidContainer: "The recording format could not be read. The original recording is unchanged."
        case .fileTooLarge:
            "The AIFF export exceeds its size limit. Choose ALAC to keep lossless audio. The original recording is unchanged."
        case .encoder(let code): "Audio export failed (\(code)). The original recording is unchanged."
        case .missingArtwork: "The recording artwork could not be loaded. Try the export again."
        case .missingTracklist: "The saved tracklist could not be found. The original recording is unchanged."
        }
    }
}

public struct RecordingExportMetadata: Sendable {
    public var fields: [String: String]
    public var tracklist: String
    public var artwork: Data
    public init(fields: [String: String], tracklist: String, artwork: Data) {
        self.fields = fields
        self.tracklist = tracklist
        self.artwork = artwork
    }
    public static func read(recording: URL, tracklist: URL?, artwork: Data) async throws -> Self {
        guard !artwork.isEmpty else { throw RecordingExportError.missingArtwork }
        guard let tracklist else { throw RecordingExportError.missingTracklist }
        let text = try String(contentsOf: tracklist, encoding: .utf8)
        let asset = AVURLAsset(url: recording)
        var fields = ["title": recording.deletingPathExtension().lastPathComponent, "encoder": "GenErik DJ"]
        if let date = try recording.resourceValues(forKeys: [.creationDateKey]).creationDate {
            fields["date"] = date.ISO8601Format()
        }
        let common = try await asset.load(.commonMetadata)
        for item in common {
            guard let value = try await item.load(.stringValue), !value.isEmpty else { continue }
            switch item.commonKey {
            case .commonKeyTitle: fields["title"] = value
            case .commonKeyArtist: fields["artist"] = value
            case .commonKeyAlbumName: fields["album"] = value
            case .commonKeyDescription: fields["comment"] = value
            case .commonKeyCreationDate: fields["date"] = value
            default: break
            }
        }
        for format in try await asset.load(.availableMetadataFormats) {
            for item in try await asset.loadMetadata(for: format) {
                guard item.commonKey != .commonKeyArtwork,
                    let identifier = item.identifier?.rawValue,
                    let value = try await item.load(.stringValue), !value.isEmpty
                else { continue }
                fields[identifier] = value
            }
        }
        return Self(fields: fields, tracklist: text, artwork: artwork)
    }
}

public struct RecordingExportResult: Sendable {
    public let audio: URL
    public let tracklist: URL
    public var files: [URL] { [audio, tracklist] }
}

public enum RecordingExport {
    /// Call from a background task. Each audio batch checks cancellation and live playback.
    public static func run(
        source: URL, format: RecordingExportFormat, metadata: RecordingExportMetadata, directory: URL,
        shouldYield: @Sendable () -> Bool = { false }, progress: @Sendable (Double) -> Void = { _ in }
    ) throws -> RecordingExportResult {
        func checkpoint() throws {
            try Task.checkCancellation()
            if shouldYield() { throw RecordingExportError.performanceActive }
        }
        try checkpoint()
        guard !metadata.artwork.isEmpty else { throw RecordingExportError.missingArtwork }
        let folder = directory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var completed = false
        defer { if !completed { try? FileManager.default.removeItem(at: folder) } }
        let base = source.deletingPathExtension().lastPathComponent
        let audio = folder.appendingPathComponent(base).appendingPathExtension(format.fileExtension)
        let list = folder.appendingPathComponent(base).appendingPathExtension("txt")
        if format == .aiff {
            let input = try FileHandle(forReadingFrom: source)
            defer { try? input.close() }
            FileManager.default.createFile(atPath: audio.path, contents: nil)
            let output = try FileHandle(forWritingTo: audio)
            defer { try? output.close() }
            let total = try input.seekToEnd()
            try input.seek(toOffset: 0)
            let header = try input.read(upToCount: 12) ?? Data()
            guard header.prefix(4) == Data("FORM".utf8), header.suffix(4) == Data("AIFF".utf8) else {
                throw RecordingExportError.invalidContainer
            }
            try input.seek(toOffset: 0)
            var copied: UInt64 = 0
            while true {
                try checkpoint()
                let copiedBatch = try autoreleasepool {
                    guard let data = try input.read(upToCount: 256 * 1024), !data.isEmpty else { return false }
                    try output.write(contentsOf: data)
                    copied += UInt64(data.count)
                    progress(Double(copied) / Double(max(1, total)))
                    return true
                }
                if !copiedBatch { break }
            }
            try checkpoint()
            try RecordingExportTags.attachAIFF(audio, metadata: metadata)
        } else {
            try encode(
                source: source, destination: audio, format: format, metadata: metadata,
                checkpoint: checkpoint, progress: progress)
        }
        try checkpoint()
        try metadata.tracklist.write(to: list, atomically: true, encoding: .utf8)
        completed = true
        progress(1)
        return .init(audio: audio, tracklist: list)
    }

    private static func encode(
        source: URL, destination: URL, format: RecordingExportFormat,
        metadata: RecordingExportMetadata, checkpoint: () throws -> Void,
        progress: @Sendable (Double) -> Void
    ) throws {
        let input = try AVAudioFile(forReading: source)
        guard input.length > 0, input.processingFormat.channelCount == 2,
            let buffer = AVAudioPCMBuffer(pcmFormat: input.processingFormat, frameCapacity: 4096)
        else { throw RecordingExportError.invalidContainer }
        if format == .mp3 {
            try encodeMP3(
                input: input, buffer: buffer, destination: destination, metadata: metadata,
                checkpoint: checkpoint, progress: progress)
            return
        }
        var description = AudioStreamBasicDescription()
        description.mSampleRate = input.processingFormat.sampleRate
        description.mChannelsPerFrame = 2
        description.mFormatID = format == .alac ? kAudioFormatAppleLossless : kAudioFormatMPEG4AAC
        description.mFormatFlags = format == .alac ? kAppleLosslessFormatFlag_24BitSourceData : 0
        var size = UInt32(MemoryLayout.size(ofValue: description))
        try check(AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, nil, &size, &description))
        var output: ExtAudioFileRef?
        try check(ExtAudioFileCreateWithURL(destination as CFURL, kAudioFileM4AType, &description, nil, 0, &output))
        guard let output else { throw RecordingExportError.invalidContainer }
        var closed = false
        defer { if !closed { ExtAudioFileDispose(output) } }
        var client = input.processingFormat.streamDescription.pointee
        try check(
            ExtAudioFileSetProperty(
                output, kExtAudioFileProperty_ClientDataFormat,
                UInt32(MemoryLayout.size(ofValue: client)), &client))
        if format == .m4a {
            var converter: AudioConverterRef?
            var converterSize = UInt32(MemoryLayout.size(ofValue: converter))
            try check(ExtAudioFileGetProperty(output, kExtAudioFileProperty_AudioConverter, &converterSize, &converter))
            if let converter {
                var bitrate: UInt32 = 256_000
                try check(AudioConverterSetProperty(converter, kAudioConverterEncodeBitRate, 4, &bitrate))
            }
        }
        while input.framePosition < input.length {
            try checkpoint()
            try autoreleasepool {
                try input.read(into: buffer)
                try check(ExtAudioFileWrite(output, buffer.frameLength, buffer.audioBufferList))
                progress(Double(input.framePosition) / Double(input.length))
            }
        }
        try checkpoint()
        let status = ExtAudioFileDispose(output)
        closed = true
        try check(status)
        try checkpoint()
        try RecordingExportTags.attachM4A(destination, metadata: metadata)
    }

    private static func encodeMP3(
        input: AVAudioFile, buffer: AVAudioPCMBuffer, destination: URL,
        metadata: RecordingExportMetadata, checkpoint: () throws -> Void,
        progress: @Sendable (Double) -> Void
    ) throws {
        guard let encoder = lame_init() else { throw RecordingExportError.encoder(-1) }
        defer { lame_close(encoder) }
        try check(lame_set_in_samplerate(encoder, Int32(input.processingFormat.sampleRate)))
        try check(lame_set_num_channels(encoder, 2))
        try check(lame_set_brate(encoder, 320))
        try check(lame_set_quality(encoder, 2))
        try check(lame_set_debugf(encoder, nil))
        lame_set_write_id3tag_automatic(encoder, 0)
        try check(lame_set_bWriteVbrTag(encoder, 1))
        try check(lame_init_params(encoder))
        FileManager.default.createFile(atPath: destination.path, contents: nil)
        let output = try FileHandle(forWritingTo: destination)
        defer { try? output.close() }
        let tags = RecordingExportTags.id3(metadata)
        try output.write(contentsOf: tags)
        var encoded = [UInt8](repeating: 0, count: 16384)
        while input.framePosition < input.length {
            try checkpoint()
            try autoreleasepool {
                try input.read(into: buffer)
                guard let channels = buffer.floatChannelData else { throw RecordingExportError.invalidContainer }
                let count = lame_encode_buffer_ieee_float(
                    encoder, channels[0], channels[1], Int32(buffer.frameLength), &encoded, Int32(encoded.count))
                guard count >= 0 else { throw RecordingExportError.encoder(count) }
                try output.write(contentsOf: Data(encoded.prefix(Int(count))))
                progress(Double(input.framePosition) / Double(input.length))
            }
        }
        try checkpoint()
        let count = lame_encode_flush(encoder, &encoded, Int32(encoded.count))
        guard count >= 0 else { throw RecordingExportError.encoder(count) }
        try output.write(contentsOf: Data(encoded.prefix(Int(count))))
        // The LAME header records encoder delay and padding for gapless playback.
        let tagCount = lame_get_lametag_frame(encoder, &encoded, encoded.count)
        guard tagCount > 0, tagCount <= encoded.count else { throw RecordingExportError.invalidContainer }
        try output.seek(toOffset: UInt64(tags.count))
        try output.write(contentsOf: Data(encoded.prefix(tagCount)))
    }
    private static func check(_ status: Int32) throws {
        guard status == 0 else { throw RecordingExportError.encoder(status) }
    }
}
