import Testing

@testable import TDJCore

private func sceneSearch(_ channel: UInt8 = 0, model: UInt8 = 4) -> [UInt8] {
    [0xF0, 0x42, 0x50, 1, channel, 0x2D, model, 1, 0, 0, 0, 0, 1, 0, 0xF7]
}
private func emptyScene(_ channel: UInt8 = 0) -> [UInt8] {
    var data = [UInt8](repeating: 0, count: 256)
    data[12] = channel
    for block in 0..<9 { data[16 + block * 23] = 255 }
    data[224] = 255
    return data
}

/**
 * Builds a synthetic manufacturer-format reply, separate from physical hardware evidence.
 */
private func sceneDump(_ data: [UInt8], channel: UInt8 = 0) -> [UInt8] {
    var packed: [UInt8] = []
    for start in stride(from: 0, to: data.count, by: 7) {
        let block = Array(data[start..<min(start + 7, data.count)])
        var mask: UInt8 = 0
        for (bit, byte) in block.enumerated() { mask |= ((byte >> 7) & 1) << bit }
        packed.append(mask)
        packed += block.map { $0 & 127 }
    }
    return [0xF0, 0x42, 0x40 + channel, 0, 1, 4, 0, 0x7F, 0x7F, 2, 2, 0x26, 0x40] + packed + [0xF7]
}
private func sceneChange(_ scene: UInt8, channel: UInt8 = 0) -> [UInt8] {
    [0xF0, 0x42, 0x40 + channel, 0, 1, 4, 0, 0x5F, 0x4F, scene, 0xF7]
}
private func setSceneFader(_ data: inout [UInt8], block: Int = 0, number: UInt8 = 1, low: UInt8 = 0, high: UInt8 = 127)
{
    let base = 16 + block * 23
    data.replaceSubrange((base + 1)...(base + 4), with: [1, number, low, high])
}

@Test func controllerNanoKontrolSceneRequiresOriginalModelAndReadReplyOnEveryGlobalChannel() {
    for channel: UInt8 in 0..<16 {
        var decoder = ControllerNanoKontrolSceneDecoder()
        var data = emptyScene(5)
        setSceneFader(&data)
        #expect(decoder.append([0xB5, 1, 127]).isEmpty)
        #expect(decoder.append(sceneSearch(channel, model: 0x13)).isEmpty)
        #expect(decoder.append(sceneSearch(channel, model: 0x12)).isEmpty)
        let request: [UInt8] = [0xF0, 0x42, 0x40 + channel, 0, 1, 4, 0, 0x1F, 0x10, 0, 0xF7]
        #expect(decoder.append(sceneSearch(channel)) == [.request(request)])
        #expect(!decoder.isReady)
        #expect(decoder.append(sceneDump(data, channel: (channel + 1) % 16)).isEmpty)
        #expect(!decoder.isReady)
        #expect(decoder.append(sceneDump(data, channel: channel)) == [.modeChanged(true)])
        #expect(decoder.isReady && decoder.mappedControlCount == 1)
        #expect(decoder.append([0xB5, 1, 127]) == [.message(.init(kind: .control, channel: 0, number: 0, value: 127))])
    }
    var wrapper = ControllerKorgInputDecoder(mode: .originalNanoKontrol)
    _ = wrapper.append(sceneSearch() + sceneDump(emptyScene()))
    #expect(wrapper.isReady && wrapper.exitRequest == nil)
}

@Test func controllerNanoKontrolSceneUnpacksEveryFragmentBoundaryAndCustomReversedRangeWithoutQuantisation() {
    var data = emptyScene(3)
    setSceneFader(&data, number: 17, low: 100, high: 20)
    let dump = sceneDump(data, channel: 7)
    #expect(dump.count == 307)
    for split in 0...dump.count {
        var decoder = ControllerNanoKontrolSceneDecoder()
        _ = decoder.append(sceneSearch(7))
        let first = decoder.append(Array(dump.prefix(split)))
        let second = decoder.append(Array(dump.dropFirst(split)))
        #expect(first + second == [.modeChanged(true)])
        #expect(
            decoder.append([0xB3, 17, 60]) == [
                .message(.init(kind: .control, channel: 0, number: 0, value: 40, maximum: 80))
            ])
        #expect(
            decoder.append([17, 100]) == [.message(.init(kind: .control, channel: 0, number: 0, value: 0, maximum: 80))]
        )
        #expect(
            decoder.append([17, 20]) == [.message(.init(kind: .control, channel: 0, number: 0, value: 80, maximum: 80))]
        )
        #expect(decoder.append([17, 0]).isEmpty)
        #expect(decoder.append([0xB0, 17, 60]).isEmpty)
    }
    var decoder = ControllerNanoKontrolSceneDecoder()
    _ = decoder.append(sceneSearch(7))
    #expect(decoder.append(dump.flatMap { [$0, 0xF8] }) == [.modeChanged(true)])
}

