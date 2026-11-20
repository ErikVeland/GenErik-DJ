import TDJCore
import Testing

@testable import TDJInterface

@Test func controllerShiftLayerStaysActiveUntilEveryShiftInputIsReleased() {
    var shift = ControllerShiftLayerState()
    shift.update(input: "deck-a", isPressed: true)
    shift.update(input: "deck-b", isPressed: true)
    #expect(shift.isActive)
    shift.update(input: "deck-a", isPressed: false)
    #expect(shift.isActive)
    shift.update(input: "deck-b", isPressed: false)
    #expect(!shift.isActive)
    shift.update(input: "deck-a", isPressed: true)
    shift.reset()
    #expect(!shift.isActive)
}

@Test func controllerSoftTakeoverWaitsForTheCurrentValueThenStaysAcquired() {
    var takeover = ControllerMIDITakeoverState()
    let initial = takeover.shouldApply(input: 0.1, target: 0.75)
    #expect(!initial)
    #expect(takeover.isPending)
    let below = takeover.shouldApply(input: 0.4, target: 0.75)
    #expect(!below)
    let close = takeover.shouldApply(input: 0.74, target: 0.75)
    #expect(close)
    #expect(!takeover.isPending)
    let acquired = takeover.shouldApply(input: 0.1, target: 0.75)
    #expect(acquired)
}

@Test func controllerSoftTakeoverAcquiresWhenAnInputCrossesTheCurrentValue() {
    var takeover = ControllerMIDITakeoverState()
    let above = takeover.shouldApply(input: 0.9, target: 0.5)
    #expect(!above)
    let crossed = takeover.shouldApply(input: 0.2, target: 0.5)
    #expect(crossed)
}

@Test func controllerSoftTakeoverDoesNotBlockWhenTheCurrentValueIsUnavailable() {
    var takeover = ControllerMIDITakeoverState()
    let unknown = takeover.shouldApply(input: 0.1, target: nil)
    #expect(unknown)
    let known = takeover.shouldApply(input: 0.1, target: 0.8)
    #expect(!known)
}

@Test @MainActor func ddjREV1InputProfileUsesPublishedDeckChannelsAndControlEncodings() throws {
    let bindings = ControllerMIDIConnection.ddjREV1Bindings(source: 42)
    #expect(bindings.count == 105)
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
    #expect(
        bindings.filter { $0.releaseOnly != true && $0.action.hotcueSlot != nil && $0.action.deck == .a }.map { ($0.channel, $0.number) }.map {
            "\($0.0):\($0.1)"
        } == (0..<8).map { "7:\($0)" })
    #expect(
        bindings.filter { $0.releaseOnly != true && $0.action.hotcueSlot != nil && $0.action.deck == .b }.map { ($0.channel, $0.number) }.map {
            "\($0.0):\($0.1)"
        } == (0..<8).map { "9:\($0)" })
}

