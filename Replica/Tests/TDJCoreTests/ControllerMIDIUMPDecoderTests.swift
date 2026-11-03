import Testing
@testable import TDJCore

private func midi1UMP(group: UInt8, status: UInt8, data1: UInt8, data2: UInt8) -> UInt32 {
    0x20000000 | UInt32(group) << 24 | UInt32(status) << 16 | UInt32(data1) << 8 | UInt32(data2)
}

private func midi2UMP(group: UInt8, status: UInt8, channel: UInt8, byte2: UInt8, byte3: UInt8) -> UInt32 {
    0x40000000 | UInt32(group) << 24 | UInt32(status) << 20 | UInt32(channel) << 16
        | UInt32(byte2) << 8 | UInt32(byte3)
}

@Test func controllerUMPDecoderPreservesMIDI1GroupAndNoteRelease() {
    let words = [
        midi1UMP(group: 5, status: 0x93, data1: 60, data2: 100),
        midi1UMP(group: 5, status: 0x93, data1: 61, data2: 0),
        midi1UMP(group: 5, status: 0x83, data1: 60, data2: 64)
    ]
    let messages = ControllerMIDIUMPDecoder.decode(words)

    #expect(messages?.map(\.group) == [5, 5, 5])
    #expect(messages?.map(\.channel) == [3, 3, 3])
    #expect(messages?.map(\.number) == [60, 61, 60])
    #expect(messages?.map(\.isNoteOff) == [false, true, true])
    #expect(messages?.map(\.value) == [100, 0, 0])
}

@Test func controllerUMPDecoderPreservesMIDI2ResolutionAndPitchCentre() {
    let words = [
        midi2UMP(group: 2, status: 0xb, channel: 9, byte2: 74, byte3: 0),
        0xfedcba98,
        midi2UMP(group: 2, status: 0xe, channel: 9, byte2: 0, byte3: 0),
        0x80000000
    ]
    let messages = ControllerMIDIUMPDecoder.decode(words)

    #expect(messages?.count == 2)
    #expect(messages?[0].kind == .control)
    #expect(messages?[0].group == 2 && messages?[0].channel == 9 && messages?[0].number == 74)
    #expect(messages?[0].value == Int(0xfedcba98) && messages?[0].maximum == Int(UInt32.max))
    #expect(messages?[1].kind == .pitch)
    #expect(abs((messages?[1].normalized ?? 0) - 0.5) < 0.00000001)
}

@Test func controllerUMPDecoderRetainsRelativeRPNIdentityAndDirection() {
    let first = midi2UMP(group: 4, status: 0x4, channel: 6, byte2: 2, byte3: 3)
    let messages = ControllerMIDIUMPDecoder.decode([first, 0xfffffffe])
    let message = messages?.first

    #expect(message?.kind == .relativeRegisteredController)
    #expect(message?.group == 4 && message?.channel == 6)
    #expect(message?.parameter == 259 && message?.number == 3)
    #expect(message?.value == -2)
}

@Test func controllerUMPDecoderRetainsBankedProgramAndMIDI2NoteOnZeroVelocity() throws {
    let program = midi2UMP(group: 1, status: 0xc, channel: 2, byte2: 0, byte3: 1)
    let bankedProgramData: UInt32 = 17 << 24 | 4 << 8 | 5
    let noteOn = midi2UMP(group: 1, status: 0x9, channel: 2, byte2: 48, byte3: 0)
    let noteOff = midi2UMP(group: 1, status: 0x8, channel: 2, byte2: 48, byte3: 0)
    let messages = try #require(ControllerMIDIUMPDecoder.decode([program, bankedProgramData, noteOn, 0, noteOff, 0]))

    #expect(messages?.count == 3)
    #expect(messages?[0].kind == .program && messages?[0].number == 17)
    #expect(messages?[0].parameter == 517)
    #expect(messages[1].kind == .note && !messages[1].isNoteOff && messages[1].value == 0)
    #expect(messages[2].kind == .note && messages[2].isNoteOff)
}

@Test func controllerUMPDecoderSkipsReservedTypesUsingTheirAllocatedLengths() {
    let reservedTypes: [(UInt8, Int)] = [
        (0x6, 1), (0x7, 1), (0x8, 2), (0x9, 2), (0xa, 2),
        (0xb, 3), (0xc, 3), (0xe, 4)
    ]
    let disguisedNote: UInt32 = 0x20903c40
    let followingNote: UInt32 = 0x20903d40

    for (type, wordCount) in reservedTypes {
        let reservedPacket = [UInt32(type) << 28]
            + Array(repeating: disguisedNote, count: wordCount - 1)
        let messages = ControllerMIDIUMPDecoder.decode(reservedPacket + [followingNote])

        #expect(messages?.map(\.number) == [61])
        #expect(messages?.map(\.value) == [64])
    }
}

@Test func controllerUMPDecoderRejectsTruncatedReservedPackets() {
    let reservedTypes: [(UInt8, Int)] = [
        (0x8, 2), (0x9, 2), (0xa, 2), (0xb, 3), (0xc, 3), (0xe, 4)
    ]

    for (type, wordCount) in reservedTypes {
        let truncatedPacket = [UInt32(type) << 28]
            + Array(repeating: UInt32.zero, count: wordCount - 2)
        #expect(ControllerMIDIUMPDecoder.decode(truncatedPacket) == nil)
    }
}
