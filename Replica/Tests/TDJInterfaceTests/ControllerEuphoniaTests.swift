import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withEuphonia(
    decks: [DeckID] = DeckID.allCases, _ body: (ControllerMIDIConnection) throws -> Void
) throws {
    let suite = "euphonia-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let name = "Euphonia"
    let input = ControllerMIDIConnection(preferences: preferences, deckAvailability: { decks })
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    #expect(!input.isInputActive(10))
    input.select(10)
    input.applyFactoryProfile(try #require(ControllerFactoryProfile.matching([name])))
    #expect(input.bindingCount == 27)
    try body(input)
}

@MainActor private func euphoniaPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    input.receiveBytes(bytes, source: 10)
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueEuphoniaEveryStripAndGlobalKeepsExactManufacturerAddress() throws {
    for decks in [DeckID.primary, DeckID.allCases] {
        try withEuphonia(decks: decks) { input in
            input.currentTargetValue = { _ in 0.5 }
            var events: [(ControllerActionTarget, Double)] = []
            input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
            let addresses: [[UInt8]] = [
                [1, 2, 3, 4, 17], [6, 7, 8, 9, 18], [12, 14, 15, 21, 19], [80, 81, 92, 82, 20],
            ]
            for (index, deck) in DeckID.allCases.enumerated() {
                for (number, action) in zip(addresses[index], [ControllerAction.gainA, .highA, .midA, .lowA, .levelA]) {
                    events.removeAll()
                    euphoniaPacket([0xB0, number, 64], to: input)
                    euphoniaPacket([0xB0, number, 127], to: input)
                    #expect(events.count == (decks.contains(deck) ? 2 : 0))
                    #expect(events.allSatisfy { $0.0 == .init(action.assigned(to: deck), deck: deck) })
                    if decks.contains(deck) { #expect(events.map(\.1) == [64.0 / 127, 1]) }
                }
            }
            for (number, action): (UInt8, ControllerAction) in [(24, .master), (26, .monitor), (27, .cueMix)] {
                events.removeAll()
                euphoniaPacket([0xB0, number, 64], to: input)
                euphoniaPacket([0xB0, number, 0], to: input)
                #expect(events.map(\.1) == [64.0 / 127, 0])
                #expect(events.allSatisfy { $0.0.action == action })
            }
        }
    }
}

@Test @MainActor func controllerCatalogueEuphoniaLatchedPFLKeepsBothStatesWithoutPickupOrToggleEdges() throws {
    for decks in [DeckID.primary, DeckID.allCases] {
        try withEuphonia(decks: decks) { input in
            input.currentTargetValue = { _ in 1 }
            var events: [(ControllerActionTarget, Double)] = []
            input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
            for (index, deck) in DeckID.allCases.enumerated() {
                events.removeAll()
                let number = UInt8(index + 10)
                for value: UInt8 in [0, 127, 127, 0, 0, 127] { euphoniaPacket([0x90, number, value], to: input) }
                if decks.contains(deck) {
                    #expect(events.map(\.1) == [0, 1, 1, 0, 0, 1])
                    #expect(
                        events.allSatisfy { $0.0 == .init(ControllerAction.cueStateA.assigned(to: deck), deck: deck) })
                } else {
                    #expect(events.isEmpty)
                }
            }
        }
    }
}

@Test @MainActor func controllerCatalogueEuphoniaNoteAndCCRemainDistinctAndOtherHardwareControlsStayInactive() throws {
    try withEuphonia { input in
        input.currentTargetValue = { _ in 0.5 }
        var events: [(ControllerAction, Double)] = []
        input.onAction = { action, value in if !action.isJog { events.append((action, value)) } }
        euphoniaPacket([0xB0, 12, 64], to: input)
        euphoniaPacket([0x90, 12, 127], to: input)
        #expect(events.map(\.0) == [.gainA, .cueStateA])
        events.removeAll()
        for number: UInt8 in [
            5, 10, 22, 25, 30, 31, 42, 50, 51, 54, 55, 62, 78, 79, 83, 89, 103, 104, 105, 106, 107, 108, 109, 110,
        ] {
            euphoniaPacket([0xB0, number, 127, number, 0], to: input)
        }
        for number: UInt8 in [
            33, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 80, 81, 82, 83, 88, 96,
        ] {
            euphoniaPacket([0x90, number, 127, number, 0], to: input)
        }
        euphoniaPacket([0xB1, 1, 127, 0x91, 10, 127, 0xF8, 0xFA, 0xFC], to: input)
        #expect(events.isEmpty)
    }
    let profile = try #require(ControllerFactoryProfile.matching(["AlphaTheta Euphonia"]))
    #expect(!profile.selectsAutomatically && profile.definition?.role == "accessory")
    #expect(profile.definition?.outputs.isEmpty == true && profile.definition?.startup.isEmpty == true)
    #expect(profile.definition?.shutdown.isEmpty == true && profile.definition?.audioOutput == nil)
    for name in ["DJM-A9", "DJM-A7", "DJM-V10", "MP2015"] {
        #expect(ControllerFactoryProfile.matching([name]) != profile)
    }
}
