public enum ControllerP1NanoEvent: Equatable, Sendable {
    case message(ControllerMIDIMessage)
    case controlsChanged
}

public struct ControllerP1NanoDecoder: Sendable {
    private var standard = ControllerMIDIDecoder()
    private var deck: UInt8 = 0
    private var flipped = false
    private var flipDown = false
    private var parameters: [UInt8] = [0, 0, 0, 0]

    public init() {}

    /**
     * Keeps MIDI1 selected transport, latched Flip and four knob assignments source-local.
     */
    public mutating func append(_ bytes: [UInt8]) -> [ControllerP1NanoEvent] {
        var result: [ControllerP1NanoEvent] = []
        for message in standard.append(bytes) {
            switch message.kind {
            case .note where message.channel == 0:
                if message.number == 50 {
                    let down = message.value > 0
                    if down && !flipDown {
                        flipped.toggle()
                        result.append(.controlsChanged)
                    }
                    flipDown = down
                } else if (24...27).contains(message.number) {
                    guard message.value > 0 else { continue }
                    let next = message.number - 24
                    if deck != next {
                        deck = next
                        result.append(.controlsChanged)
                    }
                } else if [86, 91, 92, 93, 94].contains(message.number) {
                    result.append(
                        .message(
                            .init(
                                kind: .note, channel: deck, number: message.number, value: message.value,
                                isNoteOff: message.isNoteOff)))
                }
            case .pitch where message.channel < 4:
                result.append(
                    .message(
                        .init(
                            kind: .pitch, channel: message.channel + (flipped ? 4 : 0), number: 0, value: message.value)
                    ))
            case .control where message.channel == 0 && (16...19).contains(message.number):
                let index = Int(message.number - 16)
                if flipped {
                    parameters[index] = (parameters[index] + (message.value < 64 ? 1 : 4)) % 5
                    result.append(.controlsChanged)
                } else {
                    result.append(
                        .message(
                            .init(
                                kind: .control, channel: UInt8(index), number: 16 + parameters[index],
                                value: message.value)))
                }
            default: continue
            }
        }
        return result
    }
}
