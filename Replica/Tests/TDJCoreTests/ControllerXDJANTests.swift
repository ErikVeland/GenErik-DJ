import TDJCore
import Testing

@Test func controllerXDJANWaitsForBothDecksAndActualSend() {
    var decoder = ControllerXDJANDecoder()
    #expect(decoder.append([0x90, 0, 127, 0xB4, 101, 0]).isEmpty)
    #expect(!decoder.isReady && decoder.pendingRequest == nil)
    #expect(decoder.append([0xB0, 100, 127]).isEmpty)
    #expect(decoder.pendingRequest == nil)
    #expect(decoder.append([0xB1, 100, 127, 0x91, 0, 127]).isEmpty)
    #expect(!decoder.isReady && decoder.pendingRequest == [0xB4, 101, 0])
    #expect(decoder.didSendPendingRequest([0xB4, 101, 127]) == false)
    #expect(decoder.didSendPendingRequest([0xB4, 101, 0]) == true)
    #expect(decoder.isReady && decoder.pendingRequest == nil)
    #expect(decoder.append([0x91, 0, 127]).count == 1)
    #expect(decoder.didSendPendingRequest([0xB4, 101, 0]) == false)
}

@Test func controllerXDJANRejectsStaleRequestsAndRespectsHardwareMode() {
    var decoder = ControllerXDJANDecoder()
    _ = decoder.append([0xB0, 100, 127, 0xB1, 100, 127, 0xB0, 100, 0])
    #expect(decoder.pendingRequest == nil)
    #expect(decoder.didSendPendingRequest([0xB4, 101, 0]) == false)
    _ = decoder.append([0xB0, 100, 127])
    #expect(decoder.didSendPendingRequest([0xB4, 101, 0]) == true)
    #expect(decoder.append([0xB4, 101, 1]) == [.modeChanged(false)])
    #expect(!decoder.isReady && decoder.pendingRequest == nil)
    #expect(decoder.append([0x90, 1, 127]).isEmpty)
    #expect(decoder.append([0xB4, 101, 0]) == [.modeChanged(true)])
    #expect(decoder.append([0xB1, 100, 0]) == [.modeChanged(false)])
    #expect(decoder.append([0xB4, 101, 0]).isEmpty)
    #expect(decoder.pendingRequest == nil)
}

@Test func controllerXDJANFramesSplitRunningStatusAndIgnoresForeignOwnership() {
    var decoder = ControllerXDJANDecoder()
    for byte: UInt8 in [0xB0, 100, 127, 0xB1, 100, 127] { _ = decoder.append([byte]) }
    #expect(decoder.didSendPendingRequest([0xB4, 101, 0]) == true)
    #expect(decoder.append([0xB2, 100, 0]).count == 1)
    #expect(decoder.isReady)
    #expect(decoder.append([0xB4, 101, 0]).isEmpty)
    #expect(decoder.append([0x90, 1, 127, 0xF8, 1, 0]).count == 2)
    #expect(decoder.append([0xB0, 100, 64]) == [.modeChanged(false)])
    #expect(!decoder.isReady && decoder.pendingRequest == nil)
}

@Test func controllerXDJANDoesNotOverwriteHardwareChoiceInThePendingBatch() {
    var decoder = ControllerXDJANDecoder()
    _ = decoder.append([0xB0, 100, 127, 0xB1, 100, 127, 0xB4, 101, 127])
    #expect(!decoder.isReady && decoder.pendingRequest == nil)
    #expect(decoder.didSendPendingRequest([0xB4, 101, 0]) == false)
    #expect(decoder.append([0xB4, 101, 0]) == [.modeChanged(true)])
}
