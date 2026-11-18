import Testing

@testable import TDJCore

private func padSearch(_ channel: UInt8, family: UInt8 = 0x12) -> [UInt8] {
    [0xF0, 0x42, 0x50, 1, channel, 0x2D, family, 1, 0, 0, 0, 0, 1, 0, 0xF7]
}
private func padAck(_ channel: UInt8, family: UInt8 = 0x12, state: UInt8 = 3) -> [UInt8] {
    [0xF0, 0x42, 0x40 + channel, 0, 1, family, 0, 0x40, 0, state, 0xF7]
}
private func readyPad() -> ControllerKorgNativeDecoder {
    var decoder = ControllerKorgNativeDecoder(model: .nanoPad2)
    _ = decoder.append(padSearch(7) + padAck(7))
    return decoder
}
private func stepPadScene(_ decoder: inout ControllerKorgNativeDecoder) {
    _ = decoder.append([0xBF, 57, 127, 57, 0])
}

@Test func controllerNanoPad2EveryGlobalChannelUsesItsOwnProjectAndInitialSceneLights() {
    for channel: UInt8 in 0..<16 {
        var decoder = ControllerKorgNativeDecoder(model: .nanoPad2)
        #expect(decoder.append(padSearch(channel, family: 0x13)).isEmpty)
        #expect(decoder.append([0x91, 64, 127]).isEmpty)
        #expect(
            decoder.append(padSearch(channel)) == [
                .request([0xF0, 0x42, 0x40 + channel, 0, 1, 0x12, 0, 0, 0, 1, 0xF7])
            ])
        #expect(decoder.append(padAck(channel, family: 0x13)).isEmpty)
        #expect(
            decoder.append(padAck(channel)) == [
                .modeChanged(true), .request([0xBF, 121, 127]), .request([0xBF, 122, 0]), .request([0xBF, 123, 0]),
                .request([0xBF, 124, 0]),
            ])
        #expect(decoder.isReady)
        #expect(decoder.exitRequest == [0xF0, 0x42, 0x40 + channel, 0, 1, 0x12, 0, 0, 0, 0, 0xF7])
        var mixer = ControllerKorgNativeDecoder(model: .nanoKontrol2)
        #expect(mixer.append(padSearch(channel)).isEmpty)
    }
}

@Test func controllerNanoPad2FirstSceneRetainsEverySourcePadAndOriginalReleaseAcrossSceneChanges() {
    for pad: UInt8 in 0..<16 {
        for velocity: UInt8 in [0, 1, 64, 127] {
            var decoder = readyPad()
            #expect(
                decoder.append([0x91, 64 + pad, 127]) == [
                    .message(.init(kind: .note, channel: 0, number: 36 + pad, value: 127))
                ])
            #expect(decoder.append([0x91, 64 + pad, 127]).isEmpty)
            stepPadScene(&decoder)
            #expect(
                decoder.append([0x81, 64 + pad, velocity]) == [
                    .message(.init(kind: .note, channel: 0, number: 36 + pad, value: 0, isNoteOff: true))
                ])
        }
    }
}

@Test func controllerNanoPad2SceneSelectionUsesFreshPressesAndBlocksUnsupportedBanksAndTouch() {
    var decoder = readyPad()
    let change = decoder.append([0xBF, 57, 127, 57, 127])
    #expect(
        change == [
            .sceneChanged, .request([0xBF, 121, 0]), .request([0xBF, 122, 127]), .request([0xBF, 123, 0]),
            .request([0xBF, 124, 0]),
        ])
    for pad: UInt8 in 0..<16 where pad != 14 {
        #expect(decoder.append([0x91, 64 + pad, 127, 0x81, 64 + pad, 64]).isEmpty)
    }
    #expect(decoder.append([0x91, 78, 127, 0x81, 78, 64]).count == 2)
    _ = decoder.append([0xBF, 57, 0])
    stepPadScene(&decoder)
    stepPadScene(&decoder)
    for pad: UInt8 in 0..<16 { #expect(decoder.append([0x91, 64 + pad, 127, 0x81, 64 + pad, 64]).isEmpty) }
    #expect(decoder.append([0xBF, 9, 127, 10, 127, 11, 127, 0x92, 60, 127, 0xB2, 2, 127, 0x90, 64, 127]).isEmpty)
    stepPadScene(&decoder)
    #expect(decoder.append([0x91, 64, 127]).last == .message(.init(kind: .note, channel: 0, number: 36, value: 127)))
}

@Test func controllerNanoPad2LoopResizeIsBlockedDuringLoopOrUnqualifiedReloopHolds() {
    for heldPad: UInt8 in [66, 67, 68, 69, 70, 71, 78, 79] {
        var decoder = readyPad()
        stepPadScene(&decoder); stepPadScene(&decoder)
        _ = decoder.append([0x91, heldPad, 127])
        for resize: UInt8 in [64, 65, 72, 73] {
            #expect(decoder.append([0x91, resize, 127, 0x81, resize, 64]).isEmpty)
        }
        _ = decoder.append([0x81, heldPad, 64])
        #expect(
            decoder.append([0x91, 64, 127]).last == .message(.init(kind: .note, channel: 0, number: 68, value: 127)))
    }
}

@Test func controllerNanoPad2SourcesFragmentsAndNativeExitRemainIndependent() {
    var first = ControllerKorgNativeDecoder(model: .nanoPad2)
    var second = readyPad()
    let bytes = padSearch(3) + padAck(3)
    var events: [ControllerKorgNativeEvent] = []
    for byte in bytes { events.append(contentsOf: first.append([0xF8, byte])) }
    #expect(events.count == 6 && first.isReady)
    #expect(first.append(padAck(3, state: 2)) == [.modeChanged(false)])
    #expect(first.append([0x91, 64, 127, 0xBF, 57, 127]).isEmpty)
    #expect(second.append([0x91, 64, 127]).count == 1)
    second = .init(model: .nanoPad2)
    #expect(second.append([0x91, 64, 127]).isEmpty)
}
