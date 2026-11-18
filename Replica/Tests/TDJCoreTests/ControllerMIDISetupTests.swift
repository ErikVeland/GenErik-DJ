import Testing

@testable import TDJCore

@Test func controllerMIDISetupWaitsAfterActualSendCompletionIncludingTheFinalMessage() throws {
    var sequence = try #require(
        ControllerMIDISetupSequence(
            steps: [
                .init(message: [0xB0, 1, 0], delayMilliseconds: 20),
                .init(message: [0xB0, 2, 0], delayMilliseconds: 20),
            ], startingAt: 10_000_000))
    #expect(sequence.nextMessage(at: 10_000_000) == [0xB0, 1, 0])
    #expect(sequence.nextMessage(at: 14_000_000) == [0xB0, 1, 0])
    #expect(sequence.didSend(at: 15_000_000) == true)
    #expect(sequence.nextMessage(at: 34_999_999) == nil)
    #expect(sequence.nextMessage(at: 35_000_000) == [0xB0, 2, 0])
    #expect(sequence.didSend(at: 38_000_000) == true)
    #expect(sequence.readyAfter == 58_000_000)
    #expect(!sequence.isComplete(at: 57_999_999))
    #expect(sequence.isComplete(at: 58_000_000))
    #expect(sequence.didSend(at: 58_000_000) == false)
}

@Test func controllerMIDISetupLatePollingCannotCompressModeSettlingAndAllowsZeroDelayPairs() throws {
    var sequence = try #require(
        ControllerMIDISetupSequence(
            steps: [
                .init(message: [0xF0, 0, 1, 96, 21, 1, 0xF7], delayMilliseconds: 20),
                .init(message: [0xBF, 0, 112], delayMilliseconds: 0),
                .init(message: [0xBF, 0, 127], delayMilliseconds: 20),
                .init(message: [0xBF, 1, 112], delayMilliseconds: 0),
            ], startingAt: 0))
    #expect(sequence.didSend(at: 0) == true)
    #expect(sequence.nextMessage(at: 500_000_000) == [0xBF, 0, 112])
    #expect(sequence.didSend(at: 507_000_000) == true)
    #expect(sequence.nextMessage(at: 507_000_000) == [0xBF, 0, 127])
    #expect(sequence.didSend(at: 509_000_000) == true)
    #expect(sequence.nextMessage(at: 528_999_999) == nil)
    #expect(sequence.nextMessage(at: 529_000_000) == [0xBF, 1, 112])
}

@Test func controllerMIDISetupRejectsInvalidUnboundedAndOverlongPlans() {
    #expect(ControllerMIDISetupSequence(steps: [], startingAt: 0) == nil)
    #expect(
        ControllerMIDISetupSequence(steps: [.init(message: [0xB0, 1, 128], delayMilliseconds: 0)], startingAt: 0) == nil
    )
    #expect(
        ControllerMIDISetupSequence(steps: [.init(message: [0xB0, 1, 0], delayMilliseconds: 1001)], startingAt: 0)
            == nil)
    #expect(
        ControllerMIDISetupSequence(
            steps: Array(repeating: .init(message: [0xB0, 1, 0], delayMilliseconds: 0), count: 65), startingAt: 0)
            == nil)
    #expect(
        ControllerMIDISetupSequence(
            steps: Array(repeating: .init(message: [0xB0, 1, 0], delayMilliseconds: 1000), count: 6), startingAt: 0)
            == nil)
    #expect(
        ControllerMIDISetupSequence(steps: [.init(message: [0xF0, 1, 2], delayMilliseconds: 0)], startingAt: 0) == nil)
}

@Test func controllerMIDISetupRejectsEarlyAcknowledgementAndClockOverflow() throws {
    var sequence = try #require(
        ControllerMIDISetupSequence(steps: [.init(message: [0xB0, 1, 0], delayMilliseconds: 20)], startingAt: 100))
    #expect(sequence.didSend(at: 99) == false)
    #expect(sequence.didSend(at: UInt64.max) == false)
    #expect(!sequence.isComplete(at: UInt64.max))
}
