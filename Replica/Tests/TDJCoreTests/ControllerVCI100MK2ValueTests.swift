import Testing

@testable import TDJCore

@Test func midiVCI100MK2TempoPreservesAllFourteenBitsAndExactSourceCentre() {
    var state = ControllerMIDIValueState()
    for raw in 0...16383 {
        let high = ControllerMIDIMessage(kind: .control, channel: 0, number: 27, value: raw >> 7, maximum: 127)
        let low = ControllerMIDIMessage(kind: .control, channel: 0, number: 43, value: raw & 127, maximum: 127)
        #expect(state.decode(high, encoding: .vci100MK2Tempo, number: 27, lowNumber: 43) == nil)
        #expect(
            state.decode(low, encoding: .vci100MK2Tempo, number: 27, lowNumber: 43) == .absolute(Double(raw) / 16384))
        #expect(state.decode(low, encoding: .vci100MK2Tempo, number: 27, lowNumber: 43) == nil)
    }
    #expect(!ControllerMIDIEncoding.vci100MK2Tempo.isRelative)
    #expect(ControllerMIDIEncoding.vci100MK2Tempo.isPairedCC)
    #expect(!ControllerMIDIEncoding.vci100MK2Tempo.supportsLearning)
}
