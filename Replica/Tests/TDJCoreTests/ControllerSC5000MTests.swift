import Testing

@testable import TDJCore

@Test func controllerSC5000MLayerStartsAChangesOnFreshPressAndKeepsPadModePerDeck() {
    var decoder = ControllerSC5000MDecoder()
    #expect(decoder.append([0x90, 1, 127]).first == .message(.init(kind: .note, channel: 0, number: 1, value: 127)))
    #expect(decoder.append([0x90, 30, 127]) == [.padModeChanged])
    #expect(decoder.append([0x90, 11, 127, 11, 127]) == [.deckChanged])
    #expect(decoder.append([0x90, 32, 127]).first == .message(.init(kind: .note, channel: 1, number: 64, value: 127)))
    #expect(decoder.append([0x80, 11, 127, 0x90, 11, 127]) == [.deckChanged])
    #expect(decoder.append([0x90, 33, 127]).first == .message(.init(kind: .note, channel: 0, number: 81, value: 127)))
}

@Test func controllerSC5000MAllPadAddressesRetainOriginalDeckAndModeOnRelease() {
    for mode: UInt8 in [27, 30] {
        for slot: UInt8 in 0..<8 {
            for velocity: UInt8 in [0, 1, 64, 127] {
                var decoder = ControllerSC5000MDecoder()
                _ = decoder.append([0x90, mode, 127, mode, 0])
                let logical = slot + (mode == 27 ? 64 : 80)
                #expect(
                    decoder.append([0x90, 32 + slot, 127]) == [
                        .message(.init(kind: .note, channel: 0, number: logical, value: 127))
                    ])
                _ = decoder.append([0x90, 11, 127, 28, 127])
                #expect(
                    decoder.append([0x80, 32 + slot, velocity]) == [
                        .message(.init(kind: .note, channel: 0, number: logical, value: 0, isNoteOff: true))
                    ])
            }
        }
    }
}

@Test func controllerSC5000MBlocksRollSlicerMotorCountersPitchAndAbsentTouch() {
    var decoder = ControllerSC5000MDecoder()
    for mode: UInt8 in [28, 29] {
        _ = decoder.append([0x90, mode, 127, mode, 0])
        for slot: UInt8 in 0..<8 { #expect(decoder.append([0x90, 32 + slot, 127, 32 + slot, 0]).isEmpty) }
    }
    for value: UInt8 in 0...127 {
        for cc: UInt8 in [8, 17, 40, 49, 54, 55, 64, 65, 66, 67, 68] {
            #expect(decoder.append([0xB0, cc, value]).isEmpty)
        }
        #expect(decoder.append([0xE0, value, value, 0x90, 40, value, 56, value]).isEmpty)
    }
    #expect(decoder.append([0x91, 11, 127, 32, 127, 0x94, 26, 127, 0xB1, 6, 1, 0x90, 64, 127, 80, 127]).isEmpty)
}

@Test func controllerSC5000MTransportReleasesStayWithPressedDeckAndShiftStaysGlobal() {
    var decoder = ControllerSC5000MDecoder()
    _ = decoder.append([0x90, 2, 127, 26, 127, 11, 127])
    #expect(
        decoder.append([0x80, 2, 127]) == [
            .message(.init(kind: .note, channel: 0, number: 2, value: 0, isNoteOff: true))
        ])
    #expect(
        decoder.append([0x80, 26, 127]) == [
            .message(.init(kind: .note, channel: 4, number: 26, value: 0, isNoteOff: true))
        ])
    #expect(
        decoder.append([0xB0, 3, 1, 6, 127]) == [
            .message(.init(kind: .control, channel: 1, number: 3, value: 1)),
            .message(.init(kind: .control, channel: 1, number: 6, value: 127)),
        ])
}

@Test func controllerSC5000MFragmentsRunningStatusRealtimeAndSourcesRemainIndependent() {
    var first = ControllerSC5000MDecoder()
    var second = ControllerSC5000MDecoder()
    #expect(first.append([0x90, 11]).isEmpty)
    #expect(first.append([0xF8, 127]) == [.deckChanged])
    #expect(first.append([11, 0, 1, 127]).last == .message(.init(kind: .note, channel: 1, number: 1, value: 127)))
    #expect(second.append([0x90, 1, 127]).last == .message(.init(kind: .note, channel: 0, number: 1, value: 127)))
    first = .init()
    #expect(first.append([127]).isEmpty)
    #expect(first.append([0x90, 32, 127]).last == .message(.init(kind: .note, channel: 0, number: 64, value: 127)))
}
