import Testing

@testable import TDJCore

@Test func controllerKeyLabDecodesOnlyBoundedBroadcastMMCAndPreservesFragmentOrder() {
    for command: UInt8 in [1, 2, 4, 5, 55] {
        var decoder = ControllerKeyLabDecoder()
        #expect(decoder.append([0xF0, 0x7F, 0x7F], timestamp: 1).isEmpty)
        #expect(
            decoder.append([6, 0xF8, command, 0xF7], timestamp: 1) == [
                .message(.init(kind: .note, channel: 0, number: command, value: 127)),
                .message(.init(kind: .note, channel: 0, number: command, value: 0, isNoteOff: true)),
            ])
    }
    for bytes: [UInt8] in [
        [0xF0, 0x7F, 0, 6, 2, 0xF7], [0xF0, 0x7E, 0x7F, 6, 2, 0xF7],
        [0xF0, 0x7F, 0x7F, 7, 2, 0xF7], [0xF0, 0x7F, 0x7F, 6, 6, 0xF7],
        [0xF0, 0x7F, 0x7F, 6, 2, 0, 0xF7], [0xF0] + Array(repeating: 1, count: 2048) + [0xF7],
    ] {
        var decoder = ControllerKeyLabDecoder()
        #expect(decoder.append(bytes, timestamp: 1).isEmpty)
        #expect(decoder.append([0xF0, 0x7F, 0x7F, 6, 2, 0xF7], timestamp: 1).count == 2)
    }
}

@Test func controllerKeyLabUsesSource275msDeckSelectionWithoutRepeatRetiming() {
    for elapsed: UInt64 in [1, 274_999_999, 275_000_000, 500_000_000] {
        var decoder = ControllerKeyLabDecoder()
        _ = decoder.append([0xB0, 118, 127], timestamp: 100)
        _ = decoder.append([0xB0, 118, 0], timestamp: 100 + elapsed)
        let messages = decoder.append([0xF0, 0x7F, 0x7F, 6, 2, 0xF7], timestamp: 200 + elapsed)
        #expect(
            messages.first
                == .message(.init(kind: .note, channel: elapsed >= 275_000_000 ? 2 : 0, number: 2, value: 127)))
    }
    var decoder = ControllerKeyLabDecoder()
    _ = decoder.append([0xB0, 119, 127], timestamp: 1)
    _ = decoder.append([0xB0, 119, 127], timestamp: 200_000_001)
    _ = decoder.append([0xB0, 119, 0], timestamp: 300_000_001)
    #expect(
        decoder.append([0xB0, 74, 127], timestamp: 300_000_002) == [
            .message(.init(kind: .control, channel: 3, number: 74, value: 127))
        ])
}

@Test func controllerKeyLabKeepsFixedFadersAndSwitchesOnlyReleasedCueLayouts() {
    var decoder = ControllerKeyLabDecoder()
    #expect(
        decoder.append([0xB0, 73, 127, 75, 0, 7, 64], timestamp: 1) == [
            .message(.init(kind: .control, channel: 4, number: 73, value: 127)),
            .message(.init(kind: .control, channel: 4, number: 75, value: 0)),
            .message(.init(kind: .control, channel: 4, number: 7, value: 64)),
        ])
    #expect(
        decoder.append([0x99, 44, 127], timestamp: 1) == [
            .message(.init(kind: .note, channel: 0, number: 64, value: 127))
        ])
    #expect(decoder.append([0x99, 48, 127, 36, 127], timestamp: 1).isEmpty)
    #expect(decoder.append([0xB0, 23, 127], timestamp: 1).isEmpty)
    #expect(decoder.append([0xB0, 23, 0], timestamp: 1) == [.padLayerChanged])
    #expect(
        decoder.append([0x99, 48, 127], timestamp: 1) == [
            .message(.init(kind: .note, channel: 0, number: 64, value: 127))
        ])
    #expect(decoder.append([0xB0, 24, 0, 0x99, 48, 127], timestamp: 1) == [.padLayerChanged])
    #expect(decoder.append([0xB0, 22, 0], timestamp: 1) == [.padLayerChanged])
}

@Test func controllerKeyLabRejectsOrdinaryKeyboardModWheelAndLogicalInjectionAndResetsSelection() {
    var decoder = ControllerKeyLabDecoder()
    #expect(
        decoder.append(
            [0x90, 48, 127, 2, 127, 0xB0, 1, 127, 2, 127, 4, 127, 5, 127, 55, 127, 0xB4, 73, 127], timestamp: 1
        ).isEmpty)
    _ = decoder.append([0xB0, 119, 127, 119, 0], timestamp: 1)
    decoder = .init()
    #expect(
        decoder.append([0xF0, 0x7F, 0x7F, 6, 2, 0xF7], timestamp: 1).first
            == .message(.init(kind: .note, channel: 0, number: 2, value: 127)))
}
