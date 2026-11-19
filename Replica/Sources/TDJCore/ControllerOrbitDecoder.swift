public enum ControllerOrbitEvent: Equatable, Sendable {
    case bankChanged
    case message(ControllerMIDIMessage)
}

/**
 * Observes the four factory pad channels without changing stored Orbit settings.
 */
public struct ControllerOrbitDecoder: Sendable {
    private var channel: UInt8?
    private var standard = ControllerMIDIDecoder()
    public init() {}

    /**
     * Retires the previous bank before the next mapped pad. Late releases keep their original address.
     */
    public mutating func append(_ bytes: [UInt8]) -> [ControllerOrbitEvent] {
        var events: [ControllerOrbitEvent] = []
        for message in standard.append(bytes) {
            if message.channel < 4, message.kind == .note, message.maximum == 127,
                (36...51).contains(message.number), !message.isNoteOff
            {
                if channel != nil && channel != message.channel { events.append(.bankChanged) }
                channel = message.channel
            }
            events.append(.message(message))
        }
        return events
    }
}
