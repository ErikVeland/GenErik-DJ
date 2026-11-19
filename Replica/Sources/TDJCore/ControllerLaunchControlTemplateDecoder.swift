/**
 * Reads independently qualified Launch Control User-template assignments without writing stored data.
 */
public struct ControllerLaunchControlTemplateDecoder: Sendable {
    public enum Model: UInt8, Sendable {
        case original = 10, xl = 17
        fileprivate var replySize: Int { self == .original ? 177 : 417 }
        fileprivate var continuousCount: Int { self == .original ? 16 : 32 }
        fileprivate var recordCount: Int { self == .original ? 28 : 56 }
    }
    private let model: Model
    private struct Key: Hashable, Sendable {
        let note: Bool
        let channel: UInt8
        let number: UInt8
    }
    private struct Assignment: Sendable {
        let key: Key
        let logical: UInt8
        let low: UInt8
        let high: UInt8
        let button: Bool
        let usable: Bool
    }
    private var header: [UInt8] { [240, 0, 32, 41, 2, model.rawValue] }
    public static let initialRequest: [UInt8] = [240, 0, 32, 41, 2, 10, 121, 0, 247]
    private var selected: UInt8 = 0
    private var waiting = true
    private var assignments: [Key: Assignment] = [:]
    private var packet: [UInt8]?
    private var droppingPacket = false
    private var standard = ControllerMIDIDecoder()
    public private(set) var isReady = false
    public var mappedControlCount: Int { assignments.count }

    public init(model: Model = .original) { self.model = model }

    /**
     * Reads only bounded replies for the selected template and normalises unambiguous physical controls.
     */
    public mutating func append(_ bytes: [UInt8]) -> [ControllerKorgNativeEvent] {
        var result: [ControllerKorgNativeEvent] = []
        for byte in bytes {
            if byte >= 248 { continue }
            if byte == 240 {
                packet = [byte]
                droppingPacket = false
                _ = standard.append([byte])
                continue
            }
            if let pending = packet {
                if byte == 247 {
                    packet = nil
                    _ = standard.append([byte])
                    result += decode(pending + [byte])
                    continue
                }
                if byte < 128, pending.count < model.replySize - 1 {
                    packet?.append(byte)
                    continue
                }
                packet = nil
                if byte < 128 { droppingPacket = true; continue }
            }
            if droppingPacket {
                if byte == 247 { droppingPacket = false; _ = standard.append([byte]); continue }
                if byte < 128 { continue }
                droppingPacket = false
            }
            for message in standard.append([byte]) {
                guard isReady, message.maximum == 127,
                    message.kind == .note || message.kind == .control,
                    let entry = assignments[
                        .init(note: message.kind == .note, channel: message.channel, number: message.number)]
                else { continue }
                if entry.button {
                    let pressed: Bool
                    if message.isNoteOff {
                        pressed = false
                    } else if message.value == Int(entry.low) {
                        pressed = false
                    } else if message.value == Int(entry.high) {
                        pressed = true
                    } else {
                        continue
                    }
                    result.append(
                        .message(
                            .init(
                                kind: .note, channel: 0, number: entry.logical + 16, value: pressed ? 127 : 0,
                                isNoteOff: !pressed)))
                } else {
                    let low = Int(entry.low), high = Int(entry.high)
                    guard (min(low, high)...max(low, high)).contains(message.value) else { continue }
                    result.append(
                        .message(
                            .init(
                                kind: .control, channel: 0, number: entry.logical, value: abs(message.value - low),
                                maximum: abs(high - low))))
                }
            }
        }
        return result
    }

    private mutating func decode(_ bytes: [UInt8]) -> [ControllerKorgNativeEvent] {
        guard bytes.last == 247, Array(bytes.prefix(6)) == header,
            bytes.dropFirst().dropLast().allSatisfy({ $0 < 128 }), bytes.count >= 9,
            bytes[6] == 119, bytes[7] < 16
        else { return [] }
        let template = bytes[7]
        if bytes.count == 9 {
            guard selected != template else { return [] }
            selected = template
            waiting = template < 8
            isReady = false
            assignments.removeAll()
            return [.modeChanged(false)] + (waiting ? [.request(header + [121, template, 247])] : [])
        }
        guard waiting, selected < 8, template == selected, bytes.count == model.replySize,
            let entries = entries(Array(bytes[8..<(model.replySize - 1)]))
        else { return [] }
        let counts = entries.reduce(into: [Key: Int]()) { $0[$1.key, default: 0] += 1 }
        assignments = Dictionary(
            uniqueKeysWithValues: entries.compactMap { $0.usable && counts[$0.key] == 1 ? ($0.key, $0) : nil })
        waiting = false
        isReady = true
        return [.modeChanged(true)]
    }

    /**
     * Counts inactive wires too, so duplicate or unsupported assignments cannot trigger a different control.
     */
    private func entries(_ data: [UInt8]) -> [Assignment]? {
        guard data.count == model.replySize - 9 else { return nil }
        var result: [Assignment] = []
        for index in 0..<model.recordCount {
            let base = index * 6
            let button = index >= model.continuousCount
            let low = data[base + 2], high = data[base + 3]
            let channel = data[base + (button ? 5 : 4)]
            guard channel < 16 else { return nil }
            if button {
                guard data[base] <= 1, data[base + 4] <= 1 else { return nil }
            } else {
                guard data[base + 1] == 0, data[base + 5] == 0 else { return nil }
            }
            let note = button && data[base] == 0
            result.append(
                .init(
                    key: .init(note: note, channel: channel, number: data[base + (button ? 1 : 0)]),
                    logical: UInt8(index), low: low, high: high, button: button,
                    usable: low != high && (!button || (data[base + 4] == 0 && (!note || high > 0)))))
        }
        return result
    }
}
