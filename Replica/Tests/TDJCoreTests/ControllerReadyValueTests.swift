import Testing

@testable import TDJCore

@Test func midiReadyTempoUsesFreshExplicitPairsAndMeasuredTenBitTravel() {
    var state = ControllerMIDIValueState()
    func cc(_ number: UInt8, _ value: Int) -> ControllerMIDIMessage {
        .init(kind: .control, channel: 0, number: number, value: value)
    }
    #expect(state.decode(cc(63, 127), encoding: .readyTempo, number: 9, lowNumber: 63) == nil)
    for raw in [0, 1, 127, 128, 511, 512, 1022, 1023] {
        #expect(state.decode(cc(9, raw >> 7), encoding: .readyTempo, number: 9, lowNumber: 63) == nil)
        #expect(
            state.decode(cc(63, raw & 127), encoding: .readyTempo, number: 9, lowNumber: 63)
                == .absolute(Double(raw) / 1023))
        #expect(state.decode(cc(63, 0), encoding: .readyTempo, number: 9, lowNumber: 63) == nil)
    }
    #expect(state.decode(cc(9, 8), encoding: .readyTempo, number: 9, lowNumber: 63) == nil)
    #expect(state.decode(cc(63, 0), encoding: .readyTempo, number: 9, lowNumber: 63) == nil)
    #expect(!ControllerMIDIEncoding.readyTempo.isRelative && ControllerMIDIEncoding.readyTempo.isPairedCC)
    #expect(!ControllerMIDIEncoding.readyTempo.supportsLearning)
}
