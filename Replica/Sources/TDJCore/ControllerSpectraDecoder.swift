public enum ControllerSpectraEvent: Equatable, Sendable {
    case message(ControllerMIDIMessage)
    case deckChanged
    case bankChanged
}

public struct ControllerSpectraDecoder: Sendable {
    private var standard = ControllerMIDIDecoder()
    private var deck: UInt8 = 0
    private var bank: UInt8? = 1

    public init() {}

    /**
     * Separates fixed filter switches, selected-deck cues and physical bank boundaries.
     */
    public mutating func append(_ bytes: [UInt8]) -> [ControllerSpectraEvent] {
        var result: [ControllerSpectraEvent] = []
        for message in standard.append(bytes) {
            guard message.kind == .note else { continue }
            if message.channel == 3, message.number < 4 {
                if message.value > 0 {
                    if bank != message.number {
                        bank = message.number
                        result.append(.bankChanged)
                    }
                } else if bank == message.number {
                    bank = nil
                    result.append(.bankChanged)
                }
                continue
            }
            guard message.channel == 2 else { continue }
            if (52...55).contains(message.number) || (84...87).contains(message.number) {
                guard message.value > 0 else { continue }
                let next = (message.number - 52) % 32
                if deck != next {
                    deck = next
                    result.append(.deckChanged)
                }
                continue
            }
            if (36...39).contains(message.number) {
                result.append(
                    .message(
                        .init(
                            kind: .note, channel: 4, number: message.number, value: message.value,
                            isNoteOff: message.isNoteOff)))
            } else if (56...63).contains(message.number) {
                let slot = message.number >= 60 ? message.number - 60 : message.number - 52
                result.append(
                    .message(
                        .init(
                            kind: .note, channel: deck, number: 64 + slot, value: message.value,
                            isNoteOff: message.isNoteOff)))
            }
        }
        return result
    }
}
