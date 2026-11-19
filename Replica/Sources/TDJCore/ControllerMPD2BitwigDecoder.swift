public enum ControllerMPD2BitwigEvent: Equatable, Sendable {
    case padBankChanged
    case controlBankChanged(UInt8)
    case message(ControllerMIDIMessage)
}

/**
 * Observes independent pad and control banks in the published MPD226/232 Bitwig input contract.
 */
public struct ControllerMPD2BitwigDecoder: Sendable {
    private var padBank: UInt8?
    private var controlChannel: UInt8?
    private var standard = ControllerMIDIDecoder()
    public init() {}

    /**
     * Keeps late releases and inactive controls from selecting an old bank.
     */
    public mutating func append(_ bytes: [UInt8]) -> [ControllerMPD2BitwigEvent] {
        var events: [ControllerMPD2BitwigEvent] = []
        for message in standard.append(bytes) {
            if message.channel == 9, message.kind == .note, message.maximum == 127,
                (36...99).contains(message.number), !message.isNoteOff
            {
                let next = (message.number - 36) / 16
                if padBank != nil && padBank != next { events.append(.padBankChanged) }
                padBank = next
            } else if isControlBankReport(message) {
                if controlChannel != nil && controlChannel != message.channel {
                    events.append(.controlBankChanged(message.channel))
                }
                controlChannel = message.channel
            }
            events.append(.message(message))
        }
        return events
    }

    private func isControlBankReport(_ message: ControllerMIDIMessage) -> Bool {
        guard message.kind == .control, message.maximum == 127, (1...3).contains(message.channel) else { return false }
        if (30...33).contains(message.number) { return message.value > 0 }
        if (40...43).contains(message.number) { return true }
        return (50...53).contains(message.number) && (message.value == 1 || message.value == 127)
    }
}
