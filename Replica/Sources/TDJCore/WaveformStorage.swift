import CryptoKit
import Foundation

/// Immutable per-track waveform payloads keep the library index small.
enum WaveformStorage {
    private static let magic = Data("TDJWFM01".utf8)
    private static let worker = AnalysisWorker()
    static func filename(_ analysis: AudioAnalysis) -> String {
        let configuration = SHA256.hash(data:Data(analysis.configurationID.utf8)).map { String(format:"%02x",$0) }.joined()
        return analysis.contentSHA256 + "-" + configuration + ".tdjwave"
    }
    static func validReference(_ analysis: AudioAnalysis) -> Bool {
        analysis.waveformReference.map { $0 == filename(analysis) } ?? true
    }
    static func metadata(_ snapshot: LibrarySnapshot, directory: URL) throws -> LibrarySnapshot {
        var result = snapshot
        for index in result.tracks.indices {
            let analysis = result.tracks[index].analysis
            guard !analysis.waveform.isEmpty else { continue }
            try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
            let name = filename(analysis)
            let url = directory.appendingPathComponent(name)
            if analysis.waveformReference == nil || !FileManager.default.fileExists(atPath:url.path) { try write(analysis,to:url) }
            var compact = analysis.replacingWaveform([])
            compact.waveformReference = name
            compact.cachedEnergyLevel = PerformerSuggestions.energyLevel(analysis)
            result.tracks[index].analysis = compact
        }
        return result
    }
    static func hydrate(_ track: Track, directory: URL) throws -> Track {
        guard track.analysis.waveform.isEmpty, let reference = track.analysis.waveformReference else { return track }
        guard track.id.count == 64, track.id.allSatisfy(\.isHexDigit), validReference(track.analysis) else {
            throw CoreError.invalidWorkspace("Invalid waveform reference. Original files were retained.")
        }
        var hydrated = track
        hydrated.analysis = track.analysis.replacingWaveform(try read(from:directory.appendingPathComponent(reference),analysis:track.analysis))
        return hydrated
    }
    static func hydrateAsync(_ track: Track, directory: URL) async throws -> Track {
        guard track.analysis.waveform.isEmpty, let reference = track.analysis.waveformReference else { return track }
        do {
            return try await worker.run { check in
                try check()
                return try hydrate(track,directory:directory)
            }
        } catch is CancellationError { throw CancellationError() }
        catch {
            guard validReference(track.analysis), track.id.count == 64, track.id.allSatisfy(\.isHexDigit),
                  track.mediaFilename == (track.mediaFilename as NSString).lastPathComponent,
                  track.mediaFilename != ".", track.mediaFilename != "..", !track.mediaFilename.isEmpty else { throw error }
            let source = directory.deletingLastPathComponent().appendingPathComponent("Media",isDirectory:true)
                .appendingPathComponent(track.mediaFilename)
            let rebuilt = try await AnalysisWorker.shared.rebuildWaveform(url: source, matching: track.analysis)
            let expected = track.analysis
            guard rebuilt.contentSHA256 == track.id, rebuilt.configurationID == expected.configurationID,
                  rebuilt.implementation == expected.implementation, rebuilt.sampleRate == expected.sampleRate,
                  rebuilt.frameCount == expected.frameCount, rebuilt.waveformFramesPerBin == expected.waveformFramesPerBin else {
                throw CoreError.invalidWorkspace("The waveform cache cannot be rebuilt with this analysis version. Original audio and preparation were retained.")
            }
            return try await worker.run { check in
                try check()
                try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
                try write(rebuilt,to:directory.appendingPathComponent(reference))
                var result = track
                result.analysis = expected.replacingWaveform(rebuilt.waveform)
                return result
            }
        }
    }
    private static func write(_ analysis: AudioAnalysis, to url: URL) throws {
        var data = magic
        func append(_ value: UInt64) { var word=value.littleEndian; withUnsafeBytes(of:&word) { data.append(contentsOf:$0) } }
        append(analysis.sampleRate.bitPattern)
        append(UInt64(analysis.frameCount))
        append(UInt64(analysis.waveformFramesPerBin))
        append(UInt64(analysis.waveform.count))
        var words: [UInt32] = []
        words.reserveCapacity(analysis.waveform.count*3)
        for bin in analysis.waveform {
            words.append(bin.minimum.bitPattern.littleEndian)
            words.append(bin.maximum.bitPattern.littleEndian)
            words.append(bin.rms.bitPattern.littleEndian)
        }
        words.withUnsafeBytes { data.append(contentsOf:$0) }
        data.append(contentsOf:SHA256.hash(data:data))
        try data.write(to:url,options:.atomic)
    }
    private static func read(from url: URL, analysis: AudioAnalysis) throws -> [WaveformBin] {
        let data: Data
        do { data = try Data(contentsOf:url) }
        catch { throw CoreError.invalidWorkspace("Cannot read waveform data for this track: \(error.localizedDescription)") }
        func invalid() -> CoreError { .invalidWorkspace("Waveform data is damaged or does not match the track. Original audio was retained.") }
        guard data.count >= 72, data.prefix(8) == magic else { throw invalid() }
        func word(_ offset: Int) -> UInt64 { data.withUnsafeBytes { UInt64(littleEndian:$0.loadUnaligned(fromByteOffset:offset,as:UInt64.self)) } }
        let count = word(32)
        guard analysis.frameCount > 0, analysis.waveformFramesPerBin > 0,
              word(8) == analysis.sampleRate.bitPattern, word(16) == UInt64(analysis.frameCount),
              word(24) == UInt64(analysis.waveformFramesPerBin), count <= UInt64((Int.max-72)/12),
              data.count == 72+Int(count)*12,
              count == (UInt64(analysis.frameCount)+UInt64(analysis.waveformFramesPerBin)-1)/UInt64(analysis.waveformFramesPerBin),
              data.suffix(32).elementsEqual(SHA256.hash(data:data.prefix(data.count-32))) else { throw invalid() }
        var result: [WaveformBin] = []
        result.reserveCapacity(Int(count))
        try data.withUnsafeBytes { raw in
            for index in 0..<Int(count) {
                let offset = 40+index*12
                func sample(_ delta: Int) -> Float {
                    Float(bitPattern:UInt32(littleEndian:raw.loadUnaligned(fromByteOffset:offset+delta,as:UInt32.self)))
                }
                let low=sample(0), high=sample(4), rms=sample(8)
                guard low.isFinite, high.isFinite, rms.isFinite else { throw invalid() }
                result.append(.init(minimum:low,maximum:high,rms:rms))
            }
        }
        return result
    }
}

extension WorkspaceStore {
    public var waveformDirectory: URL { root.appendingPathComponent("Waveforms",isDirectory:true) }
    public func hydrate(_ track: Track) throws -> Track { try WaveformStorage.hydrate(track,directory:waveformDirectory) }
    public func hydrateAsync(_ track: Track) async throws -> Track { try await WaveformStorage.hydrateAsync(track,directory:waveformDirectory) }
}
