public struct ControllerNanoKontrolSceneDecoder: Sendable {
    private enum Phase: Sendable { case searching, waiting, ready, closed }
    private struct Key: Hashable, Sendable {
        let note: Bool
        let channel: UInt8
        let number: UInt8
    }
    private struct Assignment: Sendable {
        let key: Key
        let logical: UInt8?
        let low: UInt8
        let high: UInt8
        let button: Bool
        let toggle: Bool
    }
    public static let searchRequest: [UInt8] = [0xF0, 0x42, 0x50, 0, 0x2D, 0xF7]
    private var phase: Phase = .searching
    private var globalChannel: UInt8?
    private var refreshNeeded = false
    private var assignments: [Key: Assignment] = [:]
    private var packet: [UInt8]?
    private var droppingPacket = false
    private var standard = ControllerMIDIDecoder()

    public init() {}
    public var isReady: Bool { phase == .ready }
    public var mappedControlCount: Int { assignments.count }

    /**
     * Reads only the original model's bounded scene replies and current physical assignments.
     */
    public mutating func append(_ bytes: [UInt8]) -> [ControllerKorgNativeEvent] {
        var events: [ControllerKorgNativeEvent] = []
        for byte in bytes {
            if byte >= 0xF8 { continue }
            if byte == 0xF0 {
                packet = [byte]
                droppingPacket = false
                _ = standard.append([byte])
                continue
            }
            if let pending = packet {
                if byte == 0xF7 {
                    packet = nil
                    _ = standard.append([byte])
                    events += decode(pending + [byte])
                    continue
                }
                if byte < 128, pending.count < 306 {
                    packet?.append(byte)
                    continue
                }
                packet = nil
                if byte < 128 { droppingPacket = true; continue }
            }
            if droppingPacket {
                if byte == 0xF7 { droppingPacket = false; _ = standard.append([byte]); continue }
                if byte < 128 { continue }
                droppingPacket = false
            }
            for message in standard.append([byte]) {
                guard isReady, message.maximum == 127,
                    message.kind == .note || message.kind == .control,
                    let entry = assignments[
                        .init(note: message.kind == .note, channel: message.channel, number: message.number)],
                    let logical = entry.logical
                else { continue }
                if entry.button {
                    let pressed: Bool
                    if message.kind == .note, message.isNoteOff {
                        pressed = false
                    } else if message.value == Int(entry.low) {
                        pressed = false
                    } else if message.value == Int(entry.high) {
                        pressed = true
                    } else {
                        continue
                    }
                    events.append(
                        .message(
                            .init(
                                kind: entry.toggle ? .control : .note, channel: 0,
                                number: (entry.toggle ? 64 : 32) + logical,
                                value: pressed ? 127 : 0, isNoteOff: !entry.toggle && !pressed)))
                } else {
                    let low = Int(entry.low), high = Int(entry.high)
                    guard (min(low, high)...max(low, high)).contains(message.value) else { continue }
                    events.append(
                        .message(
                            .init(
                                kind: .control, channel: 0, number: logical, value: abs(message.value - low),
                                maximum: abs(high - low))))
                }
            }
        }
        return events
    }

    private var sceneRequest: [UInt8] {
        [0xF0, 0x42, 0x40 + (globalChannel ?? 0), 0, 1, 4, 0, 0x1F, 0x10, 0, 0xF7]
    }

    private mutating func invalidateScene() -> [ControllerKorgNativeEvent] {
        assignments.removeAll()
        if phase == .waiting {
            refreshNeeded = true
            return []
        }
        guard phase == .ready else { return [] }
        phase = .waiting
        return [.modeChanged(false), .request(sceneRequest)]
    }

