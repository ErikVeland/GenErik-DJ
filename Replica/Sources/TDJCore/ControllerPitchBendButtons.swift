public enum ControllerPitchBendDirection: Sendable {
    case down, up
}

/**
 * Tracks held pitch-bend directions for one loaded source.
 */
public struct ControllerPitchBendButtons: Sendable {
    public static let rateOffset = 0.04
    private var generation: UInt64?
    private var down = false
    private var up = false

    public init() {}

    /**
     * Returns the held direction only for the current loaded source.
     */
    public func isPressed(_ direction: ControllerPitchBendDirection, generation: UInt64) -> Bool {
        guard generation != 0, self.generation == generation else { return false }
        return direction == .up ? up : down
    }

    /**
     * Returns the new temporary rate, or nil when the event cannot change it.
     */
    public mutating func update(
        _ direction: ControllerPitchBendDirection, pressed: Bool, generation: UInt64
    ) -> Double? {
        guard generation != 0 else {
            self = .init()
            return nil
        }
        if self.generation != generation {
            self = .init()
            self.generation = generation
            guard pressed else { return nil }
        }
        switch direction {
        case .down:
            guard down != pressed else { return nil }
            down = pressed
        case .up:
            guard up != pressed else { return nil }
            up = pressed
        }
        return 1 + Double((up ? 1 : 0) - (down ? 1 : 0)) * Self.rateOffset
    }
}
