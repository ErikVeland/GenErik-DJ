import Testing

@testable import TDJCore

@Test func controllerKontrolOneKeepsSourceWheelAndKnobDirectionsForEveryValue() {
    for channel: UInt8 in 0...3 {
        var decoder = ControllerKontrolOneDecoder()
        for raw: UInt8 in 0...127 {
            let wheel = decoder.append([0xB0 + channel, 32, raw])
            #expect(
                wheel.last == .message(.init(kind: .control, channel: channel, number: 32, value: raw > 1 ? 1 : 127)))
            for knob: UInt8 in 52...55 {
                #expect(
                    decoder.append([0xB0 + channel, knob, raw]) == [
                        .message(.init(kind: .control, channel: channel, number: knob, value: raw == 127 ? 1 : 127))
                    ])
            }
            #expect(
                decoder.append([0xB0 + channel, 33, raw]) == [
                    .message(.init(kind: .control, channel: channel, number: 33, value: Int(raw)))
                ])
        }
    }
}

@Test func controllerKontrolOneEmitsDeckBarrierBeforeFirstMessageAndEveryHardwareChannelChange() {
    var decoder = ControllerKontrolOneDecoder()
    for channel: UInt8 in [0, 2, 1, 3, 0] {
        let press = ControllerMIDIMessage(kind: .note, channel: channel, number: 28, value: 127)
        #expect(decoder.append([0x90 + channel, 28, 127]) == [.deckChanged, .message(press)])
        #expect(
            decoder.append([0x80 + channel, 28, 100]) == [
                .message(.init(kind: .note, channel: channel, number: 28, value: 0, isNoteOff: true))
            ])
    }
}

@Test func controllerKontrolOneRejectsUnknownWireTrafficWithoutChangingDeckOwnership() {
    var decoder = ControllerKontrolOneDecoder()
    _ = decoder.append([0x90, 27, 127])
    #expect(decoder.append([0x91, 126, 127, 0xB1, 1, 127, 0xE1, 0, 64, 0x94, 27, 127]).isEmpty)
    #expect(decoder.append([0x90, 27, 0]).count == 1)
    #expect(decoder.append([0xF0, 0, 32, 41, 0xF7, 0x92, 27]).isEmpty)
    #expect(decoder.append([0xF8, 127]).count == 2)
}

@Test func controllerKontrolOneKeepsFragmentsAndChannelOwnershipPerDecoder() {
    var first = ControllerKontrolOneDecoder()
    var second = ControllerKontrolOneDecoder()
    #expect(first.append([0x90, 26]).isEmpty)
    #expect(second.append([127]).isEmpty)
    #expect(first.append([127]).count == 2)
    #expect(second.append([0x93, 26, 127]).count == 2)
    #expect(first.append([26, 0]).count == 1)
    first = .init()
    #expect(first.append([0x90, 26, 0]).count == 2)
}
