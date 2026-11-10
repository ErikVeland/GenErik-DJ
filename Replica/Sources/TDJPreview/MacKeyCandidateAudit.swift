import AVFoundation
import Accelerate
import CoreML
import CryptoKit
import Foundation
import TDJCore

protocol KeyFeatureAudio {
    var frameCount: Int { get }
    func fill(_ frames: Range<Int>, into values: UnsafeMutablePointer<Float>) throws
}

/// Evaluate an external key model without changing library keys or performance workspaces.
enum MacKeyCandidateAudit {
    struct Profile: Codable {
        var modelID: String
        var weightsSHA256: String
        var filtersSHA256: String
        var preprocessingVersion: Int
        var conversionVersion: Int
        var decisionPolicyVersion: Int
        var sampleRate: Int
        var fftSize: Int
        var hop: Int
        var bands: Int
        var windowFrames: Int
        var classOrder: [MusicalKey]
    }
    struct Row: Codable {
        var id: String
        var contentSHA256: String?
        var key: MusicalKey?
        var confidence: Double?
        var probabilities: [Double]?
        var featureFrames: Int?
        var wallSeconds: Double?
        var frontendSeconds: Double?
        var inferenceSeconds: Double?
        var error: String?
    }
    struct Report: Codable {
        var format = "generik.learned-key-audit/v1"
        var runID = UUID().uuidString
        var startedUTC = Date().ISO8601Format()
        var completedUTC: String?
        var requestedComputeUnits = "cpuAndNeuralEngine"
        var profile: Profile
        var modelArtifactSHA256: String
        var modelLoadSeconds: Double
        var manifest: AnalysisBenchmarkManifest
        var rows: [Row] = []
    }

    static func digest(_ url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hash = SHA256()
        while let data = try handle.read(upToCount: 1024 * 1024), !data.isEmpty { hash.update(data: data) }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }

