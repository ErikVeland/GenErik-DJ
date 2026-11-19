import Testing

@testable import TDJCore

@Test func controllerP1NanoEncoderPreservesEverySourceCountAndRejectsOtherFormats() {
    #expect(ControllerMIDIEncoding.p1NanoEncoder.isRelative)
    #expect(!ControllerMIDIEncoding.p1NanoEncoder.supportsLearning)
    var state = ControllerMIDIValueState()
    for raw in 0...127 {
        let value = state.decode(
            .init(kind: .control, channel: 0, number: 16, value: raw), encoding: .p1NanoEncoder, number: 16)
        #expect(value == .relative(Double(raw < 64 ? raw : 64 - raw) * 1.27))
    }
    for message in [
        ControllerMIDIMessage(kind: .note, channel: 0, number: 16, value: 1),
        .init(kind: .control, channel: 0, number: 17, value: 1),
        .init(kind: .control, channel: 0, number: 16, value: 128),
        .init(kind: .control, channel: 0, number: 16, value: 1, maximum: 65535),
    ] { #expect(state.decode(message, encoding: .p1NanoEncoder, number: 16) == nil) }
}

@Test func controllerP1NanoDeckSelectionRetainsBothCueReleaseFormsAndFullFaderResolution() {
    var decoder = ControllerP1NanoDecoder()
    for deck: UInt8 in 0...3 {
        _ = decoder.append([0x90, 24 + deck, 127])
        #expect(
            decoder.append([0x90, 93, 127]) == [.message(.init(kind: .note, channel: deck, number: 93, value: 127))])
        #expect(
            decoder.append([0x80, 93, 127]) == [
                .message(.init(kind: .note, channel: deck, number: 93, value: 0, isNoteOff: true))
            ])
        #expect(
            decoder.append([0xE0 + deck, 127, 127]) == [
                .message(.init(kind: .pitch, channel: deck, number: 0, value: 16383))
            ])
        #expect(decoder.append([0x80, 24 + (deck + 1) % 4, 127]).isEmpty)
    }
}

@Test func controllerP1NanoFlipIsLatchedWithoutRepeatTogglesAndKeepsIndependentKnobModes() {
    var decoder = ControllerP1NanoDecoder()
    #expect(decoder.append([0x90, 50, 127, 50, 127, 50, 0]) == [.controlsChanged])
    #expect(decoder.append([0xE0, 0, 64]) == [.message(.init(kind: .pitch, channel: 4, number: 0, value: 8192))])
    #expect(decoder.append([0xB0, 16, 1, 17, 65, 16, 1]) == [.controlsChanged, .controlsChanged, .controlsChanged])
    #expect(decoder.append([0x90, 50, 127, 50, 0]) == [.controlsChanged])
    for (physical, logical): (UInt8, UInt8) in [(16, 18), (17, 20), (18, 16), (19, 16)] {
        #expect(
            decoder.append([0xB0, physical, 3]) == [
                .message(.init(kind: .control, channel: physical - 16, number: logical, value: 3))
            ])
    }
}

@Test func controllerP1NanoRejectsForeignAndLogicalInjectionAndKeepsStatePerDecoder() {
    var first = ControllerP1NanoDecoder()
    var second = ControllerP1NanoDecoder()
    #expect(first.append([0x90, 27]).isEmpty)
    #expect(first.append([0xF8, 127]) == [.controlsChanged])
    #expect(
        first.append([0x91, 94, 127, 0xE4, 0, 64, 0xE8, 0, 64, 0xB1, 16, 127, 0xB0, 20, 127, 60, 1, 0x93, 0, 127])
            .isEmpty)
    #expect(
        first.append([0xF0, 0, 0, 102, 20, 0xF7, 0x90, 94, 127]).last
            == .message(.init(kind: .note, channel: 3, number: 94, value: 127)))
    #expect(second.append([0x90, 94, 127]).last == .message(.init(kind: .note, channel: 0, number: 94, value: 127)))
}
