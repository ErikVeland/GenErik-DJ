public enum ControllerMPD218Event: Equatable, Sendable {
    case bankChanged
    case message(ControllerMIDIMessage)
}

/**
 * Observes only the three pad banks in the published chroma10 factory preset.
 */
public struct ControllerMPD218Decoder: Sendable {
    private var bank: UInt8?
    private var standard = ControllerMIDIDecoder()
    public init() {}

    /**
     * Retires the previous pad bank before a new press. Knob banks and late releases stay independent.
     */
    public mutating func append(_ bytes: [UInt8]) -> [ControllerMPD218Event] {
        var events: [ControllerMPD218Event] = []
        for message in standard.append(bytes) {
            if message.channel == 9, message.kind == .note, message.maximum == 127,
                (36...83).contains(message.number), !message.isNoteOff
            {
                let next = (message.number - 36) / 16
                if bank != nil && bank != next { events.append(.bankChanged) }
                bank = next
            }
            events.append(.message(message))
        }
        return events
    }
}
