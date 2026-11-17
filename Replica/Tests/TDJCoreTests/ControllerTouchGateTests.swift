import Testing

@testable import TDJCore

@Test func midiTouchGateUsesMidpointAndExplicitNoteOffAcrossResolutions() {
    var state = ControllerMIDIValueState()
    for maximum in [127, 65535] {
        for value in [0, maximum / 2, maximum / 2 + 1, maximum] {
            let message = ControllerMIDIMessage(kind: .note, channel: 0, number: 77, value: value, maximum: maximum)
            #expect(state.decode(message, encoding: .touchGate, number: 77) == .absolute(value > maximum / 2 ? 1 : 0))
        }
        let off = ControllerMIDIMessage(
            kind: .note, channel: 0, number: 77, value: maximum, maximum: maximum, isNoteOff: true)
        #expect(state.decode(off, encoding: .touchGate, number: 77) == .absolute(0))
    }
    #expect(!ControllerMIDIEncoding.touchGate.supportsLearning)
    for message in [
        ControllerMIDIMessage(kind: .control, channel: 0, number: 77, value: 127),
        ControllerMIDIMessage(kind: .note, channel: 0, number: 78, value: 127),
        ControllerMIDIMessage(kind: .note, channel: 0, number: 77, value: -1),
        ControllerMIDIMessage(kind: .note, channel: 0, number: 77, value: 128),
    ] {
        #expect(state.decode(message, encoding: .touchGate, number: 77) == nil)
    }
}

@Test func midiFullVelocityGateReleasesEveryValueBelowThePublishedContactValue() {
    var state = ControllerMIDIValueState()
    for maximum in [127, 65535] {
        for value in [0, maximum / 2, maximum - 1, maximum] {
            let message = ControllerMIDIMessage(kind: .note, channel: 0, number: 22, value: value, maximum: maximum)
            #expect(
                state.decode(message, encoding: .fullVelocityGate, number: 22) == .absolute(value == maximum ? 1 : 0))
        }
        let off = ControllerMIDIMessage(
            kind: .note, channel: 0, number: 22, value: maximum, maximum: maximum, isNoteOff: true)
        #expect(state.decode(off, encoding: .fullVelocityGate, number: 22) == .absolute(0))
    }
    #expect(!ControllerMIDIEncoding.fullVelocityGate.supportsLearning)
}
