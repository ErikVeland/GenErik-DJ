import Testing

@testable import TDJCore

@Test func midiNDX500JogsKeepThePublishedCentre63AndDirection() {
    let encoding = ControllerMIDIEncoding(rawValue: "ndx500Jog")
    #expect(encoding != nil)
    guard let encoding else { return }
    var state = ControllerMIDIValueState()
    for (raw, counts) in [(0, 63), (62, 1), (63, 0), (64, -1), (127, -64)] {
        #expect(
            state.decode(.init(kind: .control, channel: 0, number: 34, value: raw), encoding: encoding, number: 34)
                == .relative(Double(counts)))
    }
    #expect(encoding.isRelative && !encoding.supportsLearning)
}

@Test func midiNDX500BrowserKeepsTheSourceOneForwardRule() {
    let encoding = ControllerMIDIEncoding(rawValue: "ndx500Browse")
    #expect(encoding != nil)
    guard let encoding else { return }
    var state = ControllerMIDIValueState()
    for raw in [0, 1, 2, 63, 64, 65, 127] {
        #expect(
            state.decode(.init(kind: .control, channel: 0, number: 33, value: raw), encoding: encoding, number: 33)
                == .relative(raw == 1 ? 1 : -1))
    }
    #expect(encoding.isRelative && !encoding.supportsLearning)
}

@Test func midiNDX500DecodersRejectForeignMessagesAndHighResolutionValues() {
    for name in ["ndx500Jog", "ndx500Browse"] {
        guard let encoding = ControllerMIDIEncoding(rawValue: name) else { continue }
        var state = ControllerMIDIValueState()
        for message in [
            ControllerMIDIMessage(kind: .note, channel: 0, number: 34, value: 127),
            .init(kind: .control, channel: 0, number: 35, value: 1),
            .init(kind: .control, channel: 0, number: 34, value: -1),
            .init(kind: .control, channel: 0, number: 34, value: 128),
            .init(kind: .control, channel: 0, number: 34, value: 1, maximum: 65535),
        ] {
            #expect(state.decode(message, encoding: encoding, number: 34) == nil)
        }
    }
}
