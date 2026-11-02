import Foundation

public struct ControllerMIDIMessage: Equatable, Sendable {
    public enum Kind: String, Codable, Sendable { case note, control, pitch, polyPressure, pressure, program }
    public let kind: Kind
    public let channel: UInt8
    public let number: UInt8
    public let value: Int
    public var normalized: Double { Double(value) / (kind == .pitch ? 16383 : 127) }
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
                messages.append(.init(kind: .note, channel: channel, number: data[0], value: type == 0x80 ? 0 : Int(data[1])))
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
