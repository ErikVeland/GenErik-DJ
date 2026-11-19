/**
 * Gates the independently documented Launch Control 3 and XL3 DAW surface reports.
 */
public struct ControllerLaunchControlDAWDecoder: Sendable {
    private var standard = ControllerMIDIDecoder()
    private var mode: Int = 2
    public var isReady: Bool { mode == 1 || mode == 2 }

    /**
     * Starts after the host selects DAW Control. The protocol does not promise a setup acknowledgement.
     */
    public init() {}

    /**
     * Retires held actions on mode changes and rejects custom-mode traffic before binding lookup.
     */
    public mutating func append(_ bytes: [UInt8]) -> [ControllerKorgNativeEvent] {
        var result: [ControllerKorgNativeEvent] = []
        for message in standard.append(bytes) {
            guard message.kind == .control, message.maximum == 127 else { continue }
            if message.channel == 6, message.number == 30 {
                if message.value != mode {
                    mode = message.value
                    result.append(.modeChanged(isReady))
                }
            } else if isReady {
                if message.channel == 0,
                    (37...52).contains(message.number) || [102, 103, 104, 106, 107].contains(message.number)
                {
                    guard message.value == 0 || message.value == 127 else { continue }
                    result.append(
                        .message(
                            .init(
                                kind: .note, channel: 0, number: message.number, value: message.value,
                                isNoteOff: message.value == 0)))
                } else {
                    result.append(.message(message))
                }
            }
        }
        return result
    }
}