@Test func controllerNanoKontrolScenePreservesMomentaryAndLatchedSwitchesWithoutRampedButtonInference() {
    var data = emptyScene()
    data.replaceSubrange(25...31, with: [2, 10, 64, 127, 0, 0, 1])
    data.replaceSubrange(32...38, with: [1, 11, 20, 100, 0, 0, 0])
    var decoder = ControllerNanoKontrolSceneDecoder()
    _ = decoder.append(sceneSearch() + sceneDump(data))
    #expect(decoder.append([0x90, 10, 127]) == [.message(.init(kind: .control, channel: 0, number: 64, value: 127))])
    #expect(decoder.append([0x80, 10, 127]) == [.message(.init(kind: .control, channel: 0, number: 64, value: 0))])
    #expect(decoder.append([0xB0, 11, 60]).isEmpty)
    #expect(decoder.append([11, 100]) == [.message(.init(kind: .note, channel: 0, number: 36, value: 127))])
    #expect(
        decoder.append([11, 20]) == [.message(.init(kind: .note, channel: 0, number: 36, value: 0, isNoteOff: true))])
    data[29] = 1
    data[37] = 1
    var ramped = ControllerNanoKontrolSceneDecoder()
    _ = ramped.append(sceneSearch() + sceneDump(data))
    #expect(ramped.mappedControlCount == 0)
    #expect(ramped.append([0x90, 10, 127, 0xB0, 11, 100]).isEmpty)
}

@Test func controllerNanoKontrolSceneRejectsCollisionsWithUnusedStripsAndTransportButSeparatesNoteAndCC() {
    for unusedStrip in [true, false] {
        var data = emptyScene()
        setSceneFader(&data)
        if unusedStrip { setSceneFader(&data, block: 8) } else { data[225] = 1; data[226] = 1 }
        var decoder = ControllerNanoKontrolSceneDecoder()
        _ = decoder.append(sceneSearch() + sceneDump(data))
        #expect(decoder.isReady && decoder.mappedControlCount == 0)
        #expect(decoder.append([0xB0, 1, 127]).isEmpty)
    }
    var data = emptyScene()
    setSceneFader(&data, number: 10)
    data.replaceSubrange(25...31, with: [2, 10, 0, 127, 0, 0, 0])
    var decoder = ControllerNanoKontrolSceneDecoder()
    _ = decoder.append(sceneSearch() + sceneDump(data))
    #expect(decoder.mappedControlCount == 2)
    #expect(decoder.append([0xB0, 10, 127]) == [.message(.init(kind: .control, channel: 0, number: 0, value: 127))])
    #expect(decoder.append([0x90, 10, 127]) == [.message(.init(kind: .note, channel: 0, number: 32, value: 127))])
}

@Test func controllerNanoKontrolSceneSerialisesChangesAndDiscardsStaleDumpBeforeReopeningInputs() {
    var old = emptyScene(), new = emptyScene()
    setSceneFader(&old, number: 1)
    setSceneFader(&new, number: 2)
    var decoder = ControllerNanoKontrolSceneDecoder()
    _ = decoder.append(sceneSearch() + sceneDump(old))
    let invalidation = decoder.append(sceneChange(1))
    #expect(invalidation.count == 2 && invalidation.first == .modeChanged(false))
    #expect(!decoder.isReady && decoder.mappedControlCount == 0)
    #expect(decoder.append([0xB0, 1, 127, 2, 127]).isEmpty)
    #expect(decoder.append(sceneChange(2)).isEmpty)
    #expect(decoder.append(sceneChange(3)).isEmpty)
    let stale = decoder.append(sceneDump(old))
    #expect(stale == Array(invalidation.dropFirst()))
    #expect(!decoder.isReady)
    #expect(decoder.append(sceneDump(new)) == [.modeChanged(true)])
    #expect(decoder.append(sceneDump(old)).isEmpty)
    #expect(decoder.append([0xB0, 1, 127]).isEmpty)
    #expect(decoder.append([0xB0, 2, 127]).count == 1)
}

@Test func controllerNanoKontrolSceneMalformedForeignOversizedAndNAKRepliesNeverEnableRawInputs() {
    let valid = sceneDump(emptyScene())
    var badPacking = valid
    badPacking[301] = 127
    var invalidScene = emptyScene()
    invalidScene[12] = 16
    for bytes in [
        Array(valid.dropLast()), Array(valid.dropLast()) + [0, 0xF7],
        [0xF0] + Array(repeating: 0, count: 4096) + [0xF7],
        badPacking, sceneDump(invalidScene), [0xF0, 0x42, 0, 0xF7],
    ] {
        var decoder = ControllerNanoKontrolSceneDecoder()
        _ = decoder.append(sceneSearch())
        _ = decoder.append(bytes)
        #expect(!decoder.isReady)
        #expect(decoder.append([0xB0, 0, 127, 1, 127]).isEmpty)
    }
    var decoder = ControllerNanoKontrolSceneDecoder()
    _ = decoder.append(sceneSearch())
    #expect(decoder.append([0xF0, 0x42, 0x40, 0, 1, 4, 0, 0x5F, 0x24, 0, 0xF7]) == [.modeChanged(false)])
    #expect(decoder.append(valid).isEmpty && !decoder.isReady)
    decoder = .init()
    #expect(decoder.append(sceneSearch() + valid).last == .modeChanged(true))
}
