public enum ControllerKeyLabEvent: Equatable, Sendable {
    case message(ControllerMIDIMessage)
    case deckChanged
    case padLayerChanged
}

public struct ControllerKeyLabDecoder: Sendable {
    private var standard = ControllerMIDIDecoder()
    private var packet: [UInt8]?
    private var selected: UInt8 = 0
    private var layer: UInt8 = 22
    private var presses: [UInt8: UInt64] = [:]

    public init() {}

    /**
     * Converts the original KeyLab's reviewed first-bank controls and bounded MMC frames to native messages.
     */
    public mutating func append(_ bytes: [UInt8], timestamp: UInt64) -> [ControllerKeyLabEvent] {
        var result: [ControllerKeyLabEvent] = []
        for byte in bytes {
            if byte >= 0xF8 { continue }
            if byte == 0xF0 {
                packet = [byte]
                _ = standard.append([byte])
                continue
            }
            if let pending = packet {
                if byte == 0xF7 {
                    packet = nil
                    if pending.count == 5, pending.prefix(4) == [0xF0, 0x7F, 0x7F, 6],
                        [1, 2, 4, 5, 55].contains(pending[4])
                    {
                        result.append(.message(.init(kind: .note, channel: selected, number: pending[4], value: 127)))
                        result.append(
                            .message(
                                .init(kind: .note, channel: selected, number: pending[4], value: 0, isNoteOff: true)))
                    }
                    continue
                }
                if byte < 0x80, pending.count < 5 {
                    packet?.append(byte)
                    continue
                }
                packet = nil
            }
            for message in standard.append([byte]) { result += convert(message, timestamp: timestamp) }
        }
        return result
    }

    private mutating func convert(_ message: ControllerMIDIMessage, timestamp: UInt64) -> [ControllerKeyLabEvent] {
        if message.kind == .control, message.channel == 0 {
            let number = message.number
            if number == 118 || number == 119 {
                let primary: UInt8 = number == 118 ? 0 : 1
                if message.value > 0 {
                    guard presses[number] == nil else { return [] }
                    presses[number] = timestamp
                    return select(primary)
                }
                guard let pressed = presses.removeValue(forKey: number), timestamp >= pressed,
                    timestamp - pressed >= 275_000_000
                else { return [] }
                return select(primary + 2)
            }
            if (22...24).contains(number) {
                guard message.value == 0, layer != number else { return [] }
                layer = number
                return [.padLayerChanged]
            }
            if [0, 7, 72, 73, 75, 79, 80, 81, 82, 83, 85].contains(number) {
                return [.message(.init(kind: .control, channel: 4, number: number, value: message.value))]
            }
            if [71, 74, 76, 77, 93].contains(number) {
                return [.message(.init(kind: .control, channel: selected, number: number, value: message.value))]
            }
        }
        if message.kind == .note, message.channel == 9, (36...51).contains(message.number), layer != 24 {
            let pad = (51 - Int(message.number)) / 4 * 4 + Int(message.number) % 4
            let slot = layer == 22 ? pad - 4 : pad
            guard (0..<8).contains(slot) else { return [] }
            return [
                .message(
                    .init(
                        kind: .note, channel: selected, number: 64 + UInt8(slot),
                        value: message.value, isNoteOff: message.isNoteOff))
            ]
        }
        return []
    }

    private mutating func select(_ next: UInt8) -> [ControllerKeyLabEvent] {
        guard selected != next else { return [] }
        selected = next
        return [.deckChanged]
    }
}
