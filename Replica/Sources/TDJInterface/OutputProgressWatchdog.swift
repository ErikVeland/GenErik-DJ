import Foundation

struct OutputProgressWatchdog {
    private static let stallLimit: Duration = .milliseconds(750)
    private var nextSample: ContinuousClock.Instant?
    private var lastProgress: ContinuousClock.Instant?
    private var healthySince: ContinuousClock.Instant?
    private var lastFrame: UInt64 = 0
    private var restarted = false

    mutating func arm(frame: UInt64, now: ContinuousClock.Instant = .now) {
        lastFrame = frame
        lastProgress = now
        nextSample = now + .milliseconds(100)
        healthySince = nil
    }

    mutating func disarm() {
        nextSample = nil
    }

    mutating func resetRecoveryBudget() {
        restarted = false
    }

    mutating func isStalled(frame: @autoclosure () -> UInt64, now: ContinuousClock.Instant = .now) -> Bool {
        guard let nextSample, now >= nextSample, let lastProgress else { return false }
        self.nextSample = now + .milliseconds(100)
        let rendered = frame()
        let elapsed = lastProgress.duration(to: now)
        if rendered != lastFrame {
            if elapsed >= Self.stallLimit || healthySince == nil { healthySince = now }
            lastFrame = rendered
            self.lastProgress = now
            if let healthySince, healthySince.duration(to: now) >= .seconds(2) { restarted = false }
            return false
        }
        guard elapsed >= Self.stallLimit else { return false }
        healthySince = nil
        return true
    }

    mutating func takeRestart() -> Bool {
        guard !restarted else { return false }
        restarted = true
        return true
    }
}
