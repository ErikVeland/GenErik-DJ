import Foundation

/// Probability of at least 95% beat and downbeat event F1 within 25 ms on a comparable excerpt.
public struct DeepRhythmConfidence: Codable, Equatable, Sendable {
    public let calibrationVersion: Int
    public let observations: Int
    public let successes: Int
    public var estimatedProbability: Double? = nil
    public var probability: Double { estimatedProbability ?? Double(successes + 1) / Double(observations + 2) }
}

extension DeepBeatAnalysis {
    public var rhythmConfidence: DeepRhythmConfidence? {
        guard profile == .current, profile.decisionPolicy == 14, adaptiveCandidate != nil,
            audio.sampleRate > 0, (20...35).contains(Double(audio.frameCount) / audio.sampleRate),
            let evidence = rhythmEvidence, evidence.version == 1,
            (try? evidence.validate()) != nil else { return nil }
        return .init(calibrationVersion: 2, observations: 159, successes: 76,
                     estimatedProbability: DeepRhythmCalibration.probability(evidence.features))
    }
}

// Frozen before R124 validation. See docs/testing/analysis-r124-rhythm-calibration.json.
enum DeepRhythmCalibration {
    static let id = "rhythm-logistic2-62ff7defe3af01e507246e41fd3f31278a55f3d4cc4155b5c08505d85dc8e736"
    private static let mean: [Double] = [7.619859227594341, 8.17789252898978, 18.396844169652883, 0.021062135012197163, 12.484497876195547, 0.8553459119496856]
    private static let scale: [Double] = [1.8109855021634709, 2.337698700208542, 3.165640779445779, 0.006365076031660009, 12.371024615323202, 0.3517517346945806]
    private static let coefficients: [Double] = [0.046999106897173924, 0.15566606100943975, 0.42339694538801487, -0.36558632136331853, -0.7155780624473932, 0.16274853060674746]
    private static let intercept = -0.23439895013384185

    static func probability(_ features: [Double]) -> Double {
        let z = features.indices.reduce(intercept) { $0 + (features[$1] - mean[$1]) / scale[$1] * coefficients[$1] }
        return z >= 0 ? 1 / (1 + exp(-z)) : exp(z) / (1 + exp(z))
    }
}
