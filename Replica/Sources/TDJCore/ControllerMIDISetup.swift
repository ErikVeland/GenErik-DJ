public struct ControllerMIDISetupStep: Equatable, Sendable {
    public let message: [UInt8]
    public let delayMilliseconds: UInt16

    public init(message: [UInt8], delayMilliseconds: UInt16) {
        self.message = message
        self.delayMilliseconds = delayMilliseconds
    }

    public static func validMessage(_ bytes: [UInt8]) -> Bool {
        if bytes.count == 3 {
            return (0x80...0xEF).contains(bytes[0]) && bytes[1] < 128 && bytes[2] < 128
        }
        return (4...128).contains(bytes.count) && bytes.first == 0xF0 && bytes.last == 0xF7
            && bytes.dropFirst().dropLast().allSatisfy { $0 < 128 }
    }
}

public struct ControllerMIDISetupSequence: Equatable, Sendable {
    private let steps: [ControllerMIDISetupStep]
    private var index = 0
    public private(set) var readyAfter: UInt64

    public init?(steps: [ControllerMIDISetupStep], startingAt: UInt64) {
        guard !steps.isEmpty, steps.count <= 64,
            steps.allSatisfy({ $0.delayMilliseconds <= 1000 && ControllerMIDISetupStep.validMessage($0.message) }),
            steps.reduce(0, { $0 + Int($1.delayMilliseconds) }) <= 5000
        else { return nil }
        self.steps = steps
        readyAfter = startingAt
    }

    public func nextMessage(at timestamp: UInt64) -> [UInt8]? {
        guard index < steps.count, timestamp >= readyAfter else { return nil }
        return steps[index].message
    }

    /**
     * Starts each settling interval after the sender returns, so late polling cannot compress it.
     */
    @discardableResult public mutating func didSend(at timestamp: UInt64) -> Bool {
        guard index < steps.count, timestamp >= readyAfter else { return false }
        let (deadline, overflow) = timestamp.addingReportingOverflow(UInt64(steps[index].delayMilliseconds) * 1_000_000)
        guard !overflow else { return false }
        readyAfter = deadline
        index += 1
        return true
    }

    public func isComplete(at timestamp: UInt64) -> Bool { index == steps.count && timestamp >= readyAfter }
}
