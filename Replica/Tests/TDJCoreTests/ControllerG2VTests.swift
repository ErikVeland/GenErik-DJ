import Testing

@testable import TDJCore

@Test func midiG2VBrowserKeepsSourceBoundaryAndRejectsForeignValues() {
    let candidate = ControllerMIDIEncoding(rawValue: "g2vBrowse")
    #expect(candidate != nil)
    guard let encoding = candidate else { return }
    var state = ControllerMIDIValueState()
    for raw in [0, 1, 63, 64, 65, 66, 127] {
        #expect(
            state.decode(
                .init(kind: .control, channel: 3, number: 30, value: raw),
                encoding: encoding, number: 30) == .relative(raw > 64 ? 1 : -1))
    }
    for message in [
        ControllerMIDIMessage(kind: .note, channel: 3, number: 30, value: 127),
        .init(kind: .control, channel: 3, number: 31, value: 65),
        .init(kind: .control, channel: 3, number: 30, value: -1),
        .init(kind: .control, channel: 3, number: 30, value: 128),
        .init(kind: .control, channel: 3, number: 30, value: 65, maximum: 65535),
    ] {
        #expect(state.decode(message, encoding: encoding, number: 30) == nil)
    }
    #expect(encoding.isRelative && !encoding.supportsLearning)
}
