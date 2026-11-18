import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func with4Set(decks: [DeckID] = DeckID.allCases, _ body: (ControllerMIDIConnection) throws -> Void)
    throws
{
    let suite = "4set-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, deckAvailability: { decks })
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id + 100), name: "DJ 4Set",
            identity: .init(id: id, device: UInt32(id), names: ["DJ 4Set"]))
    }
    input.reconcileFactoryProfiles()
    #expect(!input.isInputActive(10) && !input.isInputActive(11))
    let profile = try #require(ControllerFactoryProfile.matching(["DJ 4Set"]))
    for source: Int32 in [10, 11] { input.select(source); input.applyFactoryProfile(profile) }
    #expect(input.bindingCount == 164)
    try body(input)
}

@MainActor private func fourSetPacket(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source)
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogue4SetSeparatesNoteBanksFromSharedCCAndHonoursDeckCapacity() throws {
    for decks in [DeckID.primary, DeckID.allCases] {
        try with4Set(decks: decks) { input in
            input.currentTargetValue = { _ in 0.5 }
            var events: [(ControllerActionTarget, Double)] = []
            input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
            for (index, deck) in DeckID.allCases.enumerated() {
                let channel = UInt8(index / 2), side = UInt8(index % 2)
                for (number, action): (UInt8, ControllerAction) in [
                    (14 + 32 * side, .playA), (17 + 32 * side, .syncA), (15 + 32 * side, .cueA), (74 + side, .loadA),
                ] {
                    events.removeAll()
                    fourSetPacket([0x90 + channel, number, 127, number, 127, 0x80 + channel, number, 127], input)
                    #expect(events.count == (decks.contains(deck) ? 1 : 0))
                    #expect(events.allSatisfy { $0.0 == .init(action.assigned(to: deck), deck: deck) })
                }
                for (number, action): (UInt8, ControllerAction) in [
                    (UInt8(5 + 8 * index), .tempoA), (UInt8(3 + 8 * index), .levelA), (UInt8(6 + 8 * index), .highA),
                    (UInt8(7 + 8 * index), .midA), (UInt8(8 + 8 * index), .lowA),
                ] {
                    events.removeAll()
                    fourSetPacket([0xB0, number, 64], input)
                    fourSetPacket([0xB0, number, 127], input)
                    #expect(events.count == (decks.contains(deck) ? 2 : 0))
                    #expect(events.allSatisfy { $0.0 == .init(action.assigned(to: deck), deck: deck) })
                    if decks.contains(deck) { #expect(events.last?.1 == (action == .tempoA ? 0 : 1)) }
                }
            }
        }
    }
}

@Test @MainActor func controllerCatalogue4SetHeldInputsAndBothBankDirectionsRetireOnlyTheirOwners() throws {
    try with4Set { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
        for off: UInt8 in [0x80, 0x90] {
            for (index, deck) in DeckID.allCases.enumerated() {
                let channel = UInt8(index / 2), side = UInt8(index % 2)
                for (number, action): (UInt8, ControllerAction) in [
                    (13 + 32 * side, .cuePreviewA), (side == 0 ? 29 : 67, .pitchBendDownA),
                    (side == 0 ? 30 : 68, .pitchBendUpA),
                ] {
                    events.removeAll()
                    fourSetPacket(
                        [0x90 + channel, number, 127, number, 127, off + channel, number, off == 0x80 ? 127 : 0], input)
                    #expect(events.map(\.1) == [1, 0])
                    #expect(events.allSatisfy { $0.0 == .init(action.assigned(to: deck), deck: deck) })
                }
            }
        }
        events.removeAll()
        fourSetPacket([0x90, 13, 127, 45, 127, 0x91, 13, 127], input)
        fourSetPacket([0x90, 13, 127], input, source: 11)
        fourSetPacket([0x90, 18, 127], input)
        #expect(events.map(\.0.deck) == [.a, .b, .c, .c])
        fourSetPacket([0x80, 13, 127], input, source: 11)
        #expect(events.last?.0.deck == .a && events.last?.1 == 0)
        fourSetPacket([0x90, 13, 127, 0x80, 18, 127], input)
        #expect(events.last?.0.deck == .a && events.last?.1 == 1)
        fourSetPacket([0x90, 72, 127, 0x91, 13, 127, 0x90, 72, 0], input)
        #expect(events.suffix(3).map(\.0.deck) == [.a, .c, .c] && events.suffix(3).map(\.1) == [0, 1, 0])
        input.stop()
        #expect(events.last?.0.deck == .b && events.last?.1 == 0)
    }
}

@Test @MainActor func controllerCatalogue4SetShiftSurvivesNoteBankHandoverAndKeepsOtherSideAndSources() throws {
    try with4Set { input in
        var plays: [DeckID?] = [], counts: [Double] = []
        input.onTargetAction = { target, _ in if [.playA, .playB].contains(target.action) { plays.append(target.deck) }
        }
        input.onJogAction = { _, value in if case .relative(let count) = value { counts.append(count) } }
        fourSetPacket([0xB0, 36, 1], input)
        #expect(counts.isEmpty)
        fourSetPacket([0x90, 26, 127, 0xB0, 36, 1], input)
        fourSetPacket([0xB0, 1, 127], input)
        #expect(counts == [1, -1])
        fourSetPacket([0x90, 28, 127, 27, 127, 28, 0, 14, 127, 14, 0, 46, 127, 46, 0, 0x91, 14, 127, 14, 0], input)
        #expect(plays == [.b])
        fourSetPacket([0x90, 14, 127, 14, 0], input, source: 11)
        #expect(plays == [.b, .a])
        fourSetPacket([0x91, 27, 0, 14, 127, 14, 0], input)
        #expect(plays == [.b, .a, .c])
    }
}

@Test @MainActor func controllerCatalogue4SetFeedbackAndIgnoredPagesDoNotInstallDriversOrWriteSettings() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["DJ 4Set"]))
    let definition = try #require(profile.definition)
    #expect(!profile.selectsAutomatically && definition.inputs.count == 82 && definition.outputs.count == 16)
    #expect(definition.startup.isEmpty && definition.shutdown.isEmpty && definition.audioOutput == nil)
    #expect(definition.inputs.filter { $0.action.isJog }.allSatisfy { $0.argument == 250 })
    let light = try #require(
        profile.feedback(destination: 20).first { $0.action == .cuePreviewA && $0.targetDeck == .c })
    #expect(light.message(value: 1) == [0x91, 13, 127] && light.message(value: 0) == [0x91, 13, 0])
    for name in ["DJ Console 4-Mx", "DJ Console MK4", "DJControl AIR+"] {
        #expect(ControllerFactoryProfile.matching([name]) != profile)
    }
    try with4Set { input in
        var actions: [ControllerAction] = []
        input.onAction = { action, _ in if !action.isJog { actions.append(action) } }
        for channel: UInt8 in [0, 1] {
            for number: UInt8 in [
                1, 2, 3, 7, 8, 9, 19, 20, 31, 32, 33, 34, 35, 39, 40, 41, 51, 52, 60, 61, 62, 63, 69, 70, 71,
            ] { fourSetPacket([0x90 + channel, number, 127, number, 0], input) }
        }
        for number: UInt8 in [12, 40, 41, 42, 43, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 125, 126, 127]
        { fourSetPacket([0xB0, number, 127, number, 0], input) }
        fourSetPacket([0xB1, 3, 64, 5, 64], input)
        #expect(actions.isEmpty)
    }
}
