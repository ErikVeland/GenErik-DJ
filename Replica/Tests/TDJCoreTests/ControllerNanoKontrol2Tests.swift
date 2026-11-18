import Testing

@testable import TDJCore

private func nanoSearch(_ channel: UInt8) -> [UInt8] {
    [0xF0, 0x42, 0x50, 1, channel, 0x2D, 0x13, 1, 0, 0, 0, 0, 1, 0, 0xF7]
}
private func nanoAck(_ channel: UInt8, _ state: UInt8 = 3) -> [UInt8] {
    [0xF0, 0x42, 0x40 + channel, 0, 1, 0x13, 0, 0x40, 0, state, 0xF7]
}

@Test func controllerNanoKontrol2RequiresExactSearchAndNativeReplyOnEveryConfiguredGlobalChannel() {
    for channel: UInt8 in 0..<16 {
        var decoder = ControllerNanoKontrol2Decoder()
        #expect(!decoder.isReady && decoder.exitRequest == nil)
        #expect(decoder.append([0xBF, 0, 127, 64, 127]).isEmpty)
        #expect(decoder.append(nanoAck(channel)).isEmpty)
        #expect(
            decoder.append(nanoSearch(channel)) == [
                .request([0xF0, 0x42, 0x40 + channel, 0, 1, 0x13, 0, 0, 0, 1, 0xF7])
            ])
        #expect(decoder.append(nanoSearch(channel)).isEmpty)
        #expect(decoder.append(nanoAck((channel + 1) % 16)).isEmpty)
        #expect(!decoder.isReady && decoder.append([0xBF, 0, 127]).isEmpty)
        #expect(decoder.append(nanoAck(channel)) == [.modeChanged(true)])
        #expect(decoder.isReady)
        #expect(decoder.exitRequest == [0xF0, 0x42, 0x40 + channel, 0, 1, 0x13, 0, 0, 0, 0, 0xF7])
        #expect(decoder.append(nanoAck(channel)).isEmpty)
    }
}

@Test func controllerNanoKontrol2RejectsForeignMalformedAndOversizedSearchRepliesWithoutModeRequests() {
    let valid = nanoSearch(0)
    for index in [1, 2, 3, 4, 5, 6, 7, 8, 9] {
        var decoder = ControllerNanoKontrol2Decoder()
        var invalid = valid
        invalid[index] = index == 4 ? 16 : valid[index] + 1
        #expect(decoder.append(invalid).isEmpty)
        #expect(!decoder.isReady && decoder.exitRequest == nil)
    }
    var decoder = ControllerNanoKontrol2Decoder()
    for bytes: [UInt8] in [[0xF0, 0x42, 0xF7], [0xF0] + Array(repeating: 0, count: 4096) + [0xF7]] {
        #expect(decoder.append(bytes).isEmpty)
    }
    #expect(decoder.append(nanoSearch(15)).count == 1)
    #expect(decoder.append(nanoAck(15)) == [.modeChanged(true)])
}

@Test func controllerNanoKontrol2MapsOnlyReviewedFixedNativeControlsAndBothButtonEdges() {
    var decoder = ControllerNanoKontrol2Decoder()
    _ = decoder.append(nanoSearch(7) + nanoAck(7))
    for number: UInt8 in [0, 1, 2, 3, 18] {
        for value: UInt8 in [0, 64, 127] {
            #expect(
                decoder.append([0xBF, number, value]) == [
                    .message(.init(kind: .control, channel: 0, number: number, value: Int(value)))
                ])
        }
    }
    for number: UInt8 in [60, 61, 62, 64, 65, 66, 67] {
        #expect(
            decoder.append([0xBF, number, 127]) == [
                .message(.init(kind: .note, channel: 0, number: number, value: 127))
            ])
        #expect(
            decoder.append([0xBF, number, 0]) == [
                .message(.init(kind: .note, channel: 0, number: number, value: 0, isNoteOff: true))
            ])
        for value: UInt8 in [1, 64, 126] { #expect(decoder.append([0xBF, number, value]).isEmpty) }
    }
    for number: UInt8 in [
        4, 5, 6, 7, 16, 17, 19, 20, 21, 22, 23, 32, 48, 68, 69, 70, 71, 41, 42, 43, 44, 45, 46, 58, 59,
    ] {
        #expect(decoder.append([0xBF, number, 127]).isEmpty)
    }
    for channel: UInt8 in 0..<15 { #expect(decoder.append([0xB0 + channel, 0, 127, 64, 127]).isEmpty) }
    #expect(decoder.append([0x90, 64, 127, 0x9F, 64, 127, 0xEF, 127, 127]).isEmpty)
}

@Test func controllerNanoKontrol2NativeExitBlocksFurtherInputAndCannotReuseOldAcknowledgements() {
    var decoder = ControllerNanoKontrol2Decoder()
    _ = decoder.append(nanoSearch(4) + nanoAck(4))
    #expect(decoder.append(nanoAck(4, 2)) == [.modeChanged(false)])
    #expect(!decoder.isReady)
    #expect(decoder.append(nanoAck(4) + nanoSearch(4) + [0xBF, 64, 127]).isEmpty)
}

@Test func controllerNanoKontrol2FragmentsRealtimeRunningStatusAndSourcesRemainIndependent() {
    var first = ControllerNanoKontrol2Decoder()
    var second = ControllerNanoKontrol2Decoder()
    let search = nanoSearch(3)
    #expect(first.append(Array(search.prefix(8))).isEmpty)
    #expect(first.append([0xF8] + Array(search.dropFirst(8))).count == 1)
    let ack = nanoAck(3)
    #expect(first.append(Array(ack.prefix(6))).isEmpty)
    #expect(first.append(Array(ack.dropFirst(6))) == [.modeChanged(true)])
    #expect(second.append(ack + [0xBF, 64, 127]).isEmpty)
    #expect(first.append([0xBF, 64]).isEmpty)
    #expect(first.append([0xF8, 127, 64, 0]).count == 2)
    first = .init()
    #expect(first.append([127, 0xBF, 64, 127]).isEmpty)
}
