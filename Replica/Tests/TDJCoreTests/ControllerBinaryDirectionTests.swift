import Testing

@testable import TDJCore

@Test func midiBinaryDirectionUsesOneStepForEitherMagnitudeAndIgnoresItsCentre() {
    var state = ControllerMIDIValueState()
    for (raw, expected): (Int, ControllerMIDIValue?) in [
        (0, .relative(-1)), (1, .relative(-1)), (62, .relative(-1)), (63, .relative(-1)),
        (64, nil), (65, .relative(1)), (66, .relative(1)), (126, .relative(1)), (127, .relative(1)),
        (-1, nil), (128, nil),
    ] {
        let message = ControllerMIDIMessage(kind: .control, channel: 2, number: 6, value: raw, maximum: 127)
        #expect(state.decode(message, encoding: .binaryDirection, number: 6) == expected)
    }
    #expect(ControllerMIDIEncoding.binaryDirection.isRelative)
    #expect(!ControllerMIDIEncoding.binaryDirection.isPairedCC)
    let wrongRange = ControllerMIDIMessage(kind: .control, channel: 2, number: 6, value: 1, maximum: 16383)
    #expect(state.decode(wrongRange, encoding: .binaryDirection, number: 6) == nil)
}
