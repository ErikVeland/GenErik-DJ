import Foundation

public enum AnalysisWorkProgress {
    @TaskLocal public static var observer: (@Sendable (Double) -> Void)?

    public struct Step {
        private let range: ClosedRange<Double>
        private let observer: (@Sendable (Double) -> Void)?
        private var lastReport: ContinuousClock.Instant?

        public init(_ range: ClosedRange<Double>, observer: (@Sendable (Double) -> Void)? = AnalysisWorkProgress.observer) {
            self.range = range
            self.observer = observer
        }

        public mutating func advance(_ completed: Int64, of total: Int64) {
            guard observer != nil, completed > 0, total > 0 else { return }
            advance(fraction: Double(completed) / Double(total))
        }

        public mutating func advance(fraction: Double) {
            guard let observer, fraction.isFinite, fraction > 0 else { return }
            let now = ContinuousClock.now
            if fraction < 1, let lastReport, lastReport.duration(to: now) < .seconds(1) { return }
            lastReport = now
            observer(range.lowerBound + (range.upperBound - range.lowerBound) * min(1, fraction))
        }
    }
}
