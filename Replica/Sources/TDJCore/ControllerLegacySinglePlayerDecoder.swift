public enum ControllerLegacySinglePlayerEvent: Equatable, Sendable {
    case controlsChanged
    case message(ControllerMIDIMessage)
}

/**
 * Observes the independently documented CDX6, MPCD-X3, CMP.800 and DMC-1000 defaults.
 */
public struct ControllerLegacySinglePlayerDecoder: Sendable {
    private var channel: UInt8?
    private var layers: [UInt8: Bool] = [:]
    private var standard = ControllerMIDIDecoder()
    public init() {}

    /**
     * Retires this unit's controls before a bank, Shift family or wheel-mode change.
     */
    public mutating func append(_ bytes: [UInt8]) -> [ControllerLegacySinglePlayerEvent] {
        var events: [ControllerLegacySinglePlayerEvent] = []
        for message in standard.append(bytes) {
            if message.channel <= 1, message.kind == .note,
                message.number == 69 || (message.number == 36 && !message.isNoteOff)
            {
                events.append(.controlsChanged)
                layers.removeAll()
            } else if let shifted = layer(message) {
                if (channel != nil && channel != message.channel)
                    || (layers[message.channel] != nil && layers[message.channel] != shifted)
                {
                    events.append(.controlsChanged)
                }
                channel = message.channel
                layers[message.channel] = shifted
            }
            events.append(.message(message))
        }
        return events
    }

    private func layer(_ message: ControllerMIDIMessage) -> Bool? {
        guard message.channel <= 1 else { return nil }
        if message.kind == .pitch { return false }
        guard message.maximum == 127 else { return nil }
        let normal: [UInt8]
        if message.kind == .note, !message.isNoteOff {
            normal = [2, 3, 4, 9, 19, 23, 29, 30, 37, 43, 46, 48, 49, 50, 51, 52, 53, 54]
        } else if message.kind == .control {
            normal = [49, 51, 53]
        } else {
            return nil
        }
        if normal.contains(message.number) { return false }
        if normal.contains(where: { $0 + 63 == message.number }) { return true }
        return nil
    }
}
