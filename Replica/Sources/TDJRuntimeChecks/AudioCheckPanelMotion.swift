import Foundation

/// A fixed one-second sequence exercises both drawer edges and both mixer tabs.
public enum AudioCheckPanelLayout: String, Encodable, Sendable {
    case fxAFilterB, closed, closedFilterA, closedFilterB, fxBMixerA, fxAMixerB, fxBFilterA
    public var isClosed: Bool { self == .closed || self == .closedFilterA || self == .closedFilterB }
    public var effectsOnA: Bool { self == .fxAFilterB || self == .fxAMixerB }
    public var effectsOnB: Bool { self == .fxBMixerA || self == .fxBFilterA }
    public var mixerOnA: Bool { self == .fxBMixerA || self == .fxBFilterA }
    public var mixerOnB: Bool { self == .fxAFilterB || self == .fxAMixerB }
    public var filterOnA: Bool { self == .fxBFilterA || self == .closedFilterA }
    public var filterOnB: Bool { self == .fxAFilterB || self == .closedFilterB }
    public static func at(step: Int) -> Self {
        switch step % 8 {
        case 0: .fxAFilterB
        case 1: .closedFilterB
        case 2: .fxBMixerA
        case 4: .fxAMixerB
        case 6: .fxBFilterA
        case 7: .closedFilterA
        default: .closed
        }
    }
}

public struct AudioCheckPanelTransition: Encodable, Sendable {
    public let step: Int
    public let layout: AudioCheckPanelLayout
    public let arrivalMachTicks: UInt64
    public let elapsedSeconds: Double
}

public struct AudioCheckPanelMotionMetrics: Encodable, Sendable {
    public let periodSeconds: Double
    public let transitions: [AudioCheckPanelTransition]
    public let transitionCount: Int
    public let transitionsDropped: Int
    public let skippedSteps: Int
    public let invalidTimes: Int
    public let capacity: Int
    public let scope = "Requested diagnostic drawer changes, not proof of displayed frames or touch fidelity."
}

/// Fixed storage is allocated before the display link starts. Summaries are read after it stops.
public struct AudioCheckPanelMotionAccumulator: Sendable {
    public static let periodSeconds = 1.0
    private var records: [AudioCheckPanelTransition?]
    private var count = 0, dropped = 0, skipped = 0, invalid = 0
    private var previousStep: Int?
    public init(capacity: Int = 512) { records = Array(repeating: nil, count: max(0, min(4096, capacity))) }
    public mutating func observe(elapsedSeconds: Double, arrivalMachTicks: UInt64) -> AudioCheckPanelLayout? {
        guard elapsedSeconds.isFinite, elapsedSeconds >= 0,
            let step = Int(exactly: floor(elapsedSeconds / Self.periodSeconds)),
            previousStep.map({ step >= $0 }) ?? true
        else {
            invalid += 1
            return nil
        }
        guard step != previousStep else { return nil }
        skipped += previousStep.map { max(0, step - $0 - 1) } ?? step
        previousStep = step
        let layout = AudioCheckPanelLayout.at(step: step)
        if count < records.count {
            records[count] = AudioCheckPanelTransition(
                step: step, layout: layout, arrivalMachTicks: arrivalMachTicks, elapsedSeconds: elapsedSeconds)
        } else {
            dropped += 1
        }
        count += 1
        return layout
    }
    public var summary: AudioCheckPanelMotionMetrics {
        .init(
            periodSeconds: Self.periodSeconds, transitions: records.compactMap { $0 }, transitionCount: count,
            transitionsDropped: dropped, skippedSteps: skipped, invalidTimes: invalid, capacity: records.count)
    }
}
