import TDJCore
import Testing

@Test func controllerLegacySinglePlayerFramesAndRetiresChangedBankBeforeItsMessage() {
    var decoder = ControllerLegacySinglePlayerDecoder()
    #expect(decoder.append([0x90, 46, 127]).count == 1)
    let events = decoder.append([0x91, 46, 127])
    #expect(events.count == 2 && events.first == .controlsChanged)
    #expect(decoder.append([0x80, 46, 127, 0x90, 46, 0]).count == 2)
    #expect(decoder.append([0xB1, 53, 65]).count == 1)
    #expect(decoder.append([0xB0, 53, 65]).first == .controlsChanged)
}

@Test func controllerLegacySinglePlayerShiftFamiliesAndModeEdgesIgnoreUnqualifiedChannels() {
    var decoder = ControllerLegacySinglePlayerDecoder()
    _ = decoder.append([0x90, 46, 127])
    #expect(decoder.append([0x90, 109, 127]).first == .controlsChanged)
    #expect(decoder.append([0x90, 109, 0]).count == 1)
    #expect(decoder.append([0x90, 46, 127]).first == .controlsChanged)
    #expect(decoder.append([0x90, 69, 127]).first == .controlsChanged)
    #expect(decoder.append([0x80, 69, 127]).first == .controlsChanged)
    #expect(decoder.append([0x90, 36, 127]).first == .controlsChanged)
    #expect(decoder.append([0x80, 36, 127]).count == 1)
    #expect(decoder.append([0x92, 69, 127, 0xB2, 53, 65, 0x90, 7, 127]).count == 3)
    #expect(decoder.append([0x90, 46, 127]).count == 1)
}

@Test func controllerLegacySinglePlayerKeepsRawRunningStatusAndRealTimeFraming() {
    var decoder = ControllerLegacySinglePlayerDecoder(); var events: [ControllerLegacySinglePlayerEvent] = []
    for byte: UInt8 in [0x90, 46, 127, 0xF8, 46, 0, 0xB1, 53, 67] { events += decoder.append([byte]) }
    let messages = events.compactMap { event -> ControllerMIDIMessage? in
        if case .message(let message) = event { return message }; return nil
    }
    #expect(messages.map(\.number) == [46, 46, 53])
    #expect(events.count == 4)
}
