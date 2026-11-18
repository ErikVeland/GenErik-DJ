import Testing

@testable import TDJCore

private func mixstreamCC(_ number: UInt8, _ value: Int, maximum: Int = 127) -> ControllerMIDIMessage {
    .init(kind: .control, channel: 2, number: number, value: value, maximum: maximum)
}

@Test func midiMixstreamCounterPrimesAndReportsMovementWithoutRepeatingPosition() {
    var state = ControllerMIDIValueState()
    #expect(state.decode(mixstreamCC(77, 100), encoding: .mixstreamJog, number: 55, lowNumber: 77) == nil)
    #expect(state.decode(mixstreamCC(77, 101), encoding: .mixstreamJog, number: 55, lowNumber: 77) == .relative(1))
    #expect(state.decode(mixstreamCC(77, 101), encoding: .mixstreamJog, number: 55, lowNumber: 77) == nil)
    #expect(state.decode(mixstreamCC(77, 99), encoding: .mixstreamJog, number: 55, lowNumber: 77) == .relative(-2))
}

@Test func midiMixstreamCounterKeepsTheSourceHighByteBoundaryRuleInBothDirections() {
    var state = ControllerMIDIValueState()
    let packets: [(UInt8, Int)] = [(77, 126), (77, 127), (55, 1), (77, 0), (77, 1), (77, 0), (55, 0), (77, 127)]
    var counts: [Double] = []
    for (number, value) in packets {
        if case .relative(let count) = state.decode(
            mixstreamCC(number, value), encoding: .mixstreamJog, number: 55, lowNumber: 77)
        {
            counts.append(count)
        }
    }
    #expect(counts == [1, 1, 1, -1, -1])
}

@Test func midiMixstreamCounterRejectsLargeJumpsAndRebasesWithoutASeek() {
    var state = ControllerMIDIValueState()
    #expect(state.decode(mixstreamCC(77, 1), encoding: .mixstreamJog, number: 55, lowNumber: 77) == nil)
    #expect(state.decode(mixstreamCC(77, 100), encoding: .mixstreamJog, number: 55, lowNumber: 77) == nil)
    #expect(state.decode(mixstreamCC(77, 101), encoding: .mixstreamJog, number: 55, lowNumber: 77) == .relative(1))
    #expect(state.decode(mixstreamCC(55, 127), encoding: .mixstreamJog, number: 55, lowNumber: 77) == nil)
    #expect(state.decode(mixstreamCC(77, 127), encoding: .mixstreamJog, number: 55, lowNumber: 77) == nil)
    #expect(state.decode(mixstreamCC(55, 0), encoding: .mixstreamJog, number: 55, lowNumber: 77) == nil)
    #expect(state.decode(mixstreamCC(77, 0), encoding: .mixstreamJog, number: 55, lowNumber: 77) == nil)
    #expect(state.decode(mixstreamCC(77, 1), encoding: .mixstreamJog, number: 55, lowNumber: 77) == .relative(1))
}

@Test func midiMixstreamCounterRequiresAnExplicitSevenBitPairAndFactorySelection() {
    var state = ControllerMIDIValueState()
    #expect(state.decode(mixstreamCC(77, 10), encoding: .mixstreamJog, number: 55) == nil)
    #expect(
        state.decode(mixstreamCC(77, 10, maximum: 65535), encoding: .mixstreamJog, number: 55, lowNumber: 77) == nil)
    #expect(state.decode(mixstreamCC(77, 128), encoding: .mixstreamJog, number: 55, lowNumber: 77) == nil)
    #expect(state.decode(mixstreamCC(77, 10), encoding: .mixstreamJog, number: 55, lowNumber: 55) == nil)
    #expect(!ControllerMIDIEncoding.mixstreamJog.supportsLearning)
    #expect(ControllerMIDIEncoding.paired14Bit.supportsLearning)
    #expect(ControllerMIDIEncoding.mixstreamJog.isRelative && ControllerMIDIEncoding.mixstreamJog.isPairedCC)
}
