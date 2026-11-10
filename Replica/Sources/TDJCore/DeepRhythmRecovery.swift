import Foundation

/// Recover a review candidate from sparse missed beats or weaker extra bar peaks.
enum DeepRhythmRecovery {
    static func fit(
        beats: [Double], bars: [Double], barLogits: [Float], sampleRate: Double, frameCount: Int64,
        checkCancellation: @Sendable () throws -> Void
    ) throws -> DeepAdaptiveBeatCandidate? {
        try checkCancellation()
        guard (16...600_000).contains(beats.count), sampleRate.isFinite, sampleRate > 0, frameCount > 0,
            beats.allSatisfy({ $0.isFinite && $0 >= 0 && $0 * sampleRate < Double(frameCount) }),
            !barLogits.isEmpty else { return nil }
        let intervals = zip(beats.dropFirst(), beats).map(-).sorted()
        let median = intervals[intervals.count / 2]
        guard median > 0, (60...200).contains(60 / median) else { return nil }
        var repaired = [beats[0]]
        var inserted = 0
        for index in 1..<beats.count {
            if index % 1024 == 0 { try checkCancellation() }
            let left = beats[index - 1], right = beats[index]
            let ratio = (right - left) / median
            guard ratio.isFinite, ratio >= 0.88, ratio <= 3.36 else { return nil }
            let steps = Int(ratio.rounded())
            guard (1...3).contains(steps), (0.88...1.12).contains(ratio / Double(steps)) else { return nil }
            inserted += steps - 1
            guard inserted <= max(1, beats.count / 20) else { return nil }
            for step in 1...steps {
                repaired.append(step == steps ? right : left + (right - left) * Double(step) / Double(steps))
            }
        }
        if let candidate = try DeepAdaptiveBeatCandidate.fit(
            beats: repaired, bars: bars, sampleRate: sampleRate, frameCount: frameCount,
            checkCancellation: checkCancellation)
        { return candidate }

        var strengths: [Double] = []
        for (beat, time) in repaired.enumerated() {
            if beat % 1024 == 0 { try checkCancellation() }
            let index = Int(((time - 0.008) * 50).rounded(.toNearestOrEven))
            guard barLogits.indices.contains(index) else { return nil }
            strengths.append(Double(barLogits[max(0, index - 3)...min(barLogits.count - 1, index + 3)].max()!))
        }
        let blocks = strengths.count / 4
        var votes = [Int](repeating: 0, count: 4)
        for block in 0..<blocks {
            if block % 256 == 0 { try checkCancellation() }
            let start = block * 4
            let order = (0..<4).sorted { strengths[start + $0] > strengths[start + $1] }
            let best = strengths[start + order[0]]
            if best > 0, best - strengths[start + order[1]] >= 2 { votes[order[0]] += 1 }
        }
        let phase = votes.indices.max { votes[$0] < votes[$1] }!
        let support = Double(votes[phase]) / Double(blocks)
        guard votes[phase] >= 4, support >= 0.9 else { return nil }
        let selectedBars = stride(from: phase, to: repaired.count, by: 4).map { repaired[$0] }
        guard let candidate = try DeepAdaptiveBeatCandidate.fit(
            beats: repaired, bars: selectedBars, sampleRate: sampleRate, frameCount: frameCount,
            checkCancellation: checkCancellation) else { return nil }
        return .init(map: candidate.map, observedBeatCount: candidate.observedBeatCount,
                     barConsistency: support, compressionErrorMilliseconds: candidate.compressionErrorMilliseconds)
    }
}
