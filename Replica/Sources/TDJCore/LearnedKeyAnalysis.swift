import CoreML
import CryptoKit
import Foundation

public struct LearnedKeyProfile: Codable, Equatable, Sendable {
    public let model: String
    public let weightsSHA256: String
    public let preprocessing: Int
    public let conversion: Int
    public let decisionPolicy: Int
    public let calibration: Int
    public static let current = Self(
        model: "MusicalKeyCNN/MIT-2025",
        weightsSHA256: "fc92072f1b9b19552ce3b74a9c8ce0cecb97633a12ae524ac0d93c05800e354e",
        preprocessing: 1, conversion: 1, decisionPolicy: 1, calibration: 1)
    public var id: String { "\(model)|\(weightsSHA256)|cqt\(preprocessing)|fp16\(conversion)|policy\(decisionPolicy)|cal\(calibration)" }
}

public struct LearnedKeyAnalysis: Codable, Equatable, Sendable {
    public let profile: LearnedKeyProfile
    public let key: MusicalKey
    public let score: Double
    public let featureFrames: Int
    /// Smoothed exact-key frequency in the frozen R118 development score bin.
    public var calibratedConfidence: Double? {
        guard profile == .current, score.isFinite, (0...1).contains(score) else { return nil }
        return score >= 0.8 ? 39.0 / 40 : score >= 0.5 ? 35.0 / 41 : 15.0 / 25
    }
    var mayReplaceAutomaticKey: Bool { profile == .current && score >= 0.8 && score <= 1 }
    func validate() throws {
        guard score.isFinite, (0...1).contains(score), (8...432_000).contains(featureFrames),
            profile.model.utf8.count <= 128, profile.weightsSHA256.count == 64,
            profile.weightsSHA256.allSatisfy(\.isHexDigit), profile.preprocessing > 0,
            profile.conversion > 0, profile.decisionPolicy > 0, profile.calibration > 0 else {
            throw CoreError.invalidAudio("The learned key evidence is invalid.")
        }
    }
}

enum LearnedKeyAnalyzer {
    private static let compiled = Result {
        guard let source = Bundle.module.url(forResource: "KeyCandidate", withExtension: "mlpackage", subdirectory: "KeyModelAssets") else {
            throw CoreError.invalidAudio("The learned key model is missing.")
        }
        return try MLModel.compileModel(at: source)
    }
    static func analyze(url: URL, analysis: AudioAnalysis, root: URL,
                        checkCancellation: @escaping @Sendable () throws -> Void) throws -> LearnedKeyAnalysis? {
        guard analysis.duration >= 2 else { return nil }
        try checkCancellation()
        let before = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        guard let filters = Bundle.module.url(forResource: "cqt", withExtension: "json", subdirectory: "KeyModelAssets"),
            analysisDigest(try Data(contentsOf: filters)) == "93368ced3ad3c4410c6e1b1edb7b8805799690175bec8f503beea4c7f28bdc69" else {
            throw CoreError.invalidAudio("The learned key filters do not match their version.")
        }
        let audio = try KeyCQTAudio(url: url, filtersURL: filters, checkCancellation: checkCancellation)
        let settings = MLModelConfiguration(); settings.computeUnits = .cpuAndNeuralEngine
        let model = try MLModel(contentsOf: compiled.get(), configuration: settings)
        let metadata = model.modelDescription.metadata[.creatorDefinedKey] as? [String: String]
        guard metadata?["weightsSHA256"] == LearnedKeyProfile.current.weightsSHA256,
            metadata?["preprocessingVersion"] == "1", metadata?["conversionVersion"] == "1" else {
            throw CoreError.invalidAudio("The learned key model has a different version.")
        }
        let folder = root.appendingPathComponent("LearnedKey").appendingPathComponent(AnalysisAudioIdentity(analysis).key)
            .appendingPathComponent(analysisDigest(Data(LearnedKeyProfile.current.id.utf8)))
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var logits = [Double](repeating: 0, count: 24)
        var total = 0
        for first in stride(from: 0, to: audio.frameCount, by: 600) {
            try checkCancellation()
            let count = min(600, audio.frameCount - first)
            let valid = max(1, count / 8)
            let file = folder.appendingPathComponent("key-window-\(first).json")
            let identity = "\(analysis.contentSHA256)|\(LearnedKeyProfile.current.id)|\(first)|\(count)"
            let sums: [Double]
            if let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize, size < 8192,
                let data = try? Data(contentsOf: file), data.count < 8192,
                let saved = try? JSONDecoder().decode(KeyWindow.self, from: data), saved.identity == identity,
                saved.values.count == 24, saved.values.allSatisfy(\.isFinite),
                saved.digest == analysisDigest(try JSONEncoder.sorted.encode(saved.values)) {
                sums = saved.values
                AnalysisMeasurement.current?.cacheHit("learnedKeyWindow")
            } else {
                sums = try autoreleasepool {
                    let frames = max(8, count)
                    let features = try MLMultiArray(shape: [1, 1, NSNumber(value: frames), 105], dataType: .float32)
                    try AnalysisMeasurement.measure("learnedKeyFrontend") {
                        try features.withUnsafeMutableBufferPointer(ofType: Float.self) { values, _ in
                            values.update(repeating: 0)
                            try audio.fill(first..<(first + count), into: values.baseAddress!)
                        }
                    }
                    try checkCancellation()
                    let output = try AnalysisMeasurement.measure("learnedKeyInference") {
                        try model.prediction(from: MLDictionaryFeatureProvider(dictionary: ["spectrogram": features]))
                    }
                    guard let values = output.featureValue(for: "logits")?.multiArrayValue,
                        values.shape.map(\.intValue) == [1, 24, frames / 8], values.dataType == .float32 else {
                        throw CoreError.invalidAudio("The learned key output has invalid dimensions.")
                    }
                    var sums = [Double](repeating: 0, count: 24)
                    for key in 0..<24 {
                        for frame in 0..<valid {
                            let value = values[[0, NSNumber(value: key), NSNumber(value: frame)]].doubleValue
                            guard value.isFinite else { throw CoreError.invalidAudio("The learned key score is not finite.") }
                            sums[key] += value
                        }
                    }
                    return sums
                }
                let after = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
                guard before.fileSize == after.fileSize, before.contentModificationDate == after.contentModificationDate else {
                    throw CoreError.invalidAudio("The audio changed during key analysis.")
                }
                let saved = KeyWindow(identity: identity, values: sums, digest: analysisDigest(try JSONEncoder.sorted.encode(sums)))
                try checkCancellation()
                try JSONEncoder.sorted.encode(saved).write(to: file, options: .atomic)
            }
            for index in logits.indices { logits[index] += sums[index] }
            total += valid
        }
        logits = logits.map { $0 / Double(total) }
        let winner = logits.indices.max { logits[$0] < logits[$1] }!
        let scores = logits.map { exp($0 - logits[winner]) }
        let key = MusicalKey(tonic: ((winner < 12 ? 8 : 11) + 7 * (winner % 12)) % 12,
                             mode: winner < 12 ? .minor : .major)
        let result = LearnedKeyAnalysis(profile: .current, key: key, score: 1 / scores.reduce(0, +), featureFrames: audio.frameCount)
        try result.validate()
        return result
    }
    private struct KeyWindow: Codable {
        let identity: String
        let values: [Double]
        let digest: String
    }
}
