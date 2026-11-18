import Testing

@testable import TDJCore

@Test func midiRot64FastPreservesEveryPublishedSevenBitDeltaAndScale() {
    var state = ControllerMIDIValueState()
    for value in 0...127 {
        #expect(
            state.decode(.init(kind: .control, channel: 0, number: 16, value: value), encoding: .rot64Fast, number: 16)
                == .relative(Double(value - 64) * 1.5))
    }
    #expect(ControllerMIDIEncoding.rot64Fast.isRelative)
    #expect(!ControllerMIDIEncoding.rot64Fast.supportsLearning)
}

@Test func midiRot64FastRejectsForeignKindsNumbersAndInvalidRanges() {
    var state = ControllerMIDIValueState()
    for message in [
        ControllerMIDIMessage(kind: .note, channel: 0, number: 16, value: 127),
        .init(kind: .control, channel: 0, number: 17, value: 127),
        .init(kind: .control, channel: 0, number: 16, value: -1),
        .init(kind: .control, channel: 0, number: 16, value: 128),
        .init(kind: .control, channel: 0, number: 16, value: 1, maximum: 65535),
    ] {
        #expect(state.decode(message, encoding: .rot64Fast, number: 16) == nil)
    }
}
