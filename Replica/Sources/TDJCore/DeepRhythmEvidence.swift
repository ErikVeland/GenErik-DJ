import Foundation

/// Versioned inputs to the rhythm reliability estimator, separate from musical timing.
public struct DeepRhythmEvidence: Codable, Equatable, Sendable {
    public let version: Int
    public let features: [Double]

    func validate() throws {
        guard version > 0, features.count == 6,
            features.allSatisfy({ $0.isFinite && abs($0) <= 1_000_000 }),
            features[1] >= 0, features[3] >= 0, (0...60).contains(features[4]),
            features[5] == 0 || features[5] == 1 else {
            throw CoreError.invalidAudio("The rhythm confidence evidence is invalid.")
        }
    }

    static func measure(
        beats: [Float], bars: [Float], times: [Double], constant: DeepBeatCandidate?,
        adaptive: DeepAdaptiveBeatCandidate?, checkCancellation: @Sendable () throws -> Void
    ) throws -> Self? {
        guard let adaptive, times.count >= 16, beats.count == bars.count,
            times.count == adaptive.observedBeatCount else { return nil }
        var strength: [Double] = []
        var curvature: [Double] = []
        var phases = [Double](repeating: 0, count: 4)
        var counts = [Int](repeating: 0, count: 4)
        for (beat, time) in times.enumerated() {
            if beat % 1024 == 0 { try checkCancellation() }
            let index = Int((time * 50).rounded(.toNearestOrEven))
            guard beats.indices.contains(index) else { return nil }
            strength.append(Double(beats[index]))
            if index > 0, index + 1 < beats.count {
                curvature.append(Double(beats[index]) - (Double(beats[index - 1]) + Double(beats[index + 1])) / 2)
            }
            let value = bars[max(0, index - 3)...min(bars.count - 1, index + 3)].max()!
            phases[beat % 4] += Double(value)
            counts[beat % 4] += 1
        }
        guard !curvature.isEmpty else { return nil }
        for phase in phases.indices { phases[phase] /= Double(counts[phase]) }
        let phase = adaptive.map.downbeatOffset
        let contrast = phases[phase] - phases.enumerated().filter { $0.offset != phase }.map(\.element).max()!
        let intervals = zip(times.dropFirst(), times).map(-)
        let mean = intervals.reduce(0, +) / Double(intervals.count)
        guard mean > 0 else { return nil }
        let variance = intervals.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(intervals.count)
        let result = Self(version: 1, features: [
            quantile(strength, 0.1), quantile(curvature, 0.5), contrast, sqrt(variance) / mean,
            min(60, constant?.residualMilliseconds ?? 60), constant?.hasStrongEvidence == true ? 1 : 0,
        ])
        try result.validate()
        return result
    }

    private static func quantile(_ values: [Double], _ fraction: Double) -> Double {
        let sorted = values.sorted()
        let position = Double(sorted.count - 1) * fraction
        let first = Int(position)
        return sorted[first] + (sorted[min(first + 1, sorted.count - 1)] - sorted[first]) * (position - Double(first))
    }
}