@Test @MainActor func ddjREV1FeedbackProfileUsesPublishedStatusAndPadMessages() {
    let bindings = ControllerMIDIConnection.ddjREV1FeedbackBindings(destination: 51)
    #expect(bindings.count == 22)
    #expect(
        bindings.allSatisfy {
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

@Test @MainActor func ddjFLX10InputProfileUsesPublishedFourDeckChannelsAndEncodings() throws {
    let bindings = ControllerMIDIConnection.ddjFLX10Bindings(source: 44)
    #expect(bindings.count == 241)
    #expect(bindings.allSatisfy { $0.source == 44 && $0.group == 0 })
    for (channel, deck) in DeckID.allCases.enumerated() {
        let scoped = bindings.filter { $0.targetDeck == deck }
        let tempo = try #require(scoped.first { [.tempoA, .tempoB].contains($0.action) && !$0.isShifted })
        #expect(tempo.channel == channel && tempo.number == 0 && tempo.mode == .paired14Bit)
        #expect(scoped.contains { [.tempoA, .tempoB].contains($0.action) && $0.number == 5 && $0.isShifted })
        #expect(scoped.contains { [.loopInOrHalveA, .loopInOrHalveB].contains($0.action) && $0.number == 16 })
        #expect(scoped.contains { [.loopOutOrDoubleA, .loopOutOrDoubleB].contains($0.action) && $0.number == 17 })
        #expect(scoped.contains { [.toggleFixedLoopA, .toggleFixedLoopB].contains($0.action) && $0.argument == 4 })
        let pads = scoped.filter { $0.action.hotcueSlot != nil && $0.releaseOnly != true }
        #expect(pads.map(\.channel) == Array(repeating: UInt8(7 + channel * 2), count: 8))
        #expect(pads.map(\.number) == (0..<8).map { UInt8($0) })
        #expect(scoped.contains { [.jogA, .jogB].contains($0.action) && $0.number == 34 && $0.mode == .binaryOffset })
        #expect(!scoped.contains { $0.kind == .control && [31, 38, 41].contains($0.number) })
    }
    #expect(bindings.filter { $0.action == .shift }.map(\.channel) == [0, 1, 2, 3])
    #expect(bindings.filter { $0.action == .shift }.map(\.shiftInput) == [0, 1, 0, 1])
    #expect(bindings.contains { $0.action == .crossfader && $0.channel == 6 && $0.number == 31 })
}

@Test @MainActor func ddjREV5InputProfileUsesPublishedTwoDeckChannelsAndEncodings() throws {
    let bindings = ControllerMIDIConnection.ddjREV5Bindings(source: 43)
    #expect(bindings.count == 111)
    #expect(bindings.allSatisfy { $0.source == 43 && $0.group == 0 })

    func first(_ action: ControllerAction) throws -> ControllerBinding {
        try #require(bindings.first { $0.action == action })
    }
    let playA = try first(.playA)
    let playB = try first(.playB)
    let cuePreviewA = try first(.cuePreviewA)
    let cueA = try first(.cueA)
    let syncA = try first(.syncA)
    let loopA = try first(.loopA)
    let tempoA = try first(.tempoA)
    let crossfader = try first(.crossfader)
    let shift = try first(.shift)
    #expect(playA.channel == 0 && playA.number == 11)
    #expect(playB.channel == 1 && playB.number == 11)
    #expect(cuePreviewA.number == 27)
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
    #expect(
        bindings.filter { $0.releaseOnly != true && $0.action.hotcueSlot != nil && $0.action.deck == .a }.map { "\($0.channel):\($0.number)" }
            == (0..<8).map { "7:\($0)" })
    #expect(
        bindings.filter { $0.releaseOnly != true && $0.action.hotcueSlot != nil && $0.action.deck == .b }.map { "\($0.channel):\($0.number)" }
            == (0..<8).map { "9:\($0)" })
}

@Test @MainActor func ddjREV5FeedbackProfileUsesPublishedStatusAndPadMessages() {
    let bindings = ControllerMIDIConnection.ddjREV5FeedbackBindings(destination: 52)
    #expect(bindings.count == 22)
    #expect(
        bindings.allSatisfy {
            $0.destination == 52 && $0.kind == .note && $0.offValue == 0 && $0.onValue == 127
                && $0.offUsesNoteOn == true
        })
    #expect(bindings.first { $0.action == .playA }?.channel == 0)
    #expect(bindings.first { $0.action == .playA }?.number == 11)
    #expect(bindings.first { $0.action == .syncB }?.channel == 1)
    #expect(bindings.first { $0.action == .syncB }?.number == 9)
    let hotcueB = bindings.filter { $0.action.hotcueSlot != nil && $0.action.deck == .b }
    #expect(hotcueB.map(\.channel) == Array(repeating: 9, count: 8))
    #expect(hotcueB.map(\.number) == (0..<8).map { UInt8($0) })
}

@Test @MainActor func ddjFLX10FeedbackProfileUsesPublishedFourDeckStatusAndHotCueMessages() {
    let bindings = ControllerMIDIConnection.ddjFLX10FeedbackBindings(destination: 53)
    #expect(bindings.count == 44)
    #expect(
        bindings.allSatisfy {
            $0.destination == 53 && $0.kind == .note && $0.offValue == 0 && $0.onValue == 127
                && $0.offUsesNoteOn == true
        })
    #expect(bindings.first { $0.action == .playA }?.channel == 0)
    #expect(bindings.first { $0.action == .playA }?.number == 11)
    #expect(bindings.first { $0.action == .syncB }?.channel == 1)
    #expect(bindings.first { $0.action == .syncB }?.number == 88)
    #expect(bindings.first { $0.action == .cueA }?.number == 84)
    let hotcueA = bindings.filter { $0.action.hotcueSlot != nil && $0.targetDeck == .a }
    let hotcueB = bindings.filter { $0.action.hotcueSlot != nil && $0.targetDeck == .b }
    #expect(hotcueA.map(\.channel) == Array(repeating: 7, count: 8))
    #expect(hotcueB.map(\.channel) == Array(repeating: 9, count: 8))
    #expect(hotcueA.map(\.number) == (0..<8).map { UInt8($0) })
    #expect(hotcueB.map(\.number) == (0..<8).map { UInt8($0) })
}
