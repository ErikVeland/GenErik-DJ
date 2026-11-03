import Testing
@testable import TDJCore

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
