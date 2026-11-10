import Foundation

enum DeepRhythmTiming {
    static func refinedPeaks(_ logits: [Float]) -> [Double] {
        BeatThisAnalyzer.peaks(logits).map { time in
            let position = time * 50
            let index = Int(position.rounded())
            guard abs(position - Double(index)) < 0.0000001,
                index > 0, index + 1 < logits.count,
                logits[index] > logits[index - 1], logits[index] > logits[index + 1] else { return time }
            let left = Double(logits[index - 1])
            let center = Double(logits[index])
            let right = Double(logits[index + 1])
            let curvature = left - 2 * center + right
            guard curvature.isFinite, curvature < -0.000000001 else { return time }
            let correction = max(-0.5, min(0.5, 0.5 * (left - right) / curvature))
            return (position + correction) / 50
        }
    }
}
