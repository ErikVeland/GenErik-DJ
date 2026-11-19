import TDJCore
import Testing

@Test func controllerMC1000KeepsDeckAndShiftChangesOnTheirOwnPhysicalSide() {
    var decoder = ControllerMC1000Decoder()
    #expect(decoder.append([0xB0, 5, 64]).count == 1)
    #expect(decoder.append([0xB1, 5, 64]).count == 1)
    #expect(decoder.append([0xB2, 5, 64]).first == .controlsChanged(true))
    #expect(decoder.append([0xB3, 5, 64]).first == .controlsChanged(false))
    #expect(decoder.append([0xB2, 68, 64]).first == .controlsChanged(true))
    #expect(decoder.append([0xB2, 68, 65]).count == 1)
    #expect(decoder.append([0xB2, 5, 64]).first == .controlsChanged(true))
    #expect(decoder.append([0xB3, 5, 65]).count == 1)
}

@Test func controllerMC1000GlobalTrafficAndLateReleasesCannotSelectDecks() {
    var decoder = ControllerMC1000Decoder()
    _ = decoder.append([0xB2, 5, 64])
    let events = decoder.append([0xB0, 35, 65, 0x90, 9, 127, 25, 127, 34, 127, 0x80, 14, 127])
    #expect(events.count == 5 && !events.contains(.controlsChanged(true)))
    #expect(decoder.append([0xB2, 5, 65]).count == 1)
    #expect(decoder.append([0x92, 77, 0]).first == .controlsChanged(true))
    #expect(decoder.append([0xB2, 5, 65]).first == .controlsChanged(true))
}

@Test func controllerMC1000RecognisesOnlyQualifiedContextFamiliesAndFramesRunningStatus() {
    var decoder = ControllerMC1000Decoder(); var events: [ControllerMC1000Event] = []
    for byte: UInt8 in [0xB0, 5, 64, 0xF8, 0xB2, 33, 65, 33, 63, 0x92, 64, 127, 64, 0] {
        events += decoder.append([byte])
    }
    #expect(
        events.filter {
            if case .controlsChanged(true) = $0 { return true }; return false
        }.count == 2)
    #expect(events.count == 7)
    #expect(decoder.append([0xB4, 5, 64, 0xB2, 1, 64, 35, 65, 0x92, 9, 127]).count == 4)
    #expect(decoder.append([0xB2, 96, 65]).count == 1)
    #expect(decoder.append([0xB2, 33, 65]).first == .controlsChanged(true))
}
