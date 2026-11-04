import Foundation

/// Family order follows NI's 1.5 footage. Target-build parity remains open.
/// Loop Stutter lengths use a user-authorized development policy.
public enum SuperSlicerFamily: String, CaseIterable, Sendable, Identifiable {
    case loopStutter, turntablism, pitch
    public var id: Self { self }
    var title: String {
        switch self {
        case .loopStutter: "Loop Stutter"
        case .turntablism: "Turntablism"
        case .pitch: "Pitch"
        }
    }
    var symbol: String {
        switch self {
        case .loopStutter: "arrow.clockwise"
        case .turntablism: "opticaldisc"
        case .pitch: "music.note"
        }
    }
    /// Equal thirds are a development hit-boundary policy, not measured NI thresholds.
    func action(at y: Double) -> SuperSlicerAction {
        let row = y < 1.0 / 3 ? 0 : y < 2.0 / 3 ? 1 : 2
        switch self {
        case .loopStutter: return [.slice, .stutterHalf, .stutterQuarter][row]
        case .turntablism: return [.brake, .scratch, .reverse][row]
        case .pitch: return [.pitchUp, .slice, .pitchDown][row]
        }
    }
    func label(row: Int) -> String? {
        guard (0..<3).contains(row) else { return nil }
        switch self {
        case .loopStutter: return ["Slice", "½ Slice", "¼ Slice"][row]
        case .turntablism: return ["Brake", "Scratch", "Reverse"][row]
        case .pitch: return ["Pitch Up", "Slice", "Pitch Down"][row]
        }
    }
}

enum SuperSlicerAction: Equatable {
    case slice, stutterHalf, stutterQuarter, brake, scratch, reverse, pitchUp, pitchDown
    var isSliceRepeat: Bool {
        switch self {
        case .slice, .stutterHalf, .stutterQuarter: true
        default: false
        }
    }
    /// Full, half and quarter of the playable slice, selected as an educated guess.
    var provisionalSliceFraction: Double {
        switch self {
        case .stutterHalf: 0.5
        case .stutterQuarter: 0.25
        default: 1
        }
    }
    /// Brake reserves the bottom tenth of its region for a reachable stop.
    /// Pitch retains its provisional full-surface response.
    func provisionalRate(at y: Double) -> Double {
        switch self {
        case .slice, .stutterHalf, .stutterQuarter, .scratch: return 1
        case .reverse: return -1
        case .brake: return min(1, max(0, 1 - y / 0.3))
        case .pitchUp, .pitchDown: return pow(2, (0.5 - y) * 2)
        }
    }
}
