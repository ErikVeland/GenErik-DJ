public enum ControllerSR2Event: Equatable, Sendable {
    case message(ControllerMIDIMessage)
    case bankChanged(left: Bool)
}

public struct ControllerSR2Decoder: Sendable {
    private var standard = ControllerMIDIDecoder()
    private var left: UInt8?
    private var right: UInt8?

    public init() {}

    /**
     * Routes shared SR2 Load packets only after a manufacturer-defined selector identifies the target.
     */
    public mutating func append(_ bytes: [UInt8]) -> [ControllerSR2Event] {
        var result: [ControllerSR2Event] = []
        for message in standard.append(bytes) {
            if message.kind == .note, message.channel < 4 {
                if message.number == 126 { continue }
                if (85...87).contains(message.number) {
                    let isLeft = message.channel % 2 == 0
                    let current = isLeft ? left : right
                    if message.value == 0 {
                        if message.number == 87 { continue }
                        if let current,
                            (message.number == 85 && current >= 2) || (message.number == 86 && current < 2)
                        {
                            continue
                        }
                        result += select(nil, left: isLeft, force: current == nil)
                    } else {
                        let valid =
                            message.value == 127
                            && ((message.number == 85 && message.channel < 2)
                                || (message.number == 86 && message.channel >= 2))
                        result += select(valid ? message.channel : nil, left: isLeft, force: !valid)
                    }
                    continue
                }
            }
            if message.kind == .note, message.channel == 6 {
                if message.number == 88 || message.number == 89 { continue }
                if message.number == 70 || message.number == 71 {
                    guard let selected = message.number == 70 ? left : right else { continue }
                    result.append(
                        .message(
                            .init(
                                kind: .note, channel: selected, number: 126,
                                value: message.value, isNoteOff: message.isNoteOff)))
                    continue
                }
            }
            result.append(.message(message))
        }
        return result
    }

    private mutating func select(_ next: UInt8?, left isLeft: Bool, force: Bool = false) -> [ControllerSR2Event] {
        let current = isLeft ? left : right
        guard force || current != next else { return [] }
        if isLeft { left = next } else { right = next }
        return [.bankChanged(left: isLeft)]
    }
}
