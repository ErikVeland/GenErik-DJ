import Foundation

public enum ControllerMIDIEncoding: String, Codable, CaseIterable, Sendable {
    case absolute, paired14Bit, twosComplement, binaryOffset, signedBit
    public var isRelative: Bool { self != .absolute && self != .paired14Bit }
    public var title: String {
        switch self {
        case .absolute: "Knob / fader"
        case .paired14Bit: "High-resolution CC pair"
        case .twosComplement: "Encoder: 1 / 127"
        case .binaryOffset: "Encoder: 65 / 63"
        case .signedBit: "Encoder: 1 / 65"
        }
    }
}

public enum ControllerMIDIValue: Equatable, Sendable {
    case absolute(Double)
    case relative(Double)
}

public struct ControllerMIDIValueState: Sendable {
    private var msb: UInt8?
    private var lsb: UInt8 = 0
    public init() {}
    public mutating func decode(_ message: ControllerMIDIMessage, encoding: ControllerMIDIEncoding, number: UInt8)
        -> ControllerMIDIValue?
    {
        if message.kind.isRelativeController {
            guard message.number == number, encoding == .absolute else { return nil }
            return .relative(Double(max(-127, min(127, message.value))))
        }
        if encoding == .paired14Bit {
            guard message.kind == .control, message.maximum <= 127, number < 32 else { return nil }
            if message.number == number {
                msb = UInt8(message.value)
                lsb = 0
            } else if message.number == number + 32 {
                lsb = UInt8(message.value)
            } else {
                return nil
            }
            guard let msb else { return nil }
            return .absolute(Double(Int(msb) << 7 | Int(lsb)) / 16383)
        }
        guard message.number == number else { return nil }
        if encoding == .absolute { return .absolute(message.normalized) }
        guard message.kind == .control, message.maximum <= 127 else { return nil }
        switch encoding {
        case .twosComplement: return .relative(Double(message.value < 64 ? message.value : message.value - 128))
        case .binaryOffset: return .relative(Double(message.value - 64))
        case .signedBit: return .relative(Double(message.value & 64 == 0 ? message.value : -(message.value & 63)))
        default: return nil
        }
    }
}
