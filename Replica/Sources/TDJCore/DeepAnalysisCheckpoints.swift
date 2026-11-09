import Foundation

struct DeepPredictionWindow: Codable, Equatable, Sendable {
    let index: Int
    let start: Int
    let beats: [Float]
    let downbeats: [Float]

    init(index: Int, start: Int, beats: [Float], downbeats: [Float]) {
        self.index = index
        self.start = start
        self.beats = beats
        self.downbeats = downbeats
    }

    private enum CodingKeys: String, CodingKey { case index, start, logits }

    func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(index, forKey: .index)
        try values.encode(start, forKey: .start)
        let bits = (beats + downbeats).map { $0.bitPattern.littleEndian }
        let bytes = bits.withUnsafeBufferPointer { Data(buffer: $0) }
        try values.encode(bytes, forKey: .logits)
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        index = try values.decode(Int.self, forKey: .index)
        start = try values.decode(Int.self, forKey: .start)
        let bytes = try values.decode(Data.self, forKey: .logits)
        guard bytes.count == 2 * BeatThisWindows.size * 4 else {
            throw CoreError.invalidAudio("The saved prediction window has invalid data.")
        }
        let logits = bytes.withUnsafeBytes { buffer in
            (0..<(2 * BeatThisWindows.size)).map {
                Float(bitPattern: UInt32(littleEndian: buffer.loadUnaligned(fromByteOffset: $0 * 4, as: UInt32.self)))
            }
        }
        beats = Array(logits.prefix(BeatThisWindows.size))
        downbeats = Array(logits.suffix(BeatThisWindows.size))
    }

    var valid: Bool {
        beats.count == BeatThisWindows.size && downbeats.count == BeatThisWindows.size
            && beats.allSatisfy(\.isFinite) && downbeats.allSatisfy(\.isFinite)
    }
}

/// Atomic, independently verified windows survive cancellation and incomplete final writes.
struct DeepAnalysisCheckpoints {
    let directory: URL
    let analysis: AudioAnalysis
    let profile: DeepAnalysisProfile
    let starts: [Int]

    private struct Envelope: Codable {
        let audio: AnalysisAudioIdentity
        let inferenceID: String
        let window: DeepPredictionWindow
        let digest: String
    }

    init(root: URL, analysis: AudioAnalysis, profile: DeepAnalysisProfile = .current) {
        self.analysis = analysis
        self.profile = profile
        starts = BeatThisWindows.starts(frameCount: BeatThisWindows.frameCount(analysis))
        directory = root.appendingPathComponent("DeepAnalysis")
            .appendingPathComponent(AnalysisAudioIdentity(analysis).key).appendingPathComponent(profile.inferenceID)
    }

    func read(_ index: Int) -> DeepPredictionWindow? {
        guard starts.indices.contains(index),
            let size = try? file(index).resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= 32 * 1024,
            let data = try? Data(contentsOf: file(index)), data.count <= 32 * 1024,
            let saved = try? JSONDecoder().decode(Envelope.self, from: data),
            saved.audio == AnalysisAudioIdentity(analysis), saved.inferenceID == profile.inferenceID,
            saved.window.index == index, saved.window.start == starts[index], saved.window.valid,
            let encoded = try? JSONEncoder.sorted.encode(saved.window), analysisDigest(encoded) == saved.digest
        else { return nil }
        return saved.window
    }

    func write(_ window: DeepPredictionWindow) throws {
        guard starts.indices.contains(window.index), window.start == starts[window.index], window.valid else {
            throw CoreError.invalidAudio("Cannot save an invalid deep-analysis window.")
        }
        let envelope = Envelope(
            audio: .init(analysis), inferenceID: profile.inferenceID, window: window,
            digest: analysisDigest(try JSONEncoder.sorted.encode(window)))
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder.sorted.encode(envelope).write(to: file(window.index), options: .atomic)
    }

    func result() -> DeepBeatAnalysis? {
        guard let data = try? Data(contentsOf: resultFile), data.count < 16384,
            let saved = try? JSONDecoder().decode(DeepBeatAnalysis.self, from: data), saved.profile == profile,
            (try? saved.validate(matching: analysis)) != nil
        else { return nil }
        return saved
    }

    func finish(_ result: DeepBeatAnalysis) throws {
        try result.validate(matching: analysis)
        guard result.profile == profile, starts.indices.allSatisfy({ read($0) != nil }) else {
            throw CoreError.invalidAudio("Deep analysis still has unfinished windows.")
        }
        try JSONEncoder.sorted.encode(result).write(to: resultFile, options: .atomic)
    }

    private func file(_ index: Int) -> URL { directory.appendingPathComponent("window-\(index).json") }
    private var resultFile: URL { directory.appendingPathComponent("result-policy\(profile.decisionPolicy).json") }
}