    static func run(manifestURL: URL, modelDirectory: URL, output: URL) async throws {
        let manifest = try JSONDecoder().decode(AnalysisBenchmarkManifest.self, from: Data(contentsOf: manifestURL))
        try manifest.validate()
        let profile = try JSONDecoder().decode(Profile.self, from: Data(contentsOf: modelDirectory.appendingPathComponent("profile.json")))
        let isCQT = profile.modelID == "musical-key-cnn-mit-2025-v1"
        let knownModel = isCQT
            ? profile.weightsSHA256 == "fc92072f1b9b19552ce3b74a9c8ce0cecb97633a12ae524ac0d93c05800e354e"
                && profile.filtersSHA256 == "93368ced3ad3c4410c6e1b1edb7b8805799690175bec8f503beea4c7f28bdc69"
            : profile.modelID == "madmom-key-cnn-2018-eval1"
                && profile.weightsSHA256 == "c58ba553be1048877662a663a2670c0051b3c2c66d109b6042ba722ed0bfc7a6"
        guard knownModel, profile.preprocessingVersion == 1,
            profile.conversionVersion == 1, profile.decisionPolicyVersion == 1,
            profile.sampleRate == 44100, profile.fftSize == (isCQT ? 0 : 8192), profile.hop == 8820,
            profile.bands == 105, profile.windowFrames == 600, profile.classOrder.count == 24,
            profile.classOrder.enumerated().allSatisfy({ index, key in
                isCQT
                    ? key.tonic == ((index < 12 ? 8 : 11) + 7 * (index % 12)) % 12
                        && key.mode == (index < 12 ? .minor : .major)
                    : key.tonic == (index % 12 + 9) % 12 && key.mode == (index < 12 ? .major : .minor)
            }),
            !manifest.tracks.isEmpty, !FileManager.default.fileExists(atPath: output.path)
        else { throw CoreError.invalidAudio("The candidate profile or audit output is invalid.") }
        let filtersURL = modelDirectory.appendingPathComponent(isCQT ? "cqt.json" : "filters.f32")
        guard try digest(filtersURL) == profile.filtersSHA256 else {
            throw CoreError.invalidAudio("The key model filters changed.")
        }
        let package = modelDirectory.appendingPathComponent("KeyCandidate.mlpackage")
        let artifact = try digest(package.appendingPathComponent("Data/com.apple.CoreML/weights/weight.bin"))
            + ":" + digest(package.appendingPathComponent("Data/com.apple.CoreML/model.mlmodel"))
        let loadStart = ProcessInfo.processInfo.systemUptime
        let settings = MLModelConfiguration()
        settings.computeUnits = .cpuAndNeuralEngine
        let compiled = try await MLModel.compileModel(at: package)
        let model = try MLModel(contentsOf: compiled, configuration: settings)
        let artifactDigest = SHA256.hash(data: Data(artifact.utf8)).map { String(format: "%02x", $0) }.joined()
        var report = Report(profile: profile, modelArtifactSHA256: artifactDigest,
                            modelLoadSeconds: ProcessInfo.processInfo.systemUptime - loadStart, manifest: manifest)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let featuresDirectory = output.appendingPathComponent("features", isDirectory: true)
        try FileManager.default.createDirectory(at: featuresDirectory, withIntermediateDirectories: true)
        func save() throws {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(report).write(to: output.appendingPathComponent("report.json"), options: .atomic)
        }
        for expected in manifest.tracks {
            try Task.checkCancellation()
            let start = ProcessInfo.processInfo.systemUptime
            var row = Row(id: expected.id)
            do {
                let source = URL(fileURLWithPath: expected.path, relativeTo: manifestURL.deletingLastPathComponent())
                row.contentSHA256 = try digest(source)
                guard row.contentSHA256 == expected.sha256 else { throw CoreError.invalidAudio("The key audit audio changed.") }
                let frontend: any KeyFeatureAudio = try isCQT
                    ? KeyCQTAudio(url: source, filtersURL: filtersURL)
                    : KeyAudio(url: source, filtersURL: filtersURL)
                row.featureFrames = frontend.frameCount
                let featureURL = featuresDirectory.appendingPathComponent(expected.sha256 + ".f32")
                FileManager.default.createFile(atPath: featureURL.path, contents: nil)
                let featureFile = try FileHandle(forWritingTo: featureURL)
                defer { try? featureFile.close() }
                var logits = [Double](repeating: 0, count: 24)
                var total = 0
                var frontendSeconds = 0.0
                var inferenceSeconds = 0.0
                for first in stride(from: 0, to: frontend.frameCount, by: 600) {
                    try Task.checkCancellation()
                    let count = min(600, frontend.frameCount - first)
                    let modelFrames = isCQT ? max(8, count) : 600
                    let features = try MLMultiArray(shape: [1, 1, NSNumber(value: modelFrames), 105], dataType: .float32)
                    let featureStart = ProcessInfo.processInfo.systemUptime
                    try features.withUnsafeMutableBufferPointer(ofType: Float.self) { values, _ in
                        values.update(repeating: 0)
                        try frontend.fill(first..<(first + count), into: values.baseAddress!)
                        try featureFile.write(contentsOf: Data(bytes: values.baseAddress!, count: count * 105 * 4))
                    }
                    frontendSeconds += ProcessInfo.processInfo.systemUptime - featureStart
                    let inferenceStart = ProcessInfo.processInfo.systemUptime
                    let prediction = try await model.prediction(from: MLDictionaryFeatureProvider(dictionary: ["spectrogram": features]))
                    guard let values = prediction.featureValue(for: "logits")?.multiArrayValue,
                        values.shape.map(\.intValue) == [1, 24, modelFrames / 8], values.dataType == .float32
                    else { throw CoreError.invalidAudio("The key model returned an invalid output shape.") }
                    let valid = max(1, count / 8)
                    for key in 0..<24 {
                        for frame in 0..<valid {
                            let value = values[[0, NSNumber(value: key), NSNumber(value: frame)]].doubleValue
                            guard value.isFinite else { throw CoreError.invalidAudio("The key model returned a non-finite score.") }
                            logits[key] += value
                        }
                    }
                    total += valid
                    inferenceSeconds += ProcessInfo.processInfo.systemUptime - inferenceStart
                }
                guard total > 0 else { throw CoreError.invalidAudio("The key audit has no audio frames.") }
                logits = logits.map { $0 / Double(total) }
                let maximum = logits.max()!
                let expScores = logits.map { exp($0 - maximum) }
                let sum = expScores.reduce(0, +)
                let probabilities = expScores.map { $0 / sum }
                let winner = probabilities.indices.max { probabilities[$0] < probabilities[$1] }!
                row.key = profile.classOrder[winner]
                row.confidence = probabilities[winner]
                row.probabilities = probabilities
                row.frontendSeconds = frontendSeconds
                row.inferenceSeconds = inferenceSeconds
            } catch { row.error = error.localizedDescription }
            row.wallSeconds = ProcessInfo.processInfo.systemUptime - start
            report.rows.append(row)
            try save()
            FileHandle.standardOutput.write(Data("Key candidate \(report.rows.count)/\(manifest.tracks.count): \(expected.id), \(row.wallSeconds!) s\n".utf8))
        }
        report.completedUTC = Date().ISO8601Format()
        try save()
        guard report.rows.allSatisfy({ $0.error == nil }) else {
            throw CoreError.invalidAudio("Some key candidates failed. Read the saved report before using its results.")
        }
    }
}

private final class KeyAudio: KeyFeatureAudio {
    private let file: AVAudioFile
    private let input: AVAudioPCMBuffer
    private let output: AVAudioPCMBuffer
    private let converter: AVAudioConverter?
    private let filters: [Float]
    private let fft: FFTSetup
    private let sampleCount: Int
    private var samples: [Float] = []
    private var sampleStart = 0
    private var inputError: (any Error)?
    private let hann = (0..<8192).map { Float(0.5 - 0.5 * cos(2 * .pi * Double($0) / 8191)) }
    let frameCount: Int

