import Foundation

enum BeatThisTempo {
    static func refine(
        fallbackBPM: Double, beats: [Double], configuration: AnalysisConfiguration,
        checkCancellation: @Sendable () throws -> Void = {}
    ) throws -> Double? {
        try checkCancellation()
        guard fallbackBPM.isFinite, (configuration.minimumBPM...configuration.maximumBPM).contains(fallbackBPM),
            beats.count >= 33, beats.allSatisfy({ $0.isFinite && $0 >= 0 })
        else { return nil }
        let steps = zip(beats, beats.dropFirst()).map { (time: $0.0, interval: $0.1 - $0.0) }
        guard steps.allSatisfy({ $0.interval > 0 }) else { return nil }
        func supports(_ interval: Double, bpm: Double) -> Bool {
            let period = 60 / bpm
            return abs(interval - period) <= max(0.03, period * 0.075)
        }
        for alternative in [fallbackBPM / 2, fallbackBPM * 2]
        where (configuration.minimumBPM...configuration.maximumBPM).contains(alternative) {
            var windows: [Int: (original: Int, alternative: Int)] = [:]
            var originalCount = 0, alternativeCount = 0
            for (index, step) in steps.enumerated() {
                if index.isMultiple(of: 256) { try checkCancellation() }
                let original = supports(step.interval, bpm: fallbackBPM) ? 1 : 0
                let other = supports(step.interval, bpm: alternative) ? 1 : 0
                originalCount += original
                alternativeCount += other
                let window = Int(step.time / 30)
                var counts = windows[window, default: (0, 0)]
                counts.original += original
                counts.alternative += other
                windows[window] = counts
            }
            let eligible = windows.values.filter { $0.original + $0.alternative >= 8 }
            let supported = eligible.filter { Double($0.alternative) > 1.5 * Double($0.original) }
            // Require sustained evidence. Dense subdivisions alone must not double the tempo.
            if alternativeCount >= 32, Double(alternativeCount) >= 0.35 * Double(steps.count),
                Double(alternativeCount) > 1.5 * Double(originalCount), eligible.count >= 3,
                supported.count * 3 >= eligible.count * 2 {
                return alternative
            }
        }
        return nil
    }
}
