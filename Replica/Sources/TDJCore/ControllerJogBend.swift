import Foundation

/// Converts relative wheel-side jog input into a bounded temporary playback-rate bend.
public enum ControllerJogBend {
    public static let maximumCounts = 4.0
    public static let maximumRateOffset = 0.08
    public static let releaseDelayNanoseconds: UInt64 = 150_000_000

    public static func deltaCounts(fromNormalizedValue value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return (min(1, max(0, value)) - 0.5) * 8
    }

    public static func accumulatedCounts(current: Double, delta: Double) -> Double {
        guard current.isFinite, delta.isFinite else { return 0 }
        return min(maximumCounts, max(-maximumCounts, current + delta))
    }

    public static func playbackRate(forCounts counts: Double) -> Double {
        let bounded = counts.isFinite ? min(maximumCounts, max(-maximumCounts, counts)) : 0
        return 1 + bounded * maximumRateOffset / maximumCounts
    }
}
