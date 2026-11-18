import Testing

@testable import TDJCore

@Test func controllerSR2StartsUnknownAndRoutesLoadOnlyAfterIndependentPositiveSelectors() {
    var decoder = ControllerSR2Decoder()
    #expect(decoder.append([0x96, 70, 127, 70, 0, 71, 127, 71, 0]).isEmpty)
    #expect(decoder.append([0x92, 86, 127, 0x91, 85, 127]) == [.bankChanged(left: true), .bankChanged(left: false)])
    #expect(
        decoder.append([0x96, 70, 127, 0x86, 70, 127, 0x96, 71, 127, 71, 0]) == [
            .message(.init(kind: .note, channel: 2, number: 126, value: 127)),
            .message(.init(kind: .note, channel: 2, number: 126, value: 0, isNoteOff: true)),
            .message(.init(kind: .note, channel: 1, number: 126, value: 127)),
            .message(.init(kind: .note, channel: 1, number: 126, value: 0, isNoteOff: true)),
        ])
    #expect(decoder.append([0x92, 87, 127]) == [.bankChanged(left: true)])
    #expect(decoder.append([0x96, 70, 127, 70, 0]).isEmpty)
    #expect(decoder.append([0x96, 71, 127]).count == 1)
}

@Test func controllerSR2ClearsCurrentBankOnEitherReleaseButIgnoresUnrelatedOrWrongPositiveSelectors() {
    var decoder = ControllerSR2Decoder()
    #expect(decoder.append([0x92, 85, 127, 0x90, 86, 127]) == [.bankChanged(left: true), .bankChanged(left: true)])
    _ = decoder.append([0x90, 85, 127, 0x93, 86, 127])
    #expect(decoder.append([0x92, 86, 0, 0x91, 85, 0]).isEmpty)
    #expect(decoder.append([0x92, 85, 0]) == [.bankChanged(left: true)])
    #expect(decoder.append([0x96, 70, 127]).isEmpty)
    #expect(decoder.append([0x91, 86, 0]) == [.bankChanged(left: false)])
    #expect(decoder.append([0x96, 71, 127]).isEmpty)
}

@Test func controllerSR2RetainsFragmentsAndOrdinaryDataWithoutRawLogicalLoadOrShiftedLoadInjection() {
    var first = ControllerSR2Decoder()
    var second = ControllerSR2Decoder()
    #expect(first.append([0x90, 85]).isEmpty)
    #expect(first.append([0xF8, 127]) == [.bankChanged(left: true)])
    #expect(first.append([0x96, 70, 127]).count == 1)
    #expect(second.append([0x96, 70, 127]).isEmpty)
    #expect(first.append([0x90, 126, 127, 126, 0, 0x96, 88, 127, 89, 127]).isEmpty)
    #expect(
        first.append([0xB2, 4, 3, 36, 127, 0x92, 11, 127]) == [
            .message(.init(kind: .control, channel: 2, number: 4, value: 3)),
            .message(.init(kind: .control, channel: 2, number: 36, value: 127)),
            .message(.init(kind: .note, channel: 2, number: 11, value: 127)),
        ])
    first = .init()
    #expect(first.append([0x96, 70, 127]).isEmpty)
}
