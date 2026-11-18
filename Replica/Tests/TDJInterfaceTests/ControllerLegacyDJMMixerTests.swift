import Foundation
import TDJCore
import Testing

@testable import TDJInterface

private let legacyDJMNames = ["DJM-900NXS", "DJM-850", "DJM-750MK2"]

@MainActor private func withLegacyDJMMixer(
    _ name: String, decks: [DeckID] = DeckID.allCases,
    _ body: (ControllerMIDIConnection) throws -> Void
) throws {
    let suite = "legacy-djm-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { _, _ in
            Issue.record("A manual legacy DJM profile must not write hardware state.")
            return false
        }, deckAvailability: { decks })
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id + 100), name: name,
            identity: .init(id: id, device: UInt32(id), names: [name]))
    }
    input.reconcileFactoryProfiles()
    #expect(!input.isInputActive(10))
    input.select(10)
    input.applyFactoryProfile(try #require(ControllerFactoryProfile.matching([name])))
    #expect(input.bindingCount == 32)
    try body(input)
}

@MainActor private func legacyDJMPacket(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source)
    input.flushPendingActions()
}

@Test(arguments: legacyDJMNames) @MainActor
func controllerCatalogueLegacyDJMEveryAbsoluteStripAndGlobalRetainsPickupAndDeckAvailability(_ name: String) throws {
    let strips: [[UInt8]] = [
        [1, 2, 3, 4, 5, 17], [6, 7, 8, 9, 10, 18], [12, 14, 15, 21, 22, 19], [80, 81, 92, 82, 83, 20],
    ]
    for decks in [DeckID.primary, DeckID.allCases] {
        try withLegacyDJMMixer(name, decks: decks) { input in
            input.currentTargetValue = { _ in 0.5 }
            var events: [(ControllerActionTarget, Double)] = []
            input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
            for (deck, numbers) in zip(DeckID.allCases, strips) {
                for (number, action) in zip(
                    numbers, [ControllerAction.gainA, .highA, .midA, .lowA, .filterKnobA, .levelA])
                {
                    events.removeAll()
                    legacyDJMPacket([0xB0, number, 0], input)
                    #expect(events.isEmpty)
                    legacyDJMPacket([0xB0, number, 64], input)
                    legacyDJMPacket([0xB0, number, 127], input)
                    #expect(events.count == (decks.contains(deck) ? 2 : 0))
                    #expect(events.allSatisfy { $0.0 == .init(action.assigned(to: deck), deck: deck) })
                    if decks.contains(deck) { #expect(events.map(\.1) == [64.0 / 127, 1]) }
                }
            }
            for (number, action): (UInt8, ControllerAction) in [
                (11, .crossfader), (24, .master), (26, .monitor), (27, .cueMix),
            ] {
                events.removeAll()
                legacyDJMPacket([0xB0, number, 0], input)
                #expect(events.isEmpty)
                legacyDJMPacket([0xB0, number, 64], input)
                legacyDJMPacket([0xB0, number, 127], input)
                #expect(events.map(\.1) == [64.0 / 127, 1] && events.allSatisfy { $0.0.action == action })
            }
        }
    }
}

@Test(arguments: legacyDJMNames) @MainActor
func controllerCatalogueLegacyDJMCueToggleReportsSetStateIndependentlyOnAllFourStrips(_ name: String) throws {
    for decks in [DeckID.primary, DeckID.allCases] {
        try withLegacyDJMMixer(name, decks: decks) { input in
            input.currentTargetValue = { _ in 0.5 }
            var events: [(ControllerActionTarget, Double)] = []
            input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
            for (index, deck) in DeckID.allCases.enumerated() {
                events.removeAll()
                for value: UInt8 in [0, 127, 127, 0, 0, 127] {
                    legacyDJMPacket([0xB0, UInt8(70 + index), value], input)
                }
                #expect(events.count == (decks.contains(deck) ? 6 : 0))
                #expect(events.allSatisfy { $0.0 == .init(ControllerAction.cueStateA.assigned(to: deck), deck: deck) })
                if decks.contains(deck) { #expect(events.map(\.1) == [0, 1, 1, 0, 0, 1]) }
            }
            events.removeAll()
            legacyDJMPacket([0xB0, 70, 127, 17, 64], input, source: 11)
            #expect(events.isEmpty)
        }
    }
}

@Test @MainActor func controllerCatalogueLegacyDJM750MK2SourceSelectorsRetireOnlyTheirStripPickup() throws {
    for (index, numbers) in [[UInt8(51), 52, 53, 67], [55, 56, 57, 69], [59, 60, 61, 71], [63, 64, 65, 73]].enumerated()
    {
        for selector in numbers {
            try withLegacyDJMMixer("DJM-750MK2") { input in
                input.currentTargetValue = { _ in 0.5 }
                var events: [(ControllerActionTarget, Double)] = []
                input.onTargetAction = { target, value in
                    if [.levelA, .levelB].contains(target.action) { events.append((target, value)) }
                }
                legacyDJMPacket([0xB0, 17, 64, 18, 64, 19, 64, 20, 64], input)
                legacyDJMPacket([0xB0, 17, 127, 18, 127, 19, 127, 20, 127], input)
                events.removeAll()
                legacyDJMPacket([0x90, selector, 127, selector, 0], input)
                legacyDJMPacket([0xB0, 17, 127, 18, 127, 19, 127, 20, 127], input)
                #expect(events.count == 3)
                #expect(events.allSatisfy { $0.0.deck != DeckID.allCases[index] })
                legacyDJMPacket([0xB0, UInt8(17 + index), 64], input)
                legacyDJMPacket([0xB0, UInt8(17 + index), 0], input)
                #expect(events.last?.0.deck == DeckID.allCases[index] && events.last?.1 == 0)
            }
        }
    }
}

@Test(arguments: legacyDJMNames) @MainActor
func controllerCatalogueLegacyDJMUnmappedModesClockAndHardwareControlsStayInactive(_ name: String) throws {
    try withLegacyDJMMixer(name) { input in
        input.currentTargetValue = { _ in 0.5 }
        var actions: [ControllerAction] = []
        input.onAction = { action, _ in if !action.isJog { actions.append(action) } }
        for number: UInt8 in [
            13, 23, 25, 30, 31, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 50, 51, 52, 53, 54, 55, 59,
            64, 65, 66, 67, 68, 69, 74, 75, 76, 77, 78, 85, 86, 87, 88, 89, 90, 91, 93, 94, 95, 101, 102, 103, 104, 108,
            114, 115, 116, 118,
        ] {
            legacyDJMPacket([0xB0, number, 64, number, 127, number, 0], input)
        }
        for number: UInt8 in [
            11, 17, 51, 52, 53, 55, 56, 57, 59, 60, 61, 63, 64, 65, 67, 69, 70, 71, 72, 73, 102, 103, 104, 105, 118,
        ] {
            legacyDJMPacket([0x90, number, 127, number, 0], input)
        }
        legacyDJMPacket([0xB1, 17, 64, 70, 127, 0xF8, 0xFA, 0xFC], input)
        #expect(actions.isEmpty)
    }
    let profile = try #require(ControllerFactoryProfile.matching([name]))
    #expect(!profile.selectsAutomatically && profile.definition?.role == "accessory")
    #expect(profile.definition?.audioOutput == nil && profile.definition?.outputs.isEmpty == true)
    #expect(profile.definition?.startup.isEmpty == true && profile.definition?.shutdown.isEmpty == true)
    for sibling in ["DJM-900NXS2", "DJM-900SRT", "DJM-750", "DJM-250MK2", "DJM-TOUR1"] {
        #expect(ControllerFactoryProfile.matching([sibling]) != profile)
    }
}
