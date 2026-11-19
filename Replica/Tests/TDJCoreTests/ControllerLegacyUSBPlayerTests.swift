import TDJCore
import Testing

@Test func controllerLegacyUSBPlayerObservesIndependentDeckAndMixerContexts() {
    var decoder = ControllerLegacyUSBPlayerDecoder()
    #expect(decoder.append([0xB0, 17, 64, 0xB2, 33, 64, 0xB1, 48, 64]).count == 3)
    #expect(decoder.append([0xB0, 80, 64]).first == .controlsChanged(0))
    #expect(decoder.append([0xB0, 80, 65]).count == 1)
    #expect(decoder.append([0xB2, 33, 65, 0xB1, 48, 65]).count == 2)
    #expect(decoder.append([0xB2, 96, 64]).first == .controlsChanged(2))
    #expect(decoder.append([0xB1, 111, 64]).first == .controlsChanged(1))
    #expect(decoder.append([0xB0, 17, 64]).first == .controlsChanged(0))
}

@Test func controllerLegacyUSBPlayerLateReleasesAndExcludedControlsDoNotSelectLayers() {
    var decoder = ControllerLegacyUSBPlayerDecoder()
    _ = decoder.append([0xB0, 80, 64])
    #expect(decoder.append([0x80, 31, 127, 0x90, 32, 0, 30, 127, 33, 127, 0xB3, 17, 64, 0xE0, 0, 127]).count == 6)
    #expect(decoder.append([0xB0, 80, 65]).count == 1)
    #expect(decoder.append([0x90, 94, 127]).count == 1)
    #expect(decoder.append([0x90, 31, 127]).first == .controlsChanged(0))
}

@Test func controllerLegacyUSBPlayerFramesRunningStatusWithoutChangingRawWires() {
    var decoder = ControllerLegacyUSBPlayerDecoder(); var events: [ControllerLegacyUSBPlayerEvent] = []
    for byte: UInt8 in [0x90, 31, 127, 0xF8, 31, 0, 94, 127, 94, 0, 0xB0, 17, 64] { events += decoder.append([byte]) }
    let messages = events.compactMap { event -> ControllerMIDIMessage? in
        if case .message(let m) = event { return m }; return nil
    }
    #expect(messages.map(\.number) == [31, 31, 94, 94, 17])
    #expect(
        events.filter {
            if case .controlsChanged(0) = $0 { return true }; return false
        }.count == 2)
}
