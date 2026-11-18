import Testing

@testable import TDJCore

@Test func midiSMK25KeepsFragmentedSysexAndMixedStripOrder() {
    var decoder = ControllerSMK25Decoder()
    #expect(decoder.append([0xF0, 0x35, 0x59]).isEmpty)
    #expect(
        decoder.append([0x10, 94, 127, 0xF7]) == [.message(.init(kind: .note, channel: 0, number: 94, value: 127))])
    #expect(
        decoder.append([0xB0, 1, 64, 0xF0, 0x35, 0x59, 0x10, 47, 0, 0xF7, 0xE0, 0, 64]) == [
            .message(.init(kind: .control, channel: 0, number: 1, value: 64)), .deckChanged,
            .message(.init(kind: .pitch, channel: 1, number: 0, value: 8192)),
        ])
    #expect(
        decoder.append([0xF0, 0x35, 0x59, 0x60, 0, 127, 0xF7]) == [
            .message(.init(kind: .control, channel: 1, number: 30, value: 127))
        ])
    #expect(
        decoder.append([0xF0, 0x35, 0x59, 0x65, 0, 64, 0xF7]) == [
            .message(.init(kind: .control, channel: 0, number: 35, value: 64))
        ])
}

@Test func midiSMK25RejectsMalformedForeignAndSamplerTrafficWithoutLosingRecovery() {
    for bytes: [UInt8] in [
        [0xF0, 0x35, 0x59, 0x10, 94, 0xF7],
        [0xF0, 0x35, 0x58, 0x10, 94, 127, 0xF7],
        [0xF0, 0x35, 0x59, 0x11, 94, 127, 0xF7],
        [0xF0, 0x35, 0x59, 0x10, 120, 127, 0xF7],
        [0xF0, 0x35, 0x59, 0x10, 94, 127, 0, 0xF7],
        [0x99, 40, 127, 0x90, 94, 127],
        [0xF0] + Array(repeating: 1, count: 2048) + [0xF7],
    ] {
        var decoder = ControllerSMK25Decoder()
        #expect(decoder.append(bytes).isEmpty)
        #expect(decoder.append([0xF0, 0x35, 0x59, 0x10, 94, 127, 0xF7]).count == 1)
    }
}

@Test func midiSMK25SelectsOnlyOnReleasedSelectorsAndKeepsSourcesIndependent() {
    var first = ControllerSMK25Decoder()
    var second = ControllerSMK25Decoder()
    #expect(first.append([0xF0, 0x35, 0x59, 0x10, 47, 127, 0xF7]).isEmpty)
    #expect(first.append([0xF0, 0x35, 0x59, 0x10, 47, 0, 0xF7]) == [.deckChanged])
    #expect(first.append([0xF0, 0x35, 0x59, 0x10, 47, 0, 0xF7]).isEmpty)
    #expect(first.append([0xB0, 1, 127]) == [.message(.init(kind: .control, channel: 1, number: 1, value: 127))])
    #expect(second.append([0xB0, 1, 127]) == [.message(.init(kind: .control, channel: 0, number: 1, value: 127))])
    #expect(first.append([0xF0, 0x35, 0x59, 0x10, 46, 0, 0xF7]) == [.deckChanged])
}