    private mutating func decode(_ data: [UInt8]) -> [ControllerKorgNativeEvent] {
        guard data.last == 0xF7, data.dropFirst().dropLast().allSatisfy({ $0 < 128 }) else { return [] }
        if phase == .searching, data.count == 15, data.prefix(4) == [0xF0, 0x42, 0x50, 1],
            data[4] < 16, data[5] == 0x2D, Array(data[6...9]) == [4, 1, 0, 0]
        {
            globalChannel = data[4]
            phase = .waiting
            return [.request(sceneRequest)]
        }
        guard let channel = globalChannel,
            Array(data.prefix(7)) == [0xF0, 0x42, 0x40 + channel, 0, 1, 4, 0]
        else { return [] }
        if data.count == 11, data[7] == 0x5F {
            if data[8] == 0x4F, data[9] < 4 { return invalidateScene() }
            if (data[8] == 0x23 || data[8] == 0x21), data[9] == 0 { return invalidateScene() }
            if (data[8] == 0x24 || data[8] == 0x22), data[9] == 0, phase == .waiting || phase == .ready {
                phase = .closed
                assignments.removeAll()
                return [.modeChanged(false)]
            }
            return []
        }
        guard phase == .waiting, data.count == 307,
            Array(data[7...12]) == [0x7F, 0x7F, 2, 2, 0x26, 0x40],
            let decoded = Self.unpack(Array(data[13..<306])), let entries = Self.sceneAssignments(decoded)
        else { return [] }
        if refreshNeeded {
            refreshNeeded = false
            return [.request(sceneRequest)]
        }
        let counts = entries.reduce(into: [Key: Int]()) { $0[$1.key, default: 0] += 1 }
        assignments = Dictionary(
            uniqueKeysWithValues: entries.compactMap {
                $0.logical != nil && counts[$0.key] == 1 ? ($0.key, $0) : nil
            })
        phase = .ready
        return [.modeChanged(true)]
    }

    private static func unpack(_ bytes: [UInt8]) -> [UInt8]? {
        guard bytes.count == 293 else { return nil }
        var result: [UInt8] = []
        var index = 0
        while index < bytes.count {
            let count = min(7, bytes.count - index - 1)
            let mask = bytes[index]
            guard count > 0, mask < (1 << count) else { return nil }
            for bit in 0..<count { result.append(bytes[index + 1 + bit] | (((mask >> bit) & 1) << 7)) }
            index += count + 1
        }
        return result.count == 256 ? result : nil
    }

    /**
     * Counts all assigned wires, including unused controls, before enabling unambiguous mixer controls.
     */
    private static func sceneAssignments(_ data: [UInt8]) -> [Assignment]? {
        guard data.count == 256, data[12] < 16 else { return nil }
        var entries: [Assignment] = []
        func channel(_ value: UInt8) -> UInt8 { value < 16 ? value : data[12] }
        for block in 0..<9 {
            let base = 16 + block * 23
            let wire = channel(data[base])
            for (offset, logical) in [
                (1, block < 4 ? UInt8(block) : block < 8 ? UInt8(12 + block - 4) : nil),
                (5, block < 4 ? UInt8(4 + block) : block < 8 ? UInt8(8 + block - 4) : nil),
            ] {
                guard data[base + offset] <= 1,
                    data[(base + offset + 1)...(base + offset + 3)].allSatisfy({ $0 < 128 })
                else { return nil }
                if data[base + offset] == 1 {
                    let low = data[base + offset + 2], high = data[base + offset + 3]
                    entries.append(
                        .init(
                            key: .init(note: false, channel: wire, number: data[base + offset + 1]),
                            logical: low == high ? nil : logical, low: low, high: high, button: false, toggle: false))
                }
            }
            for button in 0..<2 {
                let offset = base + 9 + button * 7
                guard data[offset] <= 2, data[(offset + 1)...(offset + 5)].allSatisfy({ $0 < 128 }),
                    data[offset + 6] <= 1
                else { return nil }
                if data[offset] == 0 { continue }
                let note = data[offset] == 2, low = data[offset + 2], high = data[offset + 3]
                let usable =
                    block < 4 && low != high && (!note || high > 0)
                    && data[offset + 4] == 0 && data[offset + 5] == 0
                entries.append(
                    .init(
                        key: .init(note: note, channel: wire, number: data[offset + 1]),
                        logical: usable ? UInt8(block + button * 4) : nil,
                        low: low, high: high, button: true, toggle: data[offset + 6] == 1))
            }
        }
        for control in 0..<6 {
            let base = 225 + control * 5
            guard data[base] <= 2, data[base + 1] < 128, data[base + 2] <= 12,
                data[base + 3] < 128, data[base + 4] <= 1
            else { return nil }
            if data[base] == 1 {
                entries.append(
                    .init(
                        key: .init(note: false, channel: channel(data[224]), number: data[base + 1]),
                        logical: nil, low: 0, high: 127, button: true, toggle: false))
            }
        }
        return entries
    }
}
