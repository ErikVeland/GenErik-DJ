import Foundation

public struct ControllerMIDIMessage: Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case note, control, pitch, polyPressure, pressure, program
        case registeredController, assignableController
        case relativeRegisteredController, relativeAssignableController
        case perNoteRegisteredController, perNoteAssignableController, perNotePitch
        public var isRelativeController: Bool {
            self == .relativeRegisteredController || self == .relativeAssignableController
        }
    }
    public let kind: Kind
    public let group: UInt8
    public let channel: UInt8
    public let number: UInt8
    public let value: Int
    public let maximum: Int
    public let parameter: UInt16?
    public let noteNumber: UInt8?
    public let isNoteOff: Bool
    public var normalized: Double { Double(value) / Double(maximum) }
    public init(kind: Kind, group: UInt8 = 0, channel: UInt8, number: UInt8, value: Int,
                maximum: Int? = nil, parameter: UInt16? = nil, noteNumber: UInt8? = nil,
                isNoteOff: Bool = false) {
        self.kind = kind
        self.group = group
        self.channel = channel
        self.number = number
        self.value = value
        self.maximum = maximum ?? (kind == .pitch ? 16383 : 127)
        self.parameter = parameter
        self.noteNumber = noteNumber
        self.isNoteOff = isNoteOff
    }
}

/// Decodes bounded MIDI 1.0 and MIDI 2.0 channel voice UMPs for the shared action path.
public enum ControllerMIDIUMPDecoder {
    public static func decode(_ words: [UInt32]) -> [ControllerMIDIMessage]? {
        guard words.count <= 4096 else { return nil }
        var messages: [ControllerMIDIMessage] = []
        var index = 0
        while index < words.count {
            let first = words[index]
            let type = UInt8(first >> 28)
            let wordCount: Int
            switch type {
            case 0x0, 0x1, 0x2, 0x6, 0x7, 0x8, 0x9, 0xa, 0xb, 0xc, 0xe: wordCount = 1
            case 0x3, 0x4: wordCount = 2
            case 0x5, 0xd, 0xf: wordCount = 4
            default: return nil
            }
            guard index <= words.count - wordCount else { return nil }
            let group = UInt8((first >> 24) & 0x0f)
            if type == 0x2, let message = midi1Message(first, group: group) { messages.append(message) }
            if type == 0x4, let message = midi2Message(first, words[index + 1], group: group) { messages.append(message) }
            guard messages.count <= 256 else { return nil }
            index += wordCount
        }
        return messages
    }

    private static func midi1Message(_ word: UInt32, group: UInt8) -> ControllerMIDIMessage? {
        let status = UInt8((word >> 16) & 0xff)
        let command = status & 0xf0
        let channel = status & 0x0f
        let number = UInt8((word >> 8) & 0x7f)
        let value = UInt8(word & 0x7f)
        switch command {
        case 0x80, 0x90:
            let isNoteOff = command == 0x80 || value == 0
            return .init(kind: .note, group: group, channel: channel, number: number,
                         value: isNoteOff ? 0 : Int(value), isNoteOff: isNoteOff)
        case 0xa0: return .init(kind: .polyPressure, group: group, channel: channel, number: number, value: Int(value))
        case 0xb0: return .init(kind: .control, group: group, channel: channel, number: number, value: Int(value))
        case 0xc0: return .init(kind: .program, group: group, channel: channel, number: number, value: 127)
        case 0xd0: return .init(kind: .pressure, group: group, channel: channel, number: 0, value: Int(number))
        case 0xe0: return .init(kind: .pitch, group: group, channel: channel, number: 0,
                                value: Int(UInt8((word >> 8) & 0x7f)) | Int(value) << 7)
        default: return nil
        }
    }

