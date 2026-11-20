import AVFoundation
import Foundation
import Testing

@testable import TDJCore

@Suite struct RecordingExportTests {
    let tracklist = "00:00:00 - Björk - Jóga\n00:00:01 - Underworld - Born Slippy\n"
    func fixture(_ folder: URL) throws -> URL {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("Test set.aiff")
        let format = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2)!
        var description = AudioStreamBasicDescription(
            mSampleRate: 48000, mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsBigEndian | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 6, mFramesPerPacket: 1, mBytesPerFrame: 6, mChannelsPerFrame: 2, mBitsPerChannel: 24,
            mReserved: 0)
        var output: ExtAudioFileRef?
        #expect(ExtAudioFileCreateWithURL(url as CFURL, kAudioFileAIFFType, &description, nil, 0, &output) == 0)
        let file = try #require(output)
        defer { ExtAudioFileDispose(file) }
        var client = format.streamDescription.pointee
        #expect(
            ExtAudioFileSetProperty(
                file, kExtAudioFileProperty_ClientDataFormat, UInt32(MemoryLayout.size(ofValue: client)), &client) == 0)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 96000)!
        buffer.frameLength = 96000
        for i in 0..<96000 {
            let value = Float(sin(Double(i) * 2 * .pi * 440 / 48000)) * 0.4
            buffer.floatChannelData![0][i] = value
            buffer.floatChannelData![1][i] = -value
        }
        #expect(ExtAudioFileWrite(file, buffer.frameLength, buffer.audioBufferList) == 0)
        return url
    }
    func metadata() -> RecordingExportMetadata {
        let root = URL(fileURLWithPath: #filePath).resolvingSymlinksInPath().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let logo = root.appendingPathComponent("Sources/TDJInterface/Resources/HeaderArtwork/GenErikHeaderMark.png")
        return .init(
            fields: [
                "title": "Live at café", "artist": "GenErik", "album": "Test sets", "genre": "Electronic",
                "comment": "Brisbane", "date": "2026-11-20", "custom venue": "Café",
            ], tracklist: tracklist, artwork: try! Data(contentsOf: logo))
    }
    @Test(arguments: RecordingExportFormat.allCases)
    func audioTagsAndSidecar(_ format: RecordingExportFormat) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("r510-\(format.rawValue)-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let source = try fixture(root)
        let original = try Data(contentsOf: source)
        let tags = metadata()
        let result = try RecordingExport.run(source: source, format: format, metadata: tags, directory: root)
        #expect(try Data(contentsOf: source) == original)
        #expect(try String(contentsOf: result.tracklist, encoding: .utf8) == tracklist)
        let output = try AVAudioFile(forReading: result.audio)
        #expect(abs(Double(output.length) / output.processingFormat.sampleRate - 2) < 0.05)
        let asset = AVURLAsset(url: result.audio)
        let common = try await asset.load(.commonMetadata)
        var title: String?
        var artwork: Data?
        for item in common {
            if item.commonKey == .commonKeyTitle { title = try await item.load(.stringValue) }
            if item.commonKey == .commonKeyArtwork { artwork = try await item.load(.dataValue) }
        }
        #expect(title == "Live at café")
        #expect(artwork == tags.artwork)
        var lyrics: String?
        for metadataFormat in try await asset.load(.availableMetadataFormats) {
            for item in try await asset.loadMetadata(for: metadataFormat) {
                if item.identifier == .id3MetadataUnsynchronizedLyric || item.identifier == .iTunesMetadataLyrics {
                    lyrics = try await item.load(.stringValue)
                }
            }
        }
        #expect(lyrics == tracklist)
        if format == .aiff || format == .alac {
            let input = try AVAudioFile(forReading: source)
            #expect(output.length == input.length)
            let a = AVAudioPCMBuffer(pcmFormat: input.processingFormat, frameCapacity: UInt32(input.length))!
            let b = AVAudioPCMBuffer(pcmFormat: output.processingFormat, frameCapacity: UInt32(output.length))!
            try input.read(into: a)
            try output.read(into: b)
            for channel in 0..<2 {
                #expect(
                    Array(UnsafeBufferPointer(start: a.floatChannelData![channel], count: Int(a.frameLength)))
                        == Array(UnsafeBufferPointer(start: b.floatChannelData![channel], count: Int(b.frameLength))))
            }
        }
        // Retain a small output set for independent codec and tag checks.
        guard let evidenceRoot = ProcessInfo.processInfo.environment["GENERIK_EXPORT_EVIDENCE"] else { return }
        let evidence = URL(fileURLWithPath: evidenceRoot).appendingPathComponent(format.rawValue)
        try FileManager.default.createDirectory(at: evidence, withIntermediateDirectories: true)
        for url in result.files {
            let dest = evidence.appendingPathComponent(url.lastPathComponent)
            try? FileManager.default.removeItem(at: dest)
            try FileManager.default.copyItem(at: url, to: dest)
        }
    }
    @Test func performanceProtectionRetainsSource() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = try fixture(root)
        let original = try Data(contentsOf: source)
        #expect(throws: RecordingExportError.self) {
            try RecordingExport.run(
                source: source, format: .mp3, metadata: metadata(), directory: root, shouldYield: { true })
        }
        #expect(try Data(contentsOf: source) == original)
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).count == 1)
    }
    @Test(arguments: RecordingExportFormat.allCases)
    func interruptionRemovesPartialExport(_ format: RecordingExportFormat) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = try fixture(root)
        let original = try Data(contentsOf: source)
        let admission = ExportAdmission()
        #expect(throws: RecordingExportError.self) {
            try RecordingExport.run(
                source: source, format: format, metadata: metadata(), directory: root,
                shouldYield: { admission.mustStop() })
        }
        #expect(try Data(contentsOf: source) == original)
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path) == [source.lastPathComponent])
    }
    @Test func cancelledExportDoesNotPublishFiles() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = try fixture(root)
        let tags = metadata()
        let task = Task {
            while !Task.isCancelled { await Task.yield() }
            return try RecordingExport.run(source: source, format: .alac, metadata: tags, directory: root)
        }
        task.cancel()
        do {
            _ = try await task.value
            Issue.record("Cancelled export succeeded")
        } catch is CancellationError {}
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path) == [source.lastPathComponent])
    }
    @Test func oversizedAIFFRejectsTagsWithoutChangingAudio() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".aiff")
        defer { try? FileManager.default.removeItem(at: url) }
        FileManager.default.createFile(atPath: url.path, contents: Data("FORM".utf8))
        let file = try FileHandle(forWritingTo: url)
        defer { try? file.close() }
        let size = UInt64(UInt32.max) - 4096
        try file.truncate(atOffset: size)
        #expect(throws: RecordingExportError.self) { try RecordingExportTags.attachAIFF(url, metadata: metadata()) }
        #expect(try file.seekToEnd() == size)
    }

    @Test func taggedRecordingMetadataSurvivesAnotherExport() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = try fixture(root)
        let tags = metadata()
        let first = try RecordingExport.run(source: source, format: .aiff, metadata: tags, directory: root)
        let loaded = try await RecordingExportMetadata.read(
            recording: first.audio, tracklist: first.tracklist, artwork: tags.artwork)
        #expect(loaded.fields["title"] == tags.fields["title"])
        #expect(loaded.fields["artist"] == tags.fields["artist"])
        #expect(loaded.fields["album"] == tags.fields["album"])
        #expect(loaded.tracklist == tags.tracklist)
        let result = try RecordingExport.run(source: first.audio, format: .alac, metadata: loaded, directory: root)
        #expect(try String(contentsOf: result.tracklist, encoding: .utf8) == tracklist)
    }

}

private final class ExportAdmission: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    func mustStop() -> Bool {
        lock.withLock {
            count += 1
            return count >= 3
        }
    }
}
