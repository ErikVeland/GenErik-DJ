public enum ControllerNanoKontrol2Event: Equatable, Sendable {
    case request([UInt8])
    case modeChanged(Bool)
    case message(ControllerMIDIMessage)
}

public struct ControllerNanoKontrol2Decoder: Sendable {
    private enum Phase: Sendable { case searching, entering, ready, closed }
    private var phase: Phase = .searching
    private var globalChannel: UInt8?
    private var packet: [UInt8]?
    private var standard = ControllerMIDIDecoder()
    public static let searchRequest: [UInt8] = [0xF0, 0x42, 0x50, 0, 0x2D, 0xF7]

    public init() {}
    public var isReady: Bool { phase == .ready }
    public var exitRequest: [UInt8]? { globalChannel.map { Self.modeRequest(channel: $0, entering: false) } }

    private static func modeRequest(channel: UInt8, entering: Bool) -> [UInt8] {
        [0xF0, 0x42, 0x40 + channel, 0, 1, 0x13, 0, 0, 0, entering ? 1 : 0, 0xF7]
    }

    /**
     * Confirms the model and configured channel before accepting fixed native-mode controls.
     */
    public mutating func append(_ bytes: [UInt8]) -> [ControllerNanoKontrol2Event] {
        var result: [ControllerNanoKontrol2Event] = []
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
                    result.append(contentsOf: decode(pending + [byte]))
                    continue
                }
                if byte < 0x80, pending.count < 15 {
                    packet?.append(byte)
                    continue
                }
                packet = nil
            }
            for message in standard.append([byte]) {
                guard isReady, message.kind == .control, message.channel == 15 else { continue }
                let number = message.number
                if number < 4 || number == 18 {
                    result.append(.message(.init(kind: .control, channel: 0, number: number, value: message.value)))
                } else if (60...62).contains(number) || (64...67).contains(number) {
                    guard message.value == 0 || message.value == 127 else { continue }
                    result.append(
                        .message(
                            .init(
                                kind: .note, channel: 0, number: number, value: message.value,
                                isNoteOff: message.value == 0)))
                }
            }
        }
        return result
    }

    private mutating func decode(_ data: [UInt8]) -> [ControllerNanoKontrol2Event] {
        guard data.last == 0xF7, data.dropFirst().dropLast().allSatisfy({ $0 < 128 }) else { return [] }
        if phase == .searching, data.count == 15, data.prefix(4) == [0xF0, 0x42, 0x50, 1],
            data[4] < 16, data[5] == 0x2D, Array(data[6...9]) == [0x13, 1, 0, 0]
        {
            globalChannel = data[4]
            phase = .entering
            return [.request(Self.modeRequest(channel: data[4], entering: true))]
        }
        guard let globalChannel, data.count == 11,
            Array(data.prefix(9)) == [0xF0, 0x42, 0x40 + globalChannel, 0, 1, 0x13, 0, 0x40, 0]
        else { return [] }
        if data[9] == 3, phase == .entering {
            phase = .ready
            return [.modeChanged(true)]
        }
        if data[9] == 2, phase == .entering || phase == .ready {
            phase = .closed
            return [.modeChanged(false)]
        }
        return []
    }
}
