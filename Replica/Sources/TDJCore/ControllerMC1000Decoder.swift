public enum ControllerMC1000Event: Equatable, Sendable {
    case controlsChanged(Bool)
    case message(ControllerMIDIMessage)
}

/**
 * Observes independently qualified MC-1000 deck and Shift contexts without changing raw MIDI.
 */
public struct ControllerMC1000Decoder: Sendable {
    private struct Context: Equatable, Sendable {
        let channel: UInt8
        let shifted: Bool
    }
    private var left: Context?
    private var right: Context?
    private var standard = ControllerMIDIDecoder()
    public init() {}

    /**
     * Resets only the physical side that changes context. Late releases cannot select another deck bank.
     */
    public mutating func append(_ bytes: [UInt8]) -> [ControllerMC1000Event] {
        var events: [ControllerMC1000Event] = []
        for message in standard.append(bytes) {
            if let shifted = layer(message) {
                let isLeft = message.channel % 2 == 0
                let previous = isLeft ? left : right
                let release = message.kind == .note && message.isNoteOff
                if !release || previous == nil || previous?.channel == message.channel {
                    let next = Context(channel: message.channel, shifted: shifted)
                    if let previous, previous != next { events.append(.controlsChanged(isLeft)) }
                    if isLeft { left = next } else { right = next }
                }
            }
            events.append(.message(message))
        }
        return events
    }

    private func layer(_ message: ControllerMIDIMessage) -> Bool? {
        guard message.channel < 4, message.maximum == 127 else { return nil }
        if message.kind == .note {
            if [1, 2, 3, 10, 12, 13, 14, 15].contains(message.number) { return false }
            if [64, 65, 66, 73, 75, 76, 77, 78].contains(message.number) { return true }
        } else if message.kind == .control {
            if message.number == 5 || message.number == 33 { return false }
            if message.number == 68 || message.number == 96 { return true }
        }
        return nil
    }
}
