public enum ControllerLegacyUSBPlayerEvent: Equatable, Sendable {
    case controlsChanged(UInt8)
    case message(ControllerMIDIMessage)
}

/**
 * Observes independently reviewed VERSADECK and DMC-2000 normal/Shift wire families.
 */
public struct ControllerLegacyUSBPlayerDecoder: Sendable {
    private var layers: [UInt8: Bool] = [:]
    private var standard = ControllerMIDIDecoder()
    public init() {}

    /**
     * Clears only the changed channel before its next control. Late releases cannot select a layer.
     */
    public mutating func append(_ bytes: [UInt8]) -> [ControllerLegacyUSBPlayerEvent] {
        var events: [ControllerLegacyUSBPlayerEvent] = []
        for message in standard.append(bytes) {
            if let shifted = layer(message) {
                if let previous = layers[message.channel], previous != shifted {
                    events.append(.controlsChanged(message.channel))
                }
                layers[message.channel] = shifted
            }
            events.append(.message(message))
        }
        return events
    }

    private func layer(_ message: ControllerMIDIMessage) -> Bool? {
        guard message.channel <= 2, message.maximum == 127 else { return nil }
        let normal: [UInt8]
        if message.kind == .note, message.channel != 1, !message.isNoteOff {
            normal = [1, 2, 3, 4, 5, 8, 9, 10, 11, 13, 29, 31, 32, 34, 35]
        } else if message.kind == .control {
            switch message.channel {
            case 0: normal = [16, 17, 18, 19, 20, 22, 23]
            case 2: normal = [32, 33, 34, 35, 36, 38, 39]
            default: normal = [48, 49, 51, 52]
            }
        } else {
            return nil
        }
        if normal.contains(message.number) { return false }
        if normal.contains(where: { $0 + 63 == message.number }) { return true }
        return nil
    }
}
