import Foundation

/// Private GenErik development bridge carried by a user-selected MIDI connection.
public struct ControllerBridgeFrame: Equatable, Sendable {
    public enum Kind: UInt8, Sendable {
        case z1Input = 1
        case z1Output = 2
        case z1Calibration = 3
        case z1Status = 4
        case s4MK3Input = 5
        case s4MK3Lights = 6
        case s4MK3Ring = 7
        case s4MK3Status = 8
        case modularInput = 9
        case modularLights = 10
        case modularStatus = 11
        case s2MK1Report = 12
        case s2MK1Lights = 13
        case s4MK1Report = 14
        case s4MK1Lights = 15
        case factoryInput = 16
        case factoryLights = 17
        case factoryScreen = 18
        case factoryScreenContent = 19
        case x1PatternScreen = 20
        var payloadCount: Int {
            switch self {
            case .z1Input: 30
            case .z1Output: 22
            case .z1Calibration: 32
            case .z1Status, .s4MK3Status, .modularStatus: 1
            case .s4MK3Input: 96
            case .s4MK3Lights: 95
            case .s4MK3Ring: 41
            case .modularInput: 36
            case .modularLights: 51
            case .s2MK1Report: 53
            case .s2MK1Lights: 62
            case .s4MK1Report: 74
            case .s4MK1Lights, .factoryInput, .factoryLights: 103
            case .factoryScreen, .x1PatternScreen: 64
            case .factoryScreenContent: 103
            }
        }
    }
    public enum FrameError: Error { case invalid }
    public let kind: Kind
    public let payload: [UInt8]
    public init(kind: Kind, payload: [UInt8]) throws {
        guard payload.count == kind.payloadCount else { throw FrameError.invalid }
        self.kind = kind
        self.payload = payload
    }
    public var encoded: [UInt8] {
        var result: [UInt8] = [0xf0, 0x7d, 0x47, 0x44, 0x4a, 1, kind.rawValue, UInt8(payload.count)]
        for start in stride(from: 0, to: payload.count, by: 7) {
            let group = Array(payload[start..<min(start + 7, payload.count)])
            let mask = group.enumerated().reduce(UInt8(0)) { $0 | (($1.element >> 7) << $1.offset) }
            result.append(mask)
            result += group.map { $0 & 0x7f }
        }
        result.append(UInt8((Int(kind.rawValue) + payload.count + payload.reduce(0) { $0 + Int($1) }) & 0x7f))
        result.append(0xf7)
        return result
    }
    fileprivate static func decode(_ bytes: [UInt8]) -> Self? {
        guard bytes.count >= 8, Array(bytes.prefix(5)) == [0x7d, 0x47, 0x44, 0x4a, 1],
            let kind = Kind(rawValue: bytes[5]), Int(bytes[6]) == kind.payloadCount
        else { return nil }
        let count = kind.payloadCount
        guard bytes.count == 7 + count + (count + 6) / 7 + 1 else { return nil }
        var payload: [UInt8] = []
        var index = 7
        while payload.count < count {
            let length = min(7, count - payload.count)
            let mask = bytes[index]
            index += 1
            guard mask >> length == 0 else { return nil }
            for bit in 0..<length {
                payload.append(bytes[index] | (((mask >> bit) & 1) << 7))
                index += 1
            }
        }
        let checksum = UInt8((Int(kind.rawValue) + count + payload.reduce(0) { $0 + Int($1) }) & 0x7f)
        guard bytes[index] == checksum else { return nil }
        return try? .init(kind: kind, payload: payload)
    }
}

public struct ControllerBridgeDecoder: Sendable {
    private var buffer: [UInt8] = []
    private var collecting = false
    public init() {}
    public mutating func append(_ bytes: [UInt8]) -> [ControllerBridgeFrame] {
        var frames: [ControllerBridgeFrame] = []
        for byte in bytes {
            if byte >= 0xf8 { continue }
            if byte == 0xf0 {
                buffer.removeAll(keepingCapacity: true)
                collecting = true
                continue
            }
            if byte == 0xf7 {
                if collecting, let frame = ControllerBridgeFrame.decode(buffer) { frames.append(frame) }
                collecting = false
                buffer.removeAll(keepingCapacity: true)
                continue
            }
            guard collecting else { continue }
            guard byte < 128, buffer.count < 128 else {
                collecting = false
                buffer.removeAll(keepingCapacity: true)
                continue
            }
            buffer.append(byte)
        }
        return frames
    }
}
