import Foundation

public enum ControllerMIDIEncoding: String, Codable, CaseIterable, Sendable {
    case absolute, paired14Bit, paired14BitRelative, twosComplement, binaryOffset, signedBit
    case numarkPlatinumJog, denonJog, zeroForward
    case cdjPlatterSpeed, cdjRingSpeed, cdj350PlatterSpeed, cdjTempo, needlePosition
    public var isRelative: Bool {
        [.twosComplement, .binaryOffset, .signedBit, .paired14BitRelative, .numarkPlatinumJog, .denonJog, .zeroForward]
            .contains(self)
    }
    public var isPairedCC: Bool { self == .paired14Bit || self == .paired14BitRelative }
    public var title: String {
        switch self {
        case .absolute: "Knob / fader"
        case .denonJog: "Denon jog"
        case .zeroForward: "Encoder: 0 / 127"
        case .numarkPlatinumJog: "Mixtrack Platinum jog"
        case .paired14Bit: "High-resolution CC pair"
        case .paired14BitRelative: "Relative high-resolution CC pair"
        case .twosComplement: "Encoder: 1 / 127"
        case .binaryOffset: "Encoder: 65 / 63"
        case .signedBit: "Encoder: 1 / 65"
        case .cdjPlatterSpeed: "CDJ platter speed"
        case .cdjRingSpeed: "CDJ wheel-side speed"
        case .cdj350PlatterSpeed: "CDJ-350 platter speed"
        case .cdjTempo: "CDJ tempo slider"
        case .needlePosition: "Waveform position"
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
    private var relativeMSB: UInt8?
    private var platinumTick: (value: Int, forward: Bool)?
    public init() {}
    public mutating func decode(
        _ message: ControllerMIDIMessage, encoding: ControllerMIDIEncoding, number: UInt8, lowNumber: UInt8? = nil
    )
        -> ControllerMIDIValue?
    {
        if message.kind.isRelativeController {
            guard message.number == number, encoding == .absolute else { return nil }
            return .relative(Double(max(-127, min(127, message.value))))
        }
        let low = lowNumber ?? (number < 32 ? number + 32 : nil)
        if encoding == .paired14BitRelative {
            guard message.kind == .control, message.maximum <= 127, number < 128, (0...127).contains(message.value),
                let low, low < 128, low != number
            else { return nil }
            if message.number == number {
                relativeMSB = UInt8(message.value)
                return nil
            }
            guard message.number == low, let high = relativeMSB else { return nil }
            relativeMSB = nil
            let raw = Int(high) << 7 | message.value
            return .relative(Double(raw < 8192 ? raw : raw - 16384))
        }
        if encoding == .paired14Bit {
            guard message.kind == .control, message.maximum <= 127, number < 128, let low, low < 128, low != number
            else { return nil }
            if message.number == number {
                msb = UInt8(message.value)
                lsb = 0
            } else if message.number == low {
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
        if encoding == .numarkPlatinumJog {
            let rawForward = message.value < 64
            let forward: Bool
            if let previous = platinumTick, previous.forward != rawForward, abs(previous.value - message.value) < 64 {
                forward = previous.forward
            } else {
                forward = rawForward
            }
            platinumTick = (message.value, forward)
            return .relative(Double(forward ? message.value : message.value - 128))
        }
        if encoding == .cdjTempo {
            let delta = message.value - 64
            return .absolute(0.5 + Double(delta) / (delta > 0 ? 126 : 128))
        }
        if encoding == .needlePosition {
            return message.value == 0 ? nil : .absolute(Double(message.value - 1) / 126)
        }
        if encoding == .cdjPlatterSpeed || encoding == .cdjRingSpeed || encoding == .cdj350PlatterSpeed {
            let delta = message.value - 64
            guard delta != 0 else { return .absolute(0.5) }
            let magnitude = abs(delta)
            let maximum = delta > 0 ? 63 : 64
            let speed =
                encoding == .cdjPlatterSpeed || (encoding == .cdj350PlatterSpeed && delta > 0)
                ? Double(magnitude) * 4 / Double(maximum)
                : 0.5 + Double(magnitude - 1) * 3.5 / Double(maximum - 1)
            return .absolute(0.5 + (delta > 0 ? speed : -speed) / 8)
        }
        switch encoding {
        case .zeroForward:
            return message.value == 0 ? .relative(1) : message.value == 127 ? .relative(-1) : nil
        case .denonJog: return .relative(Double(message.value == 0 ? 0 : message.value - 64))
        case .twosComplement: return .relative(Double(message.value < 64 ? message.value : message.value - 128))
        case .binaryOffset: return .relative(Double(message.value - 64))
        case .signedBit: return .relative(Double(message.value & 64 == 0 ? message.value : -(message.value & 63)))
        default: return nil
        }
    }
}
