import Foundation

/// Z1 iPad framing recovered from the preserved NI accessory implementation.
/// See docs/coordination/z1-native-accessory.md for evidence and address references.
public enum Z1AccessoryProtocol {
    public static let identifier = "com.native-instruments.traktordj.kontrolz1"

    public enum Framing: Equatable, Sendable {
        case legacy, lengthPrefixed

        public init(firmwareRevision: String) {
            let parts = firmwareRevision.split(separator: ".").compactMap { Int($0) }
            self = parts.count == 3 && parts[2] < 8 ? .legacy : .lengthPrefixed
        }
    }

    public struct Frame: Equatable, Sendable {
        public let reportID: UInt8
        public let payload: [UInt8]
        public init(reportID: UInt8, payload: [UInt8]) {
            self.reportID = reportID
            self.payload = payload
        }
    }

    public static func request(_ reportID: UInt8, framing: Framing) -> [UInt8] {
        framing == .legacy ? [0x33, 0xc3, reportID] : [0x33, 0xc3, 0, 1, 0, reportID]
    }

    public static func feedback(_ report: [UInt8], framing: Framing) throws -> [UInt8] {
        guard report.count == 22, report[0] == 0x80 else { throw TransportError.invalid }
        let header: [UInt8] = framing == .legacy ? [0xb3, 0xc3] : [0xb3, 0xc3, 0, 22, 0]
        return header + report
    }

    public struct Decoder: Sendable {
        public let framing: Framing
        private var buffer: [UInt8] = []
        public init(framing: Framing) { self.framing = framing }

        public mutating func append(_ bytes: [UInt8]) throws -> [Frame] {
            guard bytes.count <= 4096, buffer.count + bytes.count <= 8192 else { throw TransportError.invalid }
            buffer += bytes
            var frames: [Frame] = []
            var offset = 0
            framesLoop: while buffer.count - offset >= 3 {
                guard buffer[offset] == 0x33, buffer[offset + 1] == 0xc3 else { throw TransportError.invalid }
                let headerSize: Int
                let payloadSize: Int
                let reportID: UInt8
                switch framing {
                case .legacy:
                    headerSize = 3
                    reportID = buffer[offset + 2]
                    switch reportID {
                    case 1: payloadSize = 29
                    case 0xd0, 0xd1, 0xd2: payloadSize = 32
                    default: throw TransportError.invalid
                    }
                case .lengthPrefixed:
                    guard buffer[offset + 2] == 0 else { throw TransportError.invalid }
                    if buffer.count - offset < 6 { break framesLoop }
                    let length = Int(buffer[offset + 3]) | Int(buffer[offset + 4]) << 8
                    guard (1...1024).contains(length) else { throw TransportError.invalid }
                    headerSize = 6
                    payloadSize = length - 1
                    reportID = buffer[offset + 5]
                }
                let end = offset + headerSize + payloadSize
                if end > buffer.count { break }
                guard frames.count < 128 else { throw TransportError.invalid }
                frames.append(.init(reportID: reportID, payload: Array(buffer[(offset + headerSize)..<end])))
                offset = end
            }
            if offset > 0 { buffer.removeFirst(offset) }
            return frames
        }
    }

    /// Only the expected calibration reply advances startup. Input waits for all three replies.
    public struct Startup: Sendable {
        public private(set) var expectedReport: UInt8 = 0xd0
        public private(set) var calibration: Z1CrossfaderCalibration?
        public private(set) var ready = false
        public init() {}

        public mutating func consume(_ frame: Frame) throws -> UInt8? {
            guard !ready, frame.reportID == expectedReport else { return nil }
            guard frame.payload.count == 32 else { throw TransportError.invalid }
            if expectedReport == 0xd2 {
                calibration = try Z1CrossfaderCalibration(featureD2: frame.payload)
                ready = true
                return 1
            }
            expectedReport += 1
            return expectedReport
        }

        public func input(_ frame: Frame) throws -> Z1InputReport? {
            guard ready, frame.reportID == 1 else { return nil }
            return try Z1InputReport(bytes: [1] + frame.payload)
        }
    }
}
