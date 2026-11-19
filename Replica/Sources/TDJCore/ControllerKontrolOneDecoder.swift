public enum ControllerKontrolOneEvent: Equatable, Sendable {
    case message(ControllerMIDIMessage)
    case deckChanged
}

public struct ControllerKontrolOneDecoder: Sendable {
    private var standard = ControllerMIDIDecoder()
    private var channel: UInt8?

    public init() {}

    /**
     * Preserves reviewed input addresses and marks hardware channel changes before dispatch.
     */
    public mutating func append(_ bytes: [UInt8]) -> [ControllerKontrolOneEvent] {
        var result: [ControllerKontrolOneEvent] = []
        for message in standard.append(bytes) {
            guard message.channel < 4 else { continue }
            let value: Int
            switch message.kind {
            case .note:
                guard
                    [
                        1, 2, 3, 4, 6, 7, 8, 9, 11, 12, 13, 14, 16, 17, 18, 19, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30,
                        31,
                    ].contains(message.number)
                else { continue }
                value = message.value
            case .control:
                switch message.number {
                case 32: value = message.value > 1 ? 1 : 127
                case 33: value = message.value
                case 52...55: value = message.value == 127 ? 1 : 127
                default: continue
                }
            default: continue
            }
            if channel != message.channel {
                channel = message.channel
                result.append(.deckChanged)
            }
            result.append(
                .message(
                    .init(
                        kind: message.kind, channel: message.channel, number: message.number, value: value,
                        isNoteOff: message.isNoteOff)))
        }
        return result
    }
}
