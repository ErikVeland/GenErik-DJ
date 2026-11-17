import Foundation
import Testing

@testable import TDJCore

@Test func midiNoteStepEmitsOneCountForEachPositiveReportWithoutReleaseTicks() {
    var state = ControllerMIDIValueState()
    for value in [1, 64, 127, 127] {
        #expect(
            state.decode(.init(kind: .note, channel: 0, number: 96, value: value), encoding: .noteStep, number: 96)
                == .relative(1))
    }
    #expect(state.decode(.init(kind: .note, channel: 0, number: 96, value: 0), encoding: .noteStep, number: 96) == nil)
    #expect(
        state.decode(
            .init(kind: .note, channel: 0, number: 96, value: 127, isNoteOff: true), encoding: .noteStep, number: 96)
            == nil)
}

@Test func midiNoteStepRejectsForeignKindsNumbersAndMalformedOrExpandedValues() {
    var state = ControllerMIDIValueState()
    for message in [
        ControllerMIDIMessage(kind: .control, channel: 0, number: 96, value: 127),
        .init(kind: .note, channel: 0, number: 97, value: 127),
        .init(kind: .note, channel: 0, number: 96, value: 65535, maximum: 65535),
        .init(kind: .note, channel: 0, number: 96, value: 128, maximum: 127),
        .init(kind: .note, channel: 0, number: 96, value: -1, maximum: 127),
        .init(kind: .note, channel: 0, number: 96, value: 1, maximum: 1),
    ] {
        #expect(state.decode(message, encoding: .noteStep, number: 96) == nil)
    }
    #expect(ControllerMIDIEncoding.noteStep.isRelative)
    #expect(!ControllerMIDIEncoding.noteStep.isPairedCC && !ControllerMIDIEncoding.noteStep.supportsLearning)
}
