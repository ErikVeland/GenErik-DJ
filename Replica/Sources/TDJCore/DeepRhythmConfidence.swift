import Foundation

/// Probability of at least 95% beat and downbeat event F1 within 25 ms on a comparable excerpt.
public struct DeepRhythmConfidence: Codable, Equatable, Sendable {
    public let calibrationVersion: Int
    public let observations: Int
    public let successes: Int
    public var probability: Double { Double(successes + 1) / Double(observations + 2) }
}

extension DeepBeatAnalysis {
    public var rhythmConfidence: DeepRhythmConfidence? {
        guard profile == .current, (9...10).contains(profile.decisionPolicy), adaptiveCandidate != nil,
            audio.sampleRate > 0, (20...35).contains(Double(audio.frameCount) / audio.sampleRate) else { return nil }
        // Frozen R118 development bins. Longer tracks have no calibrated estimate.
        return hasStrongEvidence
            ? .init(calibrationVersion: 1, observations: 43, successes: 26)
            : .init(calibrationVersion: 1, observations: 9, successes: 0)
    }
}
