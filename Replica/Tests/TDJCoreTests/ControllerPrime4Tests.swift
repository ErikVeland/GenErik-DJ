import Testing

@testable import TDJCore

@Test func controllerPrime4EveryNormalButtonAndLoadRetainsItsOriginalDeckOnRelease() {
    for side: UInt8 in 0...1 {
        for number: UInt8 in [8, 9, 10, 29, 30, 34, 37, 38, 15, 16, 17, 18, 19, 20, 21, 22, 126] {
            for velocity: UInt8 in [0, 1, 64, 127] {
                var decoder = ControllerPrime4Decoder()
                let wire: UInt8 = number == 126 ? 15 : 4 + side
                let raw = number == 126 ? 1 + side : number
                let logical = (15...22).contains(number) ? number + 49 : number
                #expect(
                    decoder.append([0x90 + wire, raw, 127]) == [
                        .message(.init(kind: .note, channel: 4 + side, number: logical, value: 127))
                    ])
                #expect(decoder.append([0x90 + wire, raw, 127]).isEmpty)
                #expect(decoder.append([0x9F, 30 + side, 127]) == [.controlsChanged(left: side == 0)])
                #expect(
                    decoder.append([0x80 + wire, raw, velocity]) == [
                        .message(.init(kind: .note, channel: 4 + side, number: logical, value: 0, isNoteOff: true))
                    ])
                #expect(
                    decoder.append([0x90 + wire, raw, 127]).first
                        == .message(.init(kind: .note, channel: 6 + side, number: logical, value: 127)))
            }
        }
    }
}

@Test func controllerPrime4PadModesArePerDeckAndInactiveHeldPadsCannotBecomeCues() {
    var decoder = ControllerPrime4Decoder()
    #expect(decoder.append([0x94, 12, 127, 12, 0]) == [.controlsChanged(left: true)])
    #expect(decoder.append([0x94, 15, 127]).isEmpty)
    #expect(decoder.append([0x94, 11, 127, 11, 0]) == [.controlsChanged(left: true)])
    #expect(decoder.append([0x94, 15, 127, 15, 0]).isEmpty)
    #expect(decoder.append([0x94, 15, 127, 15, 0]).count == 2)
    _ = decoder.append([0x94, 13, 127, 13, 0, 0x9F, 30, 127, 30, 0])
    #expect(decoder.append([0x94, 16, 127, 16, 0]).count == 2)
    _ = decoder.append([0x9F, 28, 127, 28, 0])
    #expect(decoder.append([0x94, 17, 127, 17, 0]).isEmpty)
    #expect(decoder.append([0x95, 17, 127, 17, 0]).count == 2)
}

@Test func controllerPrime4ControlsAreBoundedAndRejectWireLogicalInjectionAndUnqualifiedTraffic() {
    var decoder = ControllerPrime4Decoder()
    for value: UInt8 in 0...127 {
        #expect(
            decoder.append([0xB0, 14, value, 0xBF, 5, value, 0xB4, 55, value, 77, value, 0xE4, value, value]).isEmpty)
        #expect(
            decoder.append([
                0x96, 10, value, 64, value, 126, value, 0x9E, 28, value, 0x94, 126, value, 64, value, 33, value, 39,
                value,
            ]).isEmpty)
        #expect(decoder.append([0xB4, 32, value]).count == ((value == 1 || value == 127) ? 1 : 0))
    }
    for side: UInt8 in 0...1 {
        for cc: UInt8 in [31, 75] {
            #expect(
                decoder.append([0xB4 + side, cc, 64]) == [
                    .message(.init(kind: .control, channel: 4 + side, number: cc, value: 64))
                ])
        }
        #expect(
            decoder.append([0x94 + side, 28, 127]).first
                == .message(.init(kind: .note, channel: 14, number: 28, value: 127)))
    }
}

@Test func controllerPrime4SelectorsFragmentsRealtimeAndReconnectKeepIndependentState() {
    var first = ControllerPrime4Decoder()
    var second = ControllerPrime4Decoder()
    #expect(first.append([0x9F, 30]).isEmpty)
    #expect(first.append([0xF8, 127, 30, 127, 30, 0]) == [.controlsChanged(left: true)])
    #expect(first.append([0x94, 10, 127]).first == .message(.init(kind: .note, channel: 6, number: 10, value: 127)))
    #expect(second.append([0x94, 10, 127]).first == .message(.init(kind: .note, channel: 4, number: 10, value: 127)))
    first = .init()
    #expect(first.append([127]).isEmpty)
    #expect(first.append([0x94, 10, 127]).first == .message(.init(kind: .note, channel: 4, number: 10, value: 127)))
}
