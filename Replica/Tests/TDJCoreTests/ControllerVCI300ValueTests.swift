import Testing

@testable import TDJCore

private func vciCC(_ number: UInt8, _ value: Int, maximum: Int = 127) -> ControllerMIDIMessage {
    .init(kind: .control, channel: 0, number: number, value: value, maximum: maximum)
}

private func vciPair(_ raw: Int, state: inout ControllerMIDIValueState) -> ControllerMIDIValue? {
    #expect(state.decode(vciCC(28, raw >> 7), encoding: .cyclic14BitJog, number: 28, lowNumber: 60) == nil)
    return state.decode(vciCC(60, raw & 127), encoding: .cyclic14BitJog, number: 28, lowNumber: 60)
}

@Test func midiVCI300CounterPrimesConsumesEachPairAndWrapsInBothDirections() {
    var state = ControllerMIDIValueState()
    #expect(state.decode(vciCC(60, 127), encoding: .cyclic14BitJog, number: 28, lowNumber: 60) == nil)
    #expect(vciPair(16383, state: &state) == nil)
    #expect(vciPair(0, state: &state) == .relative(1))
    #expect(vciPair(16383, state: &state) == .relative(-1))
    #expect(vciPair(16383, state: &state) == .relative(0))
    #expect(state.decode(vciCC(60, 0), encoding: .cyclic14BitJog, number: 28, lowNumber: 60) == nil)
    #expect(vciPair(127, state: &state) == .relative(128))
    #expect(vciPair(128, state: &state) == .relative(1))
    state = .init()
    #expect(vciPair(5000, state: &state) == nil)
}

@Test func midiVCI300CounterKeepsSourceHalfRangeBoundariesAndLatestHighByte() {
    var state = ControllerMIDIValueState()
    #expect(vciPair(0, state: &state) == nil)
    #expect(vciPair(8192, state: &state) == .relative(-8192))
    #expect(vciPair(0, state: &state) == .relative(-8192))
    #expect(vciPair(8193, state: &state) == .relative(-8191))
    #expect(vciPair(0, state: &state) == .relative(8191))
    #expect(state.decode(vciCC(28, 10), encoding: .cyclic14BitJog, number: 28, lowNumber: 60) == nil)
    #expect(state.decode(vciCC(28, 1), encoding: .cyclic14BitJog, number: 28, lowNumber: 60) == nil)
    #expect(state.decode(vciCC(60, 0), encoding: .cyclic14BitJog, number: 28, lowNumber: 60) == .relative(128))
}

@Test func midiVCI300TempoUsesEveryNineBitStepWithExactCentreAndEndpoints() {
    var state = ControllerMIDIValueState()
    #expect(state.decode(vciCC(45, 64), encoding: .vci300Tempo, number: 13) == nil)
    for pitch in 0...511 {
        #expect(state.decode(vciCC(13, pitch >> 2), encoding: .vci300Tempo, number: 13) == nil)
        let expected = 0.5 + Double(pitch - 256) / (pitch > 256 ? 510 : 512)
        #expect(state.decode(vciCC(45, (pitch & 3) << 5), encoding: .vci300Tempo, number: 13) == .absolute(expected))
        #expect(state.decode(vciCC(45, 0), encoding: .vci300Tempo, number: 13) == nil)
    }
}

@Test func midiVCI300PairsRejectMalformedPacketsAndCounterRequiresFactorySelection() {
    for encoding in [ControllerMIDIEncoding.cyclic14BitJog, .vci300Tempo] {
        var state = ControllerMIDIValueState()
        #expect(state.decode(vciCC(28, -1), encoding: encoding, number: 28, lowNumber: 60) == nil)
        #expect(state.decode(vciCC(28, 128), encoding: encoding, number: 28, lowNumber: 60) == nil)
        #expect(state.decode(vciCC(28, 1, maximum: 16383), encoding: encoding, number: 28, lowNumber: 60) == nil)
        #expect(state.decode(vciCC(28, 1), encoding: encoding, number: 28, lowNumber: 28) == nil)
        #expect(encoding.isPairedCC)
    }
    #expect(ControllerMIDIEncoding.cyclic14BitJog.isRelative)
    #expect(!ControllerMIDIEncoding.cyclic14BitJog.supportsLearning)
    #expect(!ControllerMIDIEncoding.vci300Tempo.isRelative)
}
