import TDJCore
import Testing

@Test func controllerLaunchControlDAWGatesCustomModesAndRetiresEveryModeChange() {
    var decoder = ControllerLaunchControlDAWDecoder()
    #expect(decoder.isReady)
    #expect(decoder.append([0xBF, 13, 64]).count == 1)
    #expect(decoder.append([0xB6, 30, 6]) == [.modeChanged(false)])
    #expect(!decoder.isReady)
    #expect(decoder.append([0xBF, 13, 127, 0xB0, 38, 127]).isEmpty)
    #expect(decoder.append([0xB6, 30, 1]) == [.modeChanged(true)])
    #expect(decoder.append([0xB6, 30, 1]).isEmpty)
    #expect(decoder.append([0xB6, 30, 2]) == [.modeChanged(true)])
    #expect(decoder.append([0xB6, 30, 0]) == [.modeChanged(false)])
    #expect(decoder.append([0xB6, 30, 127]) == [.modeChanged(false)])
}

@Test func controllerLaunchControlDAWFramesSplitRunningStatusAndIgnoresNotesAndForeignModeChannels() {
    var decoder = ControllerSetupInputDecoder(mode: .launchControlDAW)
    var events: [ControllerKorgNativeEvent] = []
    for byte: UInt8 in [0xB6, 30, 0xF8, 6, 0xBF, 13, 127, 0xB6, 30, 2, 0xB0, 38, 127, 38, 0] {
        events += decoder.append([byte])
    }
    #expect(events.count == 4 && events.prefix(2) == [.modeChanged(false), .modeChanged(true)])
    #expect(decoder.isReady && decoder.exitRequest == nil && decoder.pendingRequest == nil)
    #expect(decoder.append([0xB5, 30, 6]).count == 1 && decoder.isReady)
    #expect(decoder.append([0x90, 38, 127, 0x80, 38, 0, 0xF0, 0, 32, 41, 2, 22, 2, 0, 0xF7]).isEmpty)
    #expect(decoder.isReady)
}

@Test func controllerLaunchControlDAWDoesNotPassCustomTrafficFromOneMixedBatch() {
    var decoder = ControllerLaunchControlDAWDecoder()
    let events = decoder.append([0xB6, 30, 6, 0xB0, 38, 127, 0xBF, 13, 0, 0xB6, 30, 2, 0xB0, 38, 127])
    #expect(events.count == 3 && events.prefix(2) == [.modeChanged(false), .modeChanged(true)])
    #expect(events.last == .message(.init(kind: .note, channel: 0, number: 38, value: 127)))
}

@Test func controllerLaunchControlDAWNormalisesOnlyExactMomentarySurfaceReports() {
    var decoder = ControllerLaunchControlDAWDecoder()
    #expect(decoder.append([0xB0, 38, 1, 38, 64, 38, 126]).isEmpty)
    #expect(
        decoder.append([0xB0, 38, 127, 38, 0]) == [
            .message(.init(kind: .note, channel: 0, number: 38, value: 127)),
            .message(.init(kind: .note, channel: 0, number: 38, value: 0, isNoteOff: true)),
        ])
    #expect(decoder.append([0xB1, 38, 127]) == [.message(.init(kind: .control, channel: 1, number: 38, value: 127))])
}
