/**
 * Keeps standalone decks outside software control until both decks explicitly enter PC mode.
 */
public struct ControllerXDJANDecoder: Sendable {
    private var standard = ControllerMIDIDecoder()
    private var pcDecks: Set<UInt8> = []
    private enum Phase: Sendable { case waiting, requesting, ready, hardware }
    private var phase: Phase = .waiting
    public static let mixerRequest: [UInt8] = [0xB4, 101, 0]

    public init() {}
    public var isReady: Bool { phase == .ready }
    public var pendingRequest: [UInt8]? { phase == .requesting && pcDecks.count == 2 ? Self.mixerRequest : nil }

    /**
     * Confirms the local send result, not a device acknowledgement or an audio route.
     */
    public mutating func didSendPendingRequest(_ bytes: [UInt8]) -> Bool {
        guard pendingRequest == bytes else { return false }
        phase = .ready
        return true
    }

    public mutating func append(_ bytes: [UInt8]) -> [ControllerKorgNativeEvent] {
        var result: [ControllerKorgNativeEvent] = []
        for message in standard.append(bytes) {
            if message.kind == .control && message.number == 100 && message.channel < 2 {
                let wasReady = isReady
                if message.value == 127 {
                    pcDecks.insert(message.channel)
                    if phase == .waiting && pcDecks.count == 2 { phase = .requesting }
                } else {
                    pcDecks.remove(message.channel)
                    phase = .waiting
                }
                if wasReady && !isReady { result.append(.modeChanged(false)) }
                continue
            }
            if message.kind == .control && message.channel == 4 && message.number == 101 {
                let wasReady = isReady
                if phase == .requesting && message.value != 0 { phase = .hardware }
                if phase == .ready || phase == .hardware {
                    phase = message.value == 0 && pcDecks.count == 2 ? .ready : .hardware
                }
                if wasReady != isReady { result.append(.modeChanged(isReady)) }
                continue
            }
            if isReady { result.append(.message(message)) }
        }
        return result
    }
}
