import Testing

@testable import TDJCore

private let apc64Identity: [UInt8] = [0xF0, 0x7E, 0, 6, 2, 0x47, 0x53, 0, 0x19, 1, 1, 0, 14, 0, 0xF7]
private func apc64Mode(_ mode: UInt8) -> [UInt8] { [0xF0, 0x47, 0, 0x53, 0x19, 0, 1, mode, 0xF7] }

@Test func controllerAPC64RequiresOwnIdentityAndSuccessfulDAWRequestThenGatesModes() {
    var decoder = ControllerAPC64Decoder()
    #expect(!decoder.isReady && decoder.pendingRequest == nil)
    #expect(decoder.append([0x96, 1, 127]).isEmpty)
    var other = apc64Identity; other[6] = 0x4F
    #expect(decoder.append(other).isEmpty && decoder.pendingRequest == nil)
    #expect(decoder.append(apc64Identity).isEmpty && !decoder.isReady)
    #expect(decoder.pendingRequest == ControllerAPC64Decoder.dawRequest(active: true))
    let acceptedWrongRequest = decoder.didSendPendingRequest(ControllerAPC64Decoder.dawRequest(active: false))
    #expect(!acceptedWrongRequest)
    #expect(decoder.didSendPendingRequest(ControllerAPC64Decoder.dawRequest(active: true)) && decoder.isReady)
    #expect(decoder.append([0x96, 1, 1, 0x86, 1, 127]).count == 2)
    #expect(decoder.append(apc64Mode(0)).isEmpty && decoder.isReady)
    #expect(
        decoder.append(apc64Mode(2)) == [
            .modeChanged(false), .request(ControllerAPC64Decoder.dawRequest(active: false)),
        ])
    #expect(!decoder.isReady && decoder.append([0x96, 1, 127, 0xE0, 0, 127]).isEmpty)
    #expect(decoder.append(apc64Mode(0)).isEmpty && decoder.pendingRequest != nil)
    #expect(decoder.didSendPendingRequest(ControllerAPC64Decoder.dawRequest(active: true)) && decoder.isReady)
    #expect(decoder.append(apc64Mode(127)).first == .modeChanged(false) && !decoder.isReady)
}

@Test func controllerAPC64BoundsSplitSysexRealtimeAndIndependentInputChannels() {
    var decoder = ControllerAPC64Decoder()
    #expect(decoder.append(Array(apc64Identity.prefix(7))).isEmpty)
    #expect(decoder.append([0xF8] + Array(apc64Identity.dropFirst(7))).isEmpty)
    let activated = decoder.didSendPendingRequest(ControllerAPC64Decoder.dawRequest(active: true))
    #expect(activated)
    let events = decoder.append([
        0x96, 0, 127, 1, 127, 0xF8, 1, 0, 0x86, 0, 127, 0xE0, 0, 64, 0xE7, 127, 127, 0x90, 120, 127, 120, 0,
    ])
    #expect(events.count == 8)
    #expect(decoder.append([0x90, 0, 127, 0x99, 36, 127, 0xB0, 48, 127, 0xE8, 0, 64, 0xA6, 0, 127]).isEmpty)
    #expect(decoder.append([0xF0] + Array(repeating: 0, count: 120) + [0xF7]).isEmpty && decoder.isReady)
    #expect(decoder.append([0xF0, 0x47, 0, 0x53, 0x19, 0, 1, 0x90, 120, 127]).count == 1)
    var setup = ControllerSetupInputDecoder(mode: .apc64)
    #expect(setup.append(apc64Identity).isEmpty && setup.pendingRequest != nil && !setup.isReady)
    #expect(setup.didSendPendingRequest(ControllerAPC64Decoder.dawRequest(active: true)) && setup.isReady)
}
