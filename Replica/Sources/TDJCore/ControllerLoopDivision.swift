import Foundation

public struct ControllerLoopDivision: Sendable {
    private var generation: UInt64 = 0
    private var start: Double = 0
    private var originalEnd: Double = 0
    private var dividedEnd: Double = 0

    public init() {}

    /**
     * Halves an active loop and retains its original length until the loop or track changes.
     */
    public mutating func divide(generation: UInt64, start: Double, end: Double) -> Double? {
        guard generation != 0, start.isFinite, end.isFinite, start >= 0, end - start >= 2 else { return nil }
        if !matches(generation: generation, start: start, end: end) {
            self.generation = generation
            self.start = start
            originalEnd = end
        }
        dividedEnd = start + (end - start) / 2
        return dividedEnd
    }

    /**
     * Restores the original end only while the same divided loop remains active.
     */
    public mutating func restore(generation: UInt64, start: Double, end: Double) -> Double? {
        guard matches(generation: generation, start: start, end: end) else { return nil }
        dividedEnd = originalEnd
        return originalEnd
    }

    private func matches(generation: UInt64, start: Double, end: Double) -> Bool {
        self.generation == generation && self.start == start && dividedEnd == end && originalEnd > start
    }
}
