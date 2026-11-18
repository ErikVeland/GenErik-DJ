import Testing

@testable import TDJCore

@Test func midiExplicitLowByteKeepsStandardAndNonstandardAbsolutePairsSeparate() {
    var state = ControllerMIDIValueState()
    func cc(_ number: UInt8, _ value: Int) -> ControllerMIDIMessage {
        .init(kind: .control, channel: 0, number: number, value: value)
    }
    #expect(state.decode(cc(119, 127), encoding: .paired14Bit, number: 9, lowNumber: 119) == nil)
    #expect(
        state.decode(cc(9, 127), encoding: .paired14Bit, number: 9, lowNumber: 119)
            == .absolute(Double(127 << 7) / 16383))
    #expect(state.decode(cc(41, 127), encoding: .paired14Bit, number: 9, lowNumber: 119) == nil)
    #expect(state.decode(cc(119, 127), encoding: .paired14Bit, number: 9, lowNumber: 119) == .absolute(1))
    #expect(state.decode(cc(9, 0), encoding: .paired14Bit, number: 9, lowNumber: 9) == nil)
}

@Test func midiExplicitLowByteAlsoKeepsRelativePairsSingleUse() {
    var state = ControllerMIDIValueState()
    let high = ControllerMIDIMessage(kind: .control, channel: 0, number: 9, value: 127)
    let low = ControllerMIDIMessage(kind: .control, channel: 0, number: 119, value: 127)
    #expect(state.decode(high, encoding: .paired14BitRelative, number: 9, lowNumber: 119) == nil)
    #expect(state.decode(low, encoding: .paired14BitRelative, number: 9, lowNumber: 119) == .relative(-1))
    #expect(state.decode(low, encoding: .paired14BitRelative, number: 9, lowNumber: 119) == nil)
}

@Test func midiOriginalPlatinumJogRetainsDirectionAcrossTheSignedMidpointAndAllowsRealReversals() {
    var state = ControllerMIDIValueState()
    let raw = [1, 50, 70, 80, 1, 127, 126, 78, 58, 48, 127, 1]
    let expected = [1, 50, 70, 80, 1, -1, -2, -50, -70, -80, -1, 1]
    for (value, delta) in zip(raw, expected) {
        let message = ControllerMIDIMessage(kind: .control, channel: 0, number: 6, value: value)
        #expect(state.decode(message, encoding: .numarkPlatinumJog, number: 6) == .relative(Double(delta)))
    }
}
