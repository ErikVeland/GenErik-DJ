import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withA9(decks: [DeckID] = DeckID.allCases, _ body: (ControllerMIDIConnection) throws -> Void)
    throws
{
    let suite = "djm-a9-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, deckAvailability: { decks })
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id + 100), name: "DJM-A9",
            identity: .init(id: id, device: UInt32(id), names: ["DJM-A9"]))
    }
    input.reconcileFactoryProfiles()
    #expect(!input.isInputActive(10))
    input.select(10)
    input.applyFactoryProfile(try #require(ControllerFactoryProfile.matching(["DJM-A9"])))
    #expect(input.bindingCount == 30)
    try body(input)
}

@MainActor private func a9Packet(_ bytes: [UInt8], to input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source)
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueA9UnambiguousMixerRowsKeepTheirOwnAddressesAndDeckOptIn() throws {
    for decks in [DeckID.primary, DeckID.allCases] {
        try withA9(decks: decks) { input in
            input.currentTargetValue = { _ in 0.5 }
            var events: [(ControllerActionTarget, Double)] = []
            input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
            let addresses: [[UInt8]] = [
                [1, 2, 3, 4, 5], [6, 7, 8, 9, 10], [12, 14, 15, 21, 22], [80, 81, 92, 82, 83],
            ]
            for (index, deck) in DeckID.allCases.enumerated() {
                for (number, action) in zip(
                    addresses[index], [ControllerAction.gainA, .highA, .midA, .lowA, .filterKnobA])
                {
                    events.removeAll()
                    a9Packet([0xB0, number, 64], to: input)
                    a9Packet([0xB0, number, 127], to: input)
                    #expect(events.count == (decks.contains(deck) ? 2 : 0))
                    #expect(events.allSatisfy { $0.0 == .init(action.assigned(to: deck), deck: deck) })
                    if decks.contains(deck) { #expect(events.map(\.1) == [64.0 / 127, 1]) }
                }
            }
            for (deck, number): (DeckID, UInt8) in [(.c, 19), (.d, 20)] {
                events.removeAll()
                a9Packet([0xB0, number, 0], to: input)
                #expect(events.isEmpty)
                a9Packet([0xB0, number, 64], to: input)
                #expect(events.count == (decks.contains(deck) ? 1 : 0))
                #expect(events.allSatisfy { $0.0 == .init(ControllerAction.levelA.assigned(to: deck), deck: deck) })
            }
            for (number, action): (UInt8, ControllerAction) in [
                (24, .master), (26, .monitor), (27, .cueMix), (11, .crossfader),
            ] {
                events.removeAll()
                a9Packet([0xB0, number, 64], to: input)
                a9Packet([0xB0, number, 0], to: input)
                #expect(events.map(\.1) == [64.0 / 127, 0])
                #expect(events.allSatisfy { $0.0.action == action })
            }
        }
    }
}

@Test @MainActor func controllerCatalogueA9DefaultToggleCueStatesRemainExplicitAndIndependent() throws {
    for decks in [DeckID.primary, DeckID.allCases] {
        try withA9(decks: decks) { input in
            input.currentTargetValue = { _ in 1 }
            var events: [(ControllerActionTarget, Double)] = []
            input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
            for (index, deck) in DeckID.allCases.enumerated() {
                events.removeAll()
                let number = UInt8(10 + index)
                for value: UInt8 in [0, 127, 127, 0, 0, 127] { a9Packet([0x90, number, value], to: input) }
                #expect(events.count == (decks.contains(deck) ? 6 : 0))
                #expect(events.allSatisfy { $0.0 == .init(ControllerAction.cueStateA.assigned(to: deck), deck: deck) })
                if decks.contains(deck) { #expect(events.map(\.1) == [0, 1, 1, 0, 0, 1]) }
            }
            events.removeAll()
            input.select(11)
            a9Packet([0x90, 10, 127, 10, 0], to: input, source: 11)
            #expect(events.isEmpty)
        }
    }
}

@Test @MainActor func controllerCatalogueA9ConflictingFadersCueBAndUnownedHardwareNeverBecomeAppActions() throws {
    try withA9 { input in
        input.currentTargetValue = { _ in 0.5 }
        var actions: [ControllerAction] = []
        input.onAction = { action, _ in if !action.isJog { actions.append(action) } }
        for number: UInt8 in [
            17, 18, 25, 30, 31, 33, 34, 65, 66, 67, 68, 85, 86, 91, 94, 95, 97, 98, 99, 100, 101, 108, 109, 110, 114,
        ] {
            a9Packet([0xB0, number, 64], to: input)
            a9Packet([0xB0, number, 127, number, 0], to: input)
        }
        for number: UInt8 in [
            14, 15, 16, 17, 18, 19, 20, 21, 32, 33, 34, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65,
            66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 96, 97, 98, 112,
        ] {
            a9Packet([0x90, number, 127, number, 0], to: input)
        }
        a9Packet([0xB1, 1, 127, 0x91, 10, 127, 0xF8, 0xFA, 0xFC], to: input)
        #expect(actions.isEmpty)
    }
    let profile = try #require(ControllerFactoryProfile.matching(["DJM-A9"]))
    #expect(!profile.selectsAutomatically && profile.definition?.role == "accessory")
    #expect(profile.definition?.outputs.isEmpty == true && profile.definition?.startup.isEmpty == true)
    #expect(profile.definition?.shutdown.isEmpty == true && profile.definition?.audioOutput == nil)
    for name in ["DJM-A7", "DJM-V5", "DJM-V10", "Euphonia"] {
        #expect(ControllerFactoryProfile.matching([name]) != profile)
    }
}
