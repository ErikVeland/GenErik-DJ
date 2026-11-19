import Testing

@testable import TDJCore

@Test func controllerSpectraUsesEightCueAddressesAndOnlyPositiveDeckSelection() {
    var decoder = ControllerSpectraDecoder()
    for base: UInt8 in [52, 84] {
        for deck: UInt8 in 0...3 {
            _ = decoder.append([0x92, base + deck, 127])
            for (slot, number) in [60, 61, 62, 63, 56, 57, 58, 59].enumerated() {
                #expect(
                    decoder.append([0x92, UInt8(number), 127]) == [
                        .message(.init(kind: .note, channel: deck, number: 64 + UInt8(slot), value: 127))
                    ])
            }
            #expect(decoder.append([0x82, base + (deck + 1) % 4, 127]).isEmpty)
            #expect(
                decoder.append([0x92, 60, 127]).last
                    == .message(.init(kind: .note, channel: deck, number: 64, value: 127)))
        }
    }
}

@Test func controllerSpectraEveryNoteOffVelocityReleasesWithoutActivatingCue() {
    for velocity: UInt8 in 0...127 {
        var decoder = ControllerSpectraDecoder()
        #expect(
            decoder.append([0x82, 60, velocity]) == [
                .message(.init(kind: .note, channel: 0, number: 64, value: 0, isNoteOff: true))
            ])
    }
}

@Test func controllerSpectraKeepsFixedFilterMessagesSeparateFromSelectedDeckAndUnknownTraffic() {
    var decoder = ControllerSpectraDecoder()
    _ = decoder.append([0x92, 55, 127])
    for number: UInt8 in 36...39 {
        #expect(
            decoder.append([0x92, number, 127]) == [
                .message(.init(kind: .note, channel: 4, number: number, value: 127))
            ])
    }
    #expect(decoder.append([0x90, 60, 127, 0xB2, 60, 127, 0x92, 64, 127, 68, 127, 92, 127, 0x94, 36, 127]).isEmpty)
    #expect(decoder.append([0x92, 60, 127]).last == .message(.init(kind: .note, channel: 3, number: 64, value: 127)))
}

@Test func controllerSpectraTracksBankOwnershipFragmentsAndDecoderIsolation() {
    var first = ControllerSpectraDecoder()
    var second = ControllerSpectraDecoder()
    #expect(first.append([0x83, 1, 127]) == [.bankChanged])
    #expect(first.append([0x93, 2, 127]) == [.bankChanged])
    #expect(first.append([0x93, 2, 127]).isEmpty)
    #expect(first.append([0x83, 1, 127]).isEmpty)
    #expect(first.append([0x92, 54]).isEmpty)
    #expect(first.append([0xF8, 127]) == [.deckChanged])
    #expect(second.append([0x92, 60, 127]).last == .message(.init(kind: .note, channel: 0, number: 64, value: 127)))
    #expect(
        first.append([0xF0, 0, 32, 41, 0xF7, 0x92, 60, 127]).last
            == .message(.init(kind: .note, channel: 2, number: 64, value: 127)))
}
