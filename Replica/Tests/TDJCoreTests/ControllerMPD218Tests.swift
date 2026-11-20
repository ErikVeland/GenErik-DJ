import TDJCore
import Testing

@Test func controllerMPD218PadBanksKeepKnobBanksAndLateReleasesIndependent() {
    var decoder = ControllerMPD218Decoder()
    #expect(decoder.append([0x99, 45, 127]).count == 1)
    #expect(decoder.append([0xB0, 16, 64]).count == 1)
    #expect(decoder.append([0x99, 61, 1]).first == .bankChanged)
    #expect(decoder.append([0x89, 45, 127, 0x99, 45, 0]).count == 2)
    #expect(decoder.append([0x99, 61, 127]).count == 1)
    #expect(decoder.append([0x99, 68, 127]).first == .bankChanged)
}

@Test func controllerMPD218OnlyPreset1PadFootprintsSelectBankContext() {
    var decoder = ControllerMPD218Decoder(); var events: [ControllerMPD218Event] = []
    for byte: UInt8 in [0x99, 36, 127, 0xF8, 36, 0, 0x98, 68, 127, 0x99, 35, 127, 84, 127, 36, 127] {
        events += decoder.append([byte])
    }
    #expect(events.count == 6)
    #expect(
        events.allSatisfy {
            if case .message = $0 { return true }; return false
        })
}
