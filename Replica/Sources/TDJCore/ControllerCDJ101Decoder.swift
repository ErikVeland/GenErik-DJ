public struct ControllerCDJ101Decoder: Sendable {
    private var standard = ControllerMIDIDecoder()
    private var pushes: [UInt8: UInt64] = [:]

    public init() {}

    /**
     * Normalises CDJ-101 browsing and emits logical Load after an owned short push, using callback arrival time.
     */
    public mutating func append(_ bytes: [UInt8], timestamp: UInt64) -> [ControllerMIDIMessage] {
        var result: [ControllerMIDIMessage] = []
        for message in standard.append(bytes) {
            guard message.channel < 2 else { continue }
            switch message.kind {
            case .pitch:
                result.append(message)
            case .control:
                if message.number == 56 {
                    result.append(
                        .init(
                            kind: .control, channel: message.channel, number: 56,
                            value: message.value == 65 ? 1 : 127))
                } else if message.number == 53 || message.number == 54 {
                    result.append(message)
                }
            case .note:
                guard [31, 32, 42, 43].contains(message.number) else { continue }
                result.append(message)
                guard message.number == 31 else { continue }
                if message.value > 0 {
                    if pushes[message.channel] == nil { pushes[message.channel] = timestamp }
                } else if let pressed = pushes.removeValue(forKey: message.channel), timestamp >= pressed,
                    timestamp - pressed < 200_000_000
                {
                    result.append(.init(kind: .note, channel: message.channel, number: 126, value: 127))
                    result.append(.init(kind: .note, channel: message.channel, number: 126, value: 0, isNoteOff: true))
                }
            default: continue
            }
        }
        return result
    }
}
