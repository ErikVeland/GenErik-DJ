import Testing

@testable import TDJCore

@Test func midiLC6000RequiresDirectionThenRetainsItAcrossRotationPackets() {
    var state = ControllerMIDIValueState()
    func cc(_ number: UInt8, _ value: Int) -> ControllerMIDIMessage {
        .init(kind: .control, channel: 0, number: number, value: value)
    }
    #expect(state.decode(cc(54, 1), encoding: .lc6000Jog, number: 55, lowNumber: 54) == nil)
    #expect(state.decode(cc(55, 0), encoding: .lc6000Jog, number: 55, lowNumber: 54) == nil)
    for value in [0, 1, 63, 127] {
        #expect(
            state.decode(cc(54, value), encoding: .lc6000Jog, number: 55, lowNumber: 54) == .relative(Double(value)))
    }
    #expect(state.decode(cc(55, 127), encoding: .lc6000Jog, number: 55, lowNumber: 54) == nil)
    for value in [0, 64, 126, 127] {
        #expect(
            state.decode(cc(54, value), encoding: .lc6000Jog, number: 55, lowNumber: 54)
                == .relative(Double(value - 127)))
    }
    #expect(ControllerMIDIEncoding.lc6000Jog.isRelative && ControllerMIDIEncoding.lc6000Jog.isPairedCC)
    #expect(!ControllerMIDIEncoding.lc6000Jog.supportsLearning)
    for message in [
        cc(17, 1), cc(49, 1), cc(54, -1), cc(54, 128),
        .init(kind: .note, channel: 0, number: 54, value: 1),
        .init(kind: .control, channel: 0, number: 54, value: 1, maximum: 65535),
    ] {
        #expect(state.decode(message, encoding: .lc6000Jog, number: 55, lowNumber: 54) == nil)
    }
}