    init(url: URL, filtersURL: URL) throws {
        file = try AVAudioFile(forReading: url, commonFormat: .pcmFormatFloat32, interleaved: false)
        let format = file.processingFormat
        let count = (Double(file.length) * 44100 / format.sampleRate).rounded()
        guard count >= 2, count <= 44100 * 24 * 3600,
            let target = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44100,
                                       channels: format.channelCount, interleaved: false),
            let input = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 16384),
            let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: 16384),
            let fft = vDSP_create_fftsetup(13, FFTRadix(kFFTRadix2))
        else { throw CoreError.invalidAudio("Cannot prepare the key audit audio.") }
        self.input = input
        self.output = output
        self.fft = fft
        sampleCount = Int(count)
        frameCount = Int(ceil(count / 8820))
        let data = try Data(contentsOf: filtersURL)
        guard data.count == 4096 * 105 * 4 else { throw CoreError.invalidAudio("The key filter dimensions are invalid.") }
        filters = data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
        if format.sampleRate == 44100 { converter = nil }
        else {
            guard let converter = AVAudioConverter(from: format, to: target) else {
                throw CoreError.invalidAudio("Cannot convert the key audit sample rate.")
            }
            converter.sampleRateConverterQuality = AVAudioQuality.max.rawValue
            self.converter = converter
        }
    }
    deinit { vDSP_destroy_fftsetup(fft) }

    func fill(_ frames: Range<Int>, into values: UnsafeMutablePointer<Float>) throws {
        let firstSample = max(0, frames.lowerBound * 8820 - 4096)
        let endSample = min(sampleCount, (frames.upperBound - 1) * 8820 + 4096)
        let discard = min(samples.count, max(0, firstSample - sampleStart))
        samples.removeFirst(discard)
        sampleStart += discard
        while sampleStart + samples.count < endSample {
            try Task.checkCancellation()
            guard let buffer = try read(), let channels = buffer.floatChannelData else { break }
            let trim = min(samples.count, max(0, firstSample - sampleStart))
            samples.removeFirst(trim)
            sampleStart += trim
            let channelCount = Int(buffer.format.channelCount)
            for index in 0..<Int(buffer.frameLength) {
                let mono = (0..<channelCount).reduce(Float(0)) { $0 + channels[$1][index] } / Float(channelCount)
                samples.append(min(32767, max(-32768, (mono * 32768).rounded(.towardZero))) / 32767)
            }
        }
        var real = [Float](repeating: 0, count: 8192)
        var imaginary = real
        var magnitude = [Float](repeating: 0, count: 4096)
        var filtered = [Float](repeating: 0, count: 105)
        for frame in frames {
            try Task.checkCancellation()
            for index in 0..<8192 {
                let sample = frame * 8820 + index - 4096
                let offset = sample - sampleStart
                real[index] = (sample >= 0 && sample < sampleCount && samples.indices.contains(offset) ? samples[offset] : 0) * hann[index]
            }
            vDSP_vclr(&imaginary, 1, 8192)
            real.withUnsafeMutableBufferPointer { re in
                imaginary.withUnsafeMutableBufferPointer { im in
                    var split = DSPSplitComplex(realp: re.baseAddress!, imagp: im.baseAddress!)
                    vDSP_fft_zip(fft, &split, 1, 13, FFTDirection(FFT_FORWARD))
                    vDSP_zvabs(&split, 1, &magnitude, 1, 4096)
                }
            }
            vDSP_mmul(filters, 1, magnitude, 1, &filtered, 1, 105, 1, 4096)
            let row = values.advanced(by: (frame - frames.lowerBound) * 105)
            for band in 0..<105 { row[band] = log10(1 + filtered[band]) }
        }
    }

    private func readInput(_ requested: AVAudioFrameCount) throws -> Bool {
        let remaining = min(Int64(min(requested, input.frameCapacity)), file.length - file.framePosition)
        guard remaining > 0 else { return false }
        try file.read(into: input, frameCount: AVAudioFrameCount(remaining))
        return input.frameLength > 0
    }
    private func read() throws -> AVAudioPCMBuffer? {
        guard let converter else { return try readInput(input.frameCapacity) ? input : nil }
        var error: NSError?
        let status = converter.convert(to: output, error: &error) { [self] requested, status in
            do {
                let hasData = try readInput(requested)
                status.pointee = hasData ? .haveData : .endOfStream
                return hasData ? input : nil
            } catch {
                inputError = error
                status.pointee = .endOfStream
                return nil
            }
        }
        if let inputError { throw inputError }
        if status == .error { throw error ?? CoreError.invalidAudio("Cannot resample the key audit audio.") }
        return output.frameLength > 0 ? output : nil
    }
}
