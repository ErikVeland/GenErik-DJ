import Testing

@testable import TDJCore

@Test func midiUnsignedCountPreservesEverySevenBitMovementCount() throws {
    let encoding = try #require(ControllerMIDIEncoding(rawValue: "unsignedCount"))
    #expect(encoding.isRelative && !encoding.supportsLearning)
    var state = ControllerMIDIValueState()
    for value in 0...127 {
        let decoded = state.decode(
            .init(kind: .control, channel: 0, number: 16, value: value), encoding: encoding, number: 16)
        #expect(decoded == (value == 0 ? nil : .relative(Double(value))))
    }
}

@Test func midiUnsignedCountRejectsForeignMessagesAndInvalidRanges() throws {
    let encoding = try #require(ControllerMIDIEncoding(rawValue: "unsignedCount"))
    var state = ControllerMIDIValueState()
    for message in [
        ControllerMIDIMessage(kind: .note, channel: 0, number: 16, value: 127),
        .init(kind: .control, channel: 0, number: 17, value: 127),
        .init(kind: .control, channel: 0, number: 16, value: -1),
        .init(kind: .control, channel: 0, number: 16, value: 128),
        .init(kind: .control, channel: 0, number: 16, value: 1, maximum: 65535),
    ] {
        #expect(state.decode(message, encoding: encoding, number: 16) == nil)
    }
}
