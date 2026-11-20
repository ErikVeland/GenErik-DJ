import TDJCore
import Testing

@Test func controllerMPD2BitwigPadBanksKeepControlBanksAndLateReleasesIndependent() {
    var decoder = ControllerMPD2BitwigDecoder()
    #expect(decoder.append([0x99, 45, 127]).count == 1)
    #expect(decoder.append([0xB1, 30, 127]).count == 1)
    #expect(decoder.append([0xB2, 40, 0]).first == .controlBankChanged(2))
    #expect(decoder.append([0xB1, 30, 0]).count == 1)
    #expect(decoder.append([0x99, 61, 1]).first == .padBankChanged)
    #expect(decoder.append([0x89, 45, 127, 0x99, 45, 0]).count == 2)
    #expect(decoder.append([0xB2, 50, 1]).count == 1)
    #expect(decoder.append([0xB3, 53, 127]).first == .controlBankChanged(3))
    #expect(decoder.append([0x99, 99, 127]).first == .padBankChanged)
}

@Test func controllerMPD2BitwigOnlyQualifiedNormalInputsSelectEitherContext() {
    var decoder = ControllerMPD2BitwigDecoder(); var events: [ControllerMPD2BitwigEvent] = []
    for byte: UInt8 in [
        0x99, 36, 127, 0xF8, 36, 0, 0x98, 68, 127, 0x99, 35, 127, 100, 127, 0xB0, 118, 127, 0xB3, 44, 127, 50, 64, 0x99,
        36, 127,
    ] { events += decoder.append([byte]) }
    #expect(events.count == 9)
    #expect(
        events.allSatisfy {
            if case .message = $0 { return true }; return false
        })
}
