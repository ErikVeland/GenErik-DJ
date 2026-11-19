import TDJCore
import Testing

private func xlTemplateDump(_ template: UInt8 = 0) -> [UInt8] {
    var data: [UInt8] = []
    for index: UInt8 in 0..<24 { data += [index, 0, 0, 127, 2, 0] }
    for index: UInt8 in 0..<8 { data += [40 + index, 0, 0, 127, 3, 0] }
    for index: UInt8 in 0..<16 { data += [0, 60 + index, 0, 127, 0, 4] }
    for index: UInt8 in 0..<4 { data += [0, 80 + index, 0, 127, 0, 5] }
    for index: UInt8 in 0..<4 { data += [1, 100 + index, 0, 127, 0, 6] }
    data += [UInt8](repeating: 0, count: 72)
    return [240, 0, 32, 41, 2, 17, 119, template] + data + [247]
}

@Test func controllerLaunchControlXLTemplateRequiresIndependentProductSizeAndAllRecordGroups() {
    var decoder = ControllerLaunchControlTemplateDecoder(model: .xl)
    var wrong = xlTemplateDump(); wrong[5] = 10
    #expect(decoder.append(wrong).isEmpty && !decoder.isReady)
    var short = Array(xlTemplateDump().prefix(176)); short += [247]
    #expect(decoder.append(short).isEmpty && !decoder.isReady)
    #expect(decoder.append(xlTemplateDump()) == [.modeChanged(true)])
    #expect(decoder.isReady && decoder.mappedControlCount == 56)
    for (status, number, logical): (UInt8, UInt8, UInt8) in [
        (0xB2, 23, 23), (0xB3, 47, 31), (0x94, 75, 63), (0x95, 83, 67), (0xB6, 103, 71),
    ] {
        let events = decoder.append([status, number, 127, number, 0])
        let button = logical >= 32
        #expect(
            events == [
                .message(.init(kind: button ? .note : .control, channel: 0, number: logical, value: 127)),
                .message(
                    .init(kind: button ? .note : .control, channel: 0, number: logical, value: 0, isNoteOff: button)),
            ])
    }
}

@Test func controllerLaunchControlXLTemplateFramesEveryBoundaryAndSuspendsFactoryPages() {
    let dump = xlTemplateDump()
    #expect(dump.count == 417)
    for split in 0...dump.count {
        var decoder = ControllerSetupInputDecoder(mode: .launchControlXLTemplate)
        #expect(
            decoder.append(Array(dump.prefix(split))) + decoder.append(Array(dump.dropFirst(split))) == [
                .modeChanged(true)
            ])
        #expect(decoder.isReady)
    }
    var decoder = ControllerLaunchControlTemplateDecoder(model: .xl)
    _ = decoder.append(dump)
    for template: UInt8 in 1..<8 {
        #expect(
            decoder.append([240, 0, 32, 41, 2, 17, 119, template, 247]) == [
                .modeChanged(false), .request([240, 0, 32, 41, 2, 17, 121, template, 247]),
            ])
        #expect(decoder.append(xlTemplateDump(template - 1)).isEmpty && !decoder.isReady)
        #expect(decoder.append(xlTemplateDump(template)) == [.modeChanged(true)])
    }
    #expect(decoder.append([240, 0, 32, 41, 2, 17, 119, 8, 247]) == [.modeChanged(false)])
    #expect(decoder.append([0x94, 61, 127]).isEmpty && !decoder.isReady)
}

@Test func controllerLaunchControlXLTemplateValidatesAllGroupChannelsAndDisablesCrossGroupCollisions() {
    for index in [8 + 4, 8 + 144 + 4, 8 + 192 + 5, 8 + 288 + 5, 8 + 312 + 5] {
        var decoder = ControllerLaunchControlTemplateDecoder(model: .xl); var bad = xlTemplateDump(); bad[index] = 16
        #expect(decoder.append(bad).isEmpty && !decoder.isReady)
    }
    var decoder = ControllerLaunchControlTemplateDecoder(model: .xl); var dump = xlTemplateDump()
    dump[8 + 144] = 0; dump[8 + 144 + 4] = 2
    dump[8 + 192 + 4] = 1
    dump.replaceSubrange((8 + 288)..<(8 + 294), with: [1, 1, 0, 127, 0, 2])
    dump[8 + 312 + 3] = 0
    _ = decoder.append(dump)
    #expect(decoder.isReady && decoder.mappedControlCount == 50)
    #expect(
        decoder.append([0xB2, 0, 127, 1, 127, 0xB3, 40, 127, 0x94, 60, 127, 0x95, 80, 127, 0xB6, 100, 127]).isEmpty)
    #expect(decoder.append([0x94, 61, 127]).count == 1)
}

@Test func controllerLaunchControlXLTemplateIgnoresLEDTailAndNormalisesFaderRange() {
    var decoder = ControllerLaunchControlTemplateDecoder(model: .xl); var dump = xlTemplateDump()
    dump[8 + 144 + 2] = 100; dump[8 + 144 + 3] = 20
    dump.replaceSubrange((8 + 336)..<(8 + 408), with: [UInt8](repeating: 127, count: 72))
    #expect(decoder.append(dump) == [.modeChanged(true)])
    #expect(
        decoder.append([0xB3, 40, 100, 40, 60, 40, 20])
            == [0, 40, 80].map { .message(.init(kind: .control, channel: 0, number: 24, value: $0, maximum: 80)) })
    var oversized = Array(xlTemplateDump().dropLast()); oversized += [0, 247]
    var closed = ControllerLaunchControlTemplateDecoder(model: .xl)
    #expect(closed.append(oversized).isEmpty && !closed.isReady)
    #expect(closed.append(xlTemplateDump()) == [.modeChanged(true)])
}
