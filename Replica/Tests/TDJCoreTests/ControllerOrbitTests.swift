import TDJCore
import Testing

@Test func controllerOrbitBankChangesPrecedeNewPadsAndIgnoreLateReleases() {
    var decoder = ControllerOrbitDecoder()
    #expect(decoder.append([0x90, 45, 127]).count == 1)
    let events = decoder.append([0x91, 44, 127]); #expect(events.count == 2 && events.first == .bankChanged)
    #expect(decoder.append([0x80, 45, 127, 0x90, 45, 0]).count == 2)
    #expect(decoder.append([0x91, 44, 127]).count == 1)
    #expect(decoder.append([0x92, 36, 127]).first == .bankChanged)
    #expect(decoder.append([0x93, 51, 1]).first == .bankChanged)
}

@Test func controllerOrbitFramesRawPadsAndRejectsUnqualifiedBankSignals() {
    var decoder = ControllerOrbitDecoder(); var events: [ControllerOrbitEvent] = []
    for byte: UInt8 in [0x90, 45, 127, 0xF8, 45, 0, 0xB1, 4, 127, 0x94, 36, 127, 0x93, 35, 127, 0x90, 44, 127] {
        events += decoder.append([byte])
    }
    #expect(events.count == 6)
    #expect(
        events.allSatisfy {
            if case .message = $0 { return true }; return false
        })
}
