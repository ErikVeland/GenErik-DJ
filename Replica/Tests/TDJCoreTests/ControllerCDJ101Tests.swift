import Testing

@testable import TDJCore

@Test func controllerCDJ101PreservesEveryBrowserSourceValueAndPitchResolution() {
    var decoder = ControllerCDJ101Decoder()
    for channel: UInt8 in 0...1 {
        for raw: UInt8 in 0...127 {
            #expect(
                decoder.append([0xB0 + channel, 56, raw], timestamp: 1) == [
                    .init(kind: .control, channel: channel, number: 56, value: raw == 65 ? 1 : 127)
                ])
        }
        #expect(
            decoder.append([0xE0 + channel, 127, 127], timestamp: 1) == [
                .init(kind: .pitch, channel: channel, number: 0, value: 16383)
            ])
    }
}

@Test func controllerCDJ101LoadRequiresOwnedShortReleaseAndRejectsRepeatRetiming() {
    for elapsed: UInt64 in [0, 1, 199_999_999, 200_000_000, 300_000_000] {
        var decoder = ControllerCDJ101Decoder()
        _ = decoder.append([0x90, 31, 127], timestamp: 100)
        let messages = decoder.append([0x90, 31, 0], timestamp: 100 + elapsed)
        #expect(messages.first?.number == 31 && messages.first?.isNoteOff == true)
        #expect(messages.filter { $0.number == 126 }.count == (elapsed < 200_000_000 ? 2 : 0))
        #expect(decoder.append([0x80, 31, 127], timestamp: 101 + elapsed).count == 1)
    }
    var decoder = ControllerCDJ101Decoder()
    _ = decoder.append([0x90, 31, 127], timestamp: 100)
    _ = decoder.append([0x90, 31, 127], timestamp: 250_000_100)
    #expect(decoder.append([0x80, 31, 0], timestamp: 300_000_100).count == 1)
    _ = decoder.append([0x90, 31, 127], timestamp: 500)
    #expect(decoder.append([0x80, 31, 0], timestamp: 499).count == 1)
}

@Test func controllerCDJ101KeepsFragmentAndClickStatePerDecoderAndChannel() {
    var first = ControllerCDJ101Decoder()
    var second = ControllerCDJ101Decoder()
    #expect(first.append([0x90, 31], timestamp: 100).isEmpty)
    #expect(first.append([0xF8, 127], timestamp: 110).count == 1)
    _ = first.append([0x91, 31, 127], timestamp: 300_000_110)
    #expect(first.append([0x90, 31, 0], timestamp: 300_000_120).count == 1)
    #expect(first.append([0x81, 31, 127], timestamp: 300_000_130).count == 3)
    #expect(second.append([0x90, 31, 0], timestamp: 300_000_140).count == 1)
    first = .init()
    #expect(first.append([0x90, 31, 0], timestamp: 300_000_140).count == 1)
}

@Test func controllerCDJ101RejectsForeignChannelsControlsAndRawLogicalLoadInjection() {
    var decoder = ControllerCDJ101Decoder()
    #expect(decoder.append([0x92, 31, 127, 42, 127, 0x90, 126, 127, 0xB0, 42, 127, 55, 127], timestamp: 1).isEmpty)
    #expect(
        decoder.append([0xF0, 0, 32, 41, 0xF7, 0x90, 42, 127], timestamp: 1) == [
            .init(kind: .note, channel: 0, number: 42, value: 127)
        ])
}
