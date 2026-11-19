/**
 * Gates the independently qualified APC64 Session surface after identity and DAW setup.
 */
public struct ControllerAPC64Decoder: Sendable {
    private var standard = ControllerMIDIDecoder()
    private var packet: [UInt8]?
    private var identified = false
    private var mode: UInt8 = 0
    public private(set) var isReady = false

    public init() {}

    public static func dawRequest(active: Bool) -> [UInt8] {
        [0xF0, 0x47, 0, 0x53, 0x1C, 0, 1, active ? 1 : 0, 0xF7]
    }

    public var pendingRequest: [UInt8]? {
        identified && mode == 0 && !isReady ? Self.dawRequest(active: true) : nil
    }

    /**
     * Confirms the local send result. The source does not promise a separate DAW acknowledgement.
     */
    public mutating func didSendPendingRequest(_ bytes: [UInt8]) -> Bool {
        guard pendingRequest == bytes else { return false }
        isReady = true
        return true
    }

    /**
     * Bounds SysEx frames and keeps notes, strips and Shift inside the qualified Session footprint.
     */
    public mutating func append(_ bytes: [UInt8]) -> [ControllerKorgNativeEvent] {
        var events: [ControllerKorgNativeEvent] = []
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
                    _ = standard.append([byte])
                    events.append(contentsOf: decode(pending + [byte]))
                    continue
                }
                if byte < 0x80, pending.count < 96 {
                    packet?.append(byte)
                    continue
                }
                packet = nil
            }
            for message in standard.append([byte]) where isReady {
                let grid = message.kind == .note && message.channel == 6 && message.number < 64
                let strip = message.kind == .pitch && message.channel < 8
                let shift = message.kind == .note && message.channel == 0 && message.number == 120
                if grid || strip || shift { events.append(.message(message)) }
            }
        }
        return events
    }

    private mutating func decode(_ bytes: [UInt8]) -> [ControllerKorgNativeEvent] {
        guard bytes.last == 0xF7, bytes.dropFirst().dropLast().allSatisfy({ $0 < 128 }) else { return [] }
        if bytes.count >= 15,
            Array(bytes.prefix(10)) == [0xF0, 0x7E, 0, 6, 2, 0x47, 0x53, 0, 0x19, 1]
        {
            identified = true
            return []
        }
        guard bytes.count == 9, Array(bytes.prefix(7)) == [0xF0, 0x47, 0, 0x53, 0x19, 0, 1], bytes[7] != mode else {
            return []
        }
        mode = bytes[7]
        let wasReady = isReady
        isReady = false
        var events: [ControllerKorgNativeEvent] = wasReady ? [.modeChanged(false)] : []
        if identified && mode != 0 { events.append(.request(Self.dawRequest(active: false))) }
        return events
    }
}
