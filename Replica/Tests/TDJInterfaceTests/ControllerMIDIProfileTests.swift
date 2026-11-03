import Testing
@testable import TDJInterface

@Test @MainActor func ddjREV1InputProfileUsesPublishedDeckChannelsAndControlEncodings() throws {
    let bindings = ControllerMIDIConnection.ddjREV1Bindings(source: 42)
    #expect(bindings.count == 57)
    #expect(bindings.allSatisfy { $0.source == 42 && $0.group == 0 && $0.shifted == false })

    func first(_ action: ControllerAction) throws -> ControllerBinding {
        try #require(bindings.first { $0.action == action })
    }
    let playA = try first(.playA)
    let playB = try first(.playB)
    let syncA = try first(.syncA)
    let cueA = try first(.cueA)
    let loopA = try first(.loopA)
    let loopDownA = try first(.loopDownA)
    let loopUpA = try first(.loopUpA)
    let tempoA = try first(.tempoA)
    let crossfader = try first(.crossfader)
    let shift = try first(.shift)
    #expect(playA.channel == 0 && playA.number == 11)
    #expect(playB.channel == 1 && playB.number == 11)
    #expect(syncA.number == 88 && cueA.number == 84)
    #expect(loopA.number == 20)
    #expect(loopDownA.number == 18)
    #expect(loopUpA.number == 19)
    #expect(tempoA.encoding == .paired14Bit && tempoA.number == 0)
    #expect(crossfader.channel == 6 && crossfader.number == 31)
    #expect(shift.kind == .note && shift.channel == 6 && shift.number == 63)

    let jog = bindings.filter { $0.action == .jogA }
    #expect(jog.map(\.number) == [34, 35])
    #expect(jog.allSatisfy { $0.encoding == .binaryOffset })
    let wheelJog = bindings.filter { $0.action == .wheelJogA }
    #expect(wheelJog.map(\.number) == [33, 38])
    #expect(bindings.filter { $0.action.hotcueSlot != nil && $0.action.deck == .a }
        .map { ($0.channel, $0.number) }.map { "\($0.0):\($0.1)" } == (0..<8).map { "7:\($0)" })
    #expect(bindings.filter { $0.action.hotcueSlot != nil && $0.action.deck == .b }
        .map { ($0.channel, $0.number) }.map { "\($0.0):\($0.1)" } == (0..<8).map { "9:\($0)" })
}

@Test @MainActor func ddjREV1FeedbackProfileUsesPublishedStatusAndPadMessages() {
    let bindings = ControllerMIDIConnection.ddjREV1FeedbackBindings(destination: 51)
    #expect(bindings.count == 22)
    #expect(bindings.allSatisfy {
        $0.destination == 51 && $0.kind == .note && $0.offValue == 0 && $0.onValue == 127
            && $0.offUsesNoteOn == true
    })
    #expect(bindings.first { $0.action == .playA }?.channel == 0)
    #expect(bindings.first { $0.action == .playA }?.number == 11)
    #expect(bindings.first { $0.action == .syncB }?.channel == 1)
    #expect(bindings.first { $0.action == .syncB }?.number == 88)
    let hotcueB = bindings.filter { $0.action.hotcueSlot != nil && $0.action.deck == .b }
    #expect(hotcueB.map(\.channel) == Array(repeating: 9, count: 8))
    #expect(hotcueB.map(\.number) == (0..<8).map { UInt8($0) })
}

@Test @MainActor func ddjREV5InputProfileUsesPublishedTwoDeckChannelsAndEncodings() throws {
    let bindings = ControllerMIDIConnection.ddjREV5Bindings(source: 43)
    #expect(bindings.count == 63)
    #expect(bindings.allSatisfy { $0.source == 43 && $0.group == 0 })

    func first(_ action: ControllerAction) throws -> ControllerBinding {
        try #require(bindings.first { $0.action == action })
    }
    let playA = try first(.playA), playB = try first(.playB)
    let cueReturnA = try first(.cueReturnA), cueA = try first(.cueA)
    let syncA = try first(.syncA), loopA = try first(.loopA)
    let tempoA = try first(.tempoA), crossfader = try first(.crossfader), shift = try first(.shift)
    #expect(playA.channel == 0 && playA.number == 11)
    #expect(playB.channel == 1 && playB.number == 11)
    #expect(cueReturnA.number == 27)
    #expect(cueA.number == 7)
    #expect(syncA.number == 9)
    #expect(loopA.number == 4)
    #expect(bindings.filter { $0.action == .loopDownA }.map(\.number) == [1, 16])
    #expect(bindings.filter { $0.action == .loopUpA }.map(\.number) == [3, 18])
    #expect(bindings.filter { $0.action == .keylockA }.allSatisfy { $0.number == 24 && $0.isShifted })
    #expect(bindings.filter { $0.action == .loopDownA && $0.isShifted }.map(\.number) == [16])
    #expect(bindings.filter { $0.action == .loopUpA && $0.isShifted }.map(\.number) == [18])
    #expect(tempoA.encoding == .paired14Bit && tempoA.number == 5)
    #expect(crossfader.channel == 6 && crossfader.number == 31)
    #expect(shift.kind == .note && shift.channel == 6 && shift.number == 63)

    #expect(bindings.filter { $0.action == .jogA }.map(\.number) == [34, 35])
    #expect(bindings.filter { $0.action == .jogA }.allSatisfy { $0.encoding == .binaryOffset })
    #expect(bindings.filter { $0.action == .wheelJogB }.map(\.number) == [33, 38])
    #expect(bindings.filter { $0.action == .wheelJogB && $0.isShifted }.map(\.number) == [38])
    #expect(bindings.filter { $0.action.hotcueSlot != nil && $0.action.deck == .a }
        .map { "\($0.channel):\($0.number)" } == (0..<8).map { "7:\($0)" })
    #expect(bindings.filter { $0.action.hotcueSlot != nil && $0.action.deck == .b }
        .map { "\($0.channel):\($0.number)" } == (0..<8).map { "8:\($0)" })
}

@Test @MainActor func ddjREV5FeedbackProfileUsesPublishedStatusAndPadMessages() {
    let bindings = ControllerMIDIConnection.ddjREV5FeedbackBindings(destination: 52)
    #expect(bindings.count == 22)
    #expect(bindings.allSatisfy {
        $0.destination == 52 && $0.kind == .note && $0.offValue == 0 && $0.onValue == 127
            && $0.offUsesNoteOn == true
    })
    #expect(bindings.first { $0.action == .playA }?.channel == 0)
    #expect(bindings.first { $0.action == .playA }?.number == 11)
    #expect(bindings.first { $0.action == .syncB }?.channel == 1)
    #expect(bindings.first { $0.action == .syncB }?.number == 9)
    let hotcueB = bindings.filter { $0.action.hotcueSlot != nil && $0.action.deck == .b }
    #expect(hotcueB.map(\.channel) == Array(repeating: 8, count: 8))
    #expect(hotcueB.map(\.number) == (0..<8).map { UInt8($0) })
}
