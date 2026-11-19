import TDJCore
import Testing

private func originalLaunchControlDump(_ template: UInt8 = 0) -> [UInt8] {
    var data: [UInt8] = []
    for index: UInt8 in 0..<16 { data += [16 + index, 0, 0, 127, 2, 0] }
    for index: UInt8 in 0..<8 { data += [0, 60 + index, 0, 127, 0, 3] }
    for index: UInt8 in 0..<4 { data += [1, 100 + index, 0, 127, 0, 4] }
    return [240, 0, 32, 41, 2, 10, 119, template] + data + [247]
}
private func originalLaunchControlChange(_ template: UInt8) -> [UInt8] { [240, 0, 32, 41, 2, 10, 119, template, 247] }

@Test func controllerLaunchControlTemplateWaitsForExactRequestedOriginalUserData() {
    var decoder = ControllerLaunchControlTemplateDecoder()
    #expect(!decoder.isReady && decoder.append([0x93, 61, 127]).isEmpty)
    #expect(decoder.append(originalLaunchControlDump(1)).isEmpty && !decoder.isReady)
    var other = originalLaunchControlDump(); other[5] = 17
    #expect(decoder.append(other).isEmpty && !decoder.isReady)
    #expect(decoder.append(originalLaunchControlDump()) == [.modeChanged(true)])
    #expect(decoder.isReady && decoder.mappedControlCount == 28)
    #expect(
        decoder.append([0x93, 61, 127, 0x83, 61, 100]) == [
            .message(.init(kind: .note, channel: 0, number: 33, value: 127)),
            .message(.init(kind: .note, channel: 0, number: 33, value: 0, isNoteOff: true)),
        ])
}

@Test func controllerLaunchControlTemplateHandlesEverySplitBoundaryAndRunningStatus() {
    let dump = originalLaunchControlDump()
    #expect(dump.count == 177)
    for split in 0...dump.count {
        var decoder = ControllerSetupInputDecoder(mode: .launchControlTemplate)
        let events = decoder.append(Array(dump.prefix(split))) + decoder.append(Array(dump.dropFirst(split)))
        #expect(events == [.modeChanged(true)] && decoder.isReady)
        #expect(decoder.append([0xB4, 103, 127, 0xF8, 103, 0]).count == 2)
    }
}

@Test func controllerLaunchControlTemplateQueriesOnlySelectedUserTemplatesAndDropsStaleReplies() {
    var decoder = ControllerLaunchControlTemplateDecoder()
    _ = decoder.append(originalLaunchControlDump())
    for template: UInt8 in 1..<8 {
        #expect(
            decoder.append(originalLaunchControlChange(template)) == [
                .modeChanged(false), .request([240, 0, 32, 41, 2, 10, 121, template, 247]),
            ])
        #expect(!decoder.isReady && decoder.append(originalLaunchControlDump(template - 1)).isEmpty)
        #expect(decoder.append([0x93, 61, 127]).isEmpty)
        #expect(decoder.append(originalLaunchControlDump(template)) == [.modeChanged(true)])
    }
    for template: UInt8 in 8..<16 {
        #expect(decoder.append(originalLaunchControlChange(template)) == [.modeChanged(false)])
        #expect(!decoder.isReady && decoder.append(originalLaunchControlDump(template)).isEmpty)
    }
    #expect(decoder.append(originalLaunchControlChange(0)).count == 2)
    #expect(decoder.append(originalLaunchControlDump()) == [.modeChanged(true)])
    #expect(decoder.append(originalLaunchControlChange(0)).isEmpty && decoder.isReady)
}

@Test func controllerLaunchControlTemplateRejectsMalformedOversizedReservedAndForeignData() {
    let dump = originalLaunchControlDump()
    for index in [8 + 4, 8 + 96, 8 + 96 + 4, 8 + 96 + 5, 8 + 1, 8 + 5] {
        var decoder = ControllerLaunchControlTemplateDecoder(); var bad = dump; bad[index] = 127
        #expect(decoder.append(bad).isEmpty && !decoder.isReady)
        #expect(decoder.append(dump) == [.modeChanged(true)])
    }
    for extra in [1, 200, 4096] {
        var decoder = ControllerLaunchControlTemplateDecoder(); var bad = Array(dump.dropLast());
        bad += [UInt8](repeating: 0, count: extra); bad += [247]
        #expect(decoder.append(bad).isEmpty && !decoder.isReady)
        #expect(decoder.append(dump) == [.modeChanged(true)])
    }
    var decoder = ControllerLaunchControlTemplateDecoder()
    #expect(decoder.append(Array(dump.dropLast(2)) + [247]).isEmpty && !decoder.isReady)
}

@Test func controllerLaunchControlTemplateNormalisesReversedLimitedRangesAndExactMomentaryValues() {
    var decoder = ControllerLaunchControlTemplateDecoder(); var dump = originalLaunchControlDump()
    dump[10] = 100; dump[11] = 20
    dump[8 + 96 + 6 + 2] = 110; dump[8 + 96 + 6 + 3] = 30
    _ = decoder.append(dump)
    #expect(decoder.append([0xB2, 16, 101, 16, 19]).isEmpty)
    #expect(
        decoder.append([0xB2, 16, 100, 16, 60, 16, 20])
            == [0, 40, 80].map { .message(.init(kind: .control, channel: 0, number: 0, value: $0, maximum: 80)) })
    #expect(decoder.append([0x93, 61, 64]).isEmpty)
    #expect(decoder.append([0x93, 61, 30, 61, 110, 61, 30, 0x83, 61, 100]).count == 4)
}

@Test func controllerLaunchControlTemplateDisablesDuplicateConstantToggleAndUnsafeZeroNoteAssignments() {
    var decoder = ControllerLaunchControlTemplateDecoder(); var dump = originalLaunchControlDump()
    dump[14] = 16
    dump[8 + 2 * 6 + 2] = 127
    dump[8 + 96 + 4] = 1
    dump[8 + 96 + 6 + 3] = 0
    dump.replaceSubrange((8 + 96 + 12)..<(8 + 96 + 18), with: [1, 18, 0, 127, 1, 2])
    _ = decoder.append(dump)
    #expect(decoder.isReady && decoder.mappedControlCount == 22)
    #expect(decoder.append([0xB2, 16, 127, 17, 127, 18, 127, 0x93, 60, 127, 61, 127, 62, 127]).isEmpty)
    #expect(decoder.append([0x93, 63, 127]).count == 1)
}
