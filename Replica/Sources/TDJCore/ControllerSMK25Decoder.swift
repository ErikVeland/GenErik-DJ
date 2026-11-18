import Foundation

public enum ControllerSMK25Event: Equatable, Sendable {
    case message(ControllerMIDIMessage)
    case deckChanged
}

public struct ControllerSMK25Decoder: Sendable {
    private var selected: UInt8 = 0
    private var packet: [UInt8]?
    private var standard = ControllerMIDIDecoder()

    public init() {}

    /**
     * Converts source-local SMK-25 II input to ordered native messages without retaining oversized SysEx.
     */
    public mutating func append(_ bytes: [UInt8]) -> [ControllerSMK25Event] {
        var result: [ControllerSMK25Event] = []
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
                    if let event = decode(pending + [byte]) { result.append(event) }
                    continue
                }
                if byte < 0x80, pending.count < 6 {
                    packet?.append(byte)
                    continue
                }
                packet = nil
            }
            for message in standard.append([byte]) {
                if let converted = convert(message) { result.append(.message(converted)) }
            }
        }
        return result
    }

    private mutating func decode(_ data: [UInt8]) -> ControllerSMK25Event? {
        guard data.count == 7, data.prefix(3) == [0xF0, 0x35, 0x59], data.last == 0xF7,
            data.dropFirst().dropLast().allSatisfy({ $0 < 128 })
        else { return nil }
        if data[3] == 0x10 {
            let note = data[4]
            let value = data[5]
            if note == 46 || note == 47 {
                let next: UInt8 = note == 46 ? 0 : 1
                guard value == 0, selected != next else { return nil }
                selected = next
                return .deckChanged
            }
            guard note < 8 || [76, 91, 92, 93, 94, 95].contains(note) else { return nil }
            return .message(
                .init(kind: .note, channel: selected, number: note, value: Int(value), isNoteOff: value == 0))
        }
        guard (0x60...0x67).contains(data[3]) else { return nil }
        return convert(.init(kind: .control, channel: 0, number: 30 + data[3] - 0x60, value: Int(data[5])))
            .map { .message($0) }
    }

    private func convert(_ message: ControllerMIDIMessage) -> ControllerMIDIMessage? {
        guard message.channel == 0 else { return nil }
        if message.kind == .pitch {
            return .init(kind: .pitch, channel: selected, number: 0, value: message.value)
        }
        guard message.kind == .control, message.number == 1 || (30...37).contains(message.number) else { return nil }
        return .init(
            kind: .control, channel: message.number < 35 ? selected : 0,
            number: message.number, value: message.value)
    }
}