    private static func midi2Message(_ first: UInt32, _ second: UInt32, group: UInt8) -> ControllerMIDIMessage? {
        let status = UInt8((first >> 20) & 0x0f)
        let channel = UInt8((first >> 16) & 0x0f)
        let number = UInt8((first >> 8) & 0x7f)
        let value = Int(second)
        switch status {
        case 0x0, 0x1:
            let note = UInt8((first >> 8) & 0x7f)
            let number = UInt8(first & 0xff)
            return .init(kind: status == 0 ? .perNoteRegisteredController : .perNoteAssignableController,
                         group: group, channel: channel, number: number, value: value,
                         maximum: Int(UInt32.max), noteNumber: note)
        case 0x2, 0x3, 0x4, 0x5:
            let bank = UInt16((first >> 8) & 0x7f)
            let index = UInt16(first & 0x7f)
            let parameter = bank << 7 | index
            let kind: ControllerMIDIMessage.Kind
            switch status {
            case 0x2: kind = .registeredController
            case 0x3: kind = .assignableController
            case 0x4: kind = .relativeRegisteredController
            default: kind = .relativeAssignableController
            }
            let data = kind.isRelativeController ? Int(Int32(bitPattern: second)) : value
            return .init(kind: kind, group: group, channel: channel, number: UInt8(index), value: data,
                         maximum: kind.isRelativeController ? Int(Int32.max) : Int(UInt32.max), parameter: parameter)
        case 0x6:
            let note = UInt8((first >> 8) & 0x7f)
            return .init(kind: .perNotePitch, group: group, channel: channel, number: note,
                         value: value, maximum: Int(UInt32.max), noteNumber: note)
        case 0x8: return .init(kind: .note, group: group, channel: channel, number: number,
                               value: 0, maximum: 65535, isNoteOff: true)
        case 0x9: return .init(kind: .note, group: group, channel: channel, number: number,
                               value: Int((second >> 16) & 0xffff), maximum: 65535)
        case 0xa: return .init(kind: .polyPressure, group: group, channel: channel, number: number, value: value, maximum: Int(UInt32.max))
        case 0xb: return .init(kind: .control, group: group, channel: channel, number: number, value: value, maximum: Int(UInt32.max))
        case 0xc:
            let program = UInt8((second >> 24) & 0x7f)
            let bank: UInt16? = first & 0x01 == 0 ? nil
                : UInt16((second >> 8) & 0x7f) << 7 | UInt16(second & 0x7f)
            return .init(kind: .program, group: group, channel: channel, number: program,
                         value: 127, parameter: bank)
        case 0xd: return .init(kind: .pressure, group: group, channel: channel, number: 0, value: value, maximum: Int(UInt32.max))
        case 0xe: return .init(kind: .pitch, group: group, channel: channel, number: 0, value: value, maximum: Int(UInt32.max))
        default: return nil
        }
    }
}

/// One decoder belongs to one input. MIDI messages can span packet boundaries.
public struct ControllerMIDIDecoder: Sendable {
    private var status: UInt8?
    private var data: [UInt8] = []
    public init() {}
    public mutating func append(_ bytes: [UInt8]) -> [ControllerMIDIMessage] {
        var messages: [ControllerMIDIMessage] = []
        for byte in bytes {
            if byte >= 0xf8 { continue }
            if byte >= 0x80 {
                status = byte < 0xf0 ? byte : nil
                data.removeAll(keepingCapacity: true)
                continue
            }
            guard let status else { continue }
            data.append(byte)
            let type = status & 0xf0
            let count = type == 0xc0 || type == 0xd0 ? 1 : 2
            guard data.count == count else { continue }
            let channel = status & 0x0f
            switch type {
            case 0x80, 0x90:
                let isNoteOff = type == 0x80 || data[1] == 0
                messages.append(.init(kind: .note, channel: channel, number: data[0],
                                      value: isNoteOff ? 0 : Int(data[1]), isNoteOff: isNoteOff))
            case 0xb0:
                messages.append(.init(kind: .control, channel: channel, number: data[0], value: Int(data[1])))
            case 0xe0:
                messages.append(.init(kind: .pitch, channel: channel, number: 0, value: Int(data[0]) | Int(data[1]) << 7))
            case 0xa0:
                messages.append(.init(kind: .polyPressure, channel: channel, number: data[0], value: Int(data[1])))
            case 0xd0:
                messages.append(.init(kind: .pressure, channel: channel, number: 0, value: Int(data[0])))
            case 0xc0:
                messages.append(.init(kind: .program, channel: channel, number: data[0], value: 127))
            default: break
            }
            data.removeAll(keepingCapacity: true)
        }
        return messages
    }
}
