import Testing

@testable import TDJCore

@Test func midiFixedMixerEncodersRetainEverySourceValueAndRejectForeignMessages() {
    for name in ["smcMixerEncoder", "iconVelocity"] {
        let candidate = ControllerMIDIEncoding(rawValue: name)
        #expect(candidate != nil)
        guard let encoding = candidate else { continue }
        var state = ControllerMIDIValueState()
        for raw in 0...127 {
            let counts = name == "smcMixerEncoder" ? (raw == 65 ? -1.0 : 1) : Double(raw <= 64 ? raw : raw - 128)
            #expect(
                state.decode(
                    .init(kind: .control, channel: 0, number: 16, value: raw),
                    encoding: encoding, number: 16) == .relative(counts * 1.27))
        }
        for message in [
            ControllerMIDIMessage(kind: .note, channel: 0, number: 16, value: 127),
            .init(kind: .control, channel: 0, number: 17, value: 65),
            .init(kind: .control, channel: 0, number: 16, value: -1),
            .init(kind: .control, channel: 0, number: 16, value: 128),
            .init(kind: .control, channel: 0, number: 16, value: 65, maximum: 65535),
        ] {
            #expect(state.decode(message, encoding: encoding, number: 16) == nil)
        }
        #expect(encoding.isRelative && !encoding.supportsLearning)
    }
}
