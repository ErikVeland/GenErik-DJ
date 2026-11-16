import Testing

@testable import TDJCore

private func pairedRelativeCC(_ number: UInt8, _ value: Int, maximum: Int = 127) -> ControllerMIDIMessage {
    .init(kind: .control, channel: 0, number: number, value: value, maximum: maximum)
}

@Test func midiPairedRelativeEmitsOnlyOneSignedCountPerCompletePair() {
    var state = ControllerMIDIValueState()
    for (raw, delta) in [(0, 0), (1, 1), (8191, 8191), (8192, -8192), (16383, -1)] {
        #expect(state.decode(pairedRelativeCC(2, raw >> 7), encoding: .paired14BitRelative, number: 2) == nil)
        #expect(
            state.decode(pairedRelativeCC(34, raw & 127), encoding: .paired14BitRelative, number: 2)
                == .relative(Double(delta)))
        #expect(state.decode(pairedRelativeCC(34, raw & 127), encoding: .paired14BitRelative, number: 2) == nil)
    }
}

@Test func midiPairedRelativeRejectsOrphanBytesAndUsesTheLatestHighByte() {
    var state = ControllerMIDIValueState()
    #expect(state.decode(pairedRelativeCC(34, 127), encoding: .paired14BitRelative, number: 2) == nil)
    #expect(state.decode(pairedRelativeCC(2, 127), encoding: .paired14BitRelative, number: 2) == nil)
    #expect(state.decode(pairedRelativeCC(2, 0), encoding: .paired14BitRelative, number: 2) == nil)
    #expect(state.decode(pairedRelativeCC(34, 1), encoding: .paired14BitRelative, number: 2) == .relative(1))
}

@Test func midiPairedRelativeRejectsNonCCAndUnrelatedHighResolutionMessages() {
    var state = ControllerMIDIValueState()
    for message in [
        ControllerMIDIMessage(kind: .note, channel: 0, number: 2, value: 127),
        pairedRelativeCC(2, 65535, maximum: 65535), pairedRelativeCC(3, 1), pairedRelativeCC(35, 1),
        pairedRelativeCC(64, 1),
    ] {
        #expect(state.decode(message, encoding: .paired14BitRelative, number: 2) == nil)
    }
    #expect(state.decode(pairedRelativeCC(64, 1), encoding: .paired14BitRelative, number: 32) == nil)
    #expect(state.decode(pairedRelativeCC(34, 1), encoding: .paired14BitRelative, number: 2) == nil)
}

@Test func midiPairedRelativeKeepsTheExistingAbsolutePairBehaviour() {
    var state = ControllerMIDIValueState()
    #expect(
        state.decode(pairedRelativeCC(0, 127), encoding: .paired14Bit, number: 0) == .absolute(Double(127 << 7) / 16383)
    )
    #expect(state.decode(pairedRelativeCC(32, 127), encoding: .paired14Bit, number: 0) == .absolute(1))
    #expect(ControllerMIDIEncoding.paired14BitRelative.isPairedCC)
    #expect(ControllerMIDIEncoding.paired14BitRelative.isRelative)
}
