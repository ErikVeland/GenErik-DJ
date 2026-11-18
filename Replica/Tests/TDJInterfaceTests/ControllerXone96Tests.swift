import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withXone96(decks: [DeckID] = DeckID.allCases, _ body: (ControllerMIDIConnection) throws -> Void)
    throws
{
    let suite = "xone96-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { _, _ in
            Issue.record("The Xone:96 subset must not change hardware Cue or filter states.")
            return false
        }, deckAvailability: { decks })
    input.sources = [
        .init(id: 10, reference: 100, name: "Xone:96", identity: .init(id: 10, device: 1, names: ["Xone:96"]))
    ]
    input.destinations = [
        .init(id: 20, reference: 200, name: "Xone:96", identity: .init(id: 20, device: 1, names: ["Xone:96"]))
    ]
    input.reconcileFactoryProfiles()
    #expect(!input.isInputActive(10))
    input.select(10)
    input.applyFactoryProfile(try #require(ControllerFactoryProfile.matching(["Xone:96"])))
    #expect(input.bindingCount == 9)
    try body(input)
}

@MainActor private func xone96Packet(_ bytes: [UInt8], _ input: ControllerMIDIConnection) {
    input.receiveBytes(bytes, source: 10)
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueXone96KeepsDefaultChannel16AndFourDeckOptIn() throws {
    for decks in [DeckID.primary, DeckID.allCases] {
        try withXone96(decks: decks) { input in
            input.currentTargetValue = { _ in 0.5 }
            var events: [(ControllerActionTarget, Double)] = []
            input.onTargetAction = { events.append(($0, $1)) }
            for (number, deck) in DeckID.allCases.enumerated() {
                events.removeAll()
                xone96Packet([0xBF, UInt8(number), 64], input)
                xone96Packet([0xBF, UInt8(number), 127], input)
                #expect(events.count == (decks.contains(deck) ? 2 : 0))
                #expect(events.allSatisfy { $0.0 == .init(ControllerAction.levelA.assigned(to: deck), deck: deck) })
            }
            events.removeAll()
            xone96Packet([0xBF, 5, 64], input)
            xone96Packet([0xBF, 5, 0], input)
            #expect(events.map(\.0.action) == [.crossfader, .crossfader] && events.last?.1 == 0)
            events.removeAll()
            xone96Packet([0xB0, 0, 127, 5, 127, 0x90, 0, 127], input)
            #expect(events.isEmpty)
        }
    }
}

@Test @MainActor func controllerCatalogueXone96CueMessagesSetStateInsteadOfTogglingEveryReport() throws {
    try withXone96 { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        for (number, deck) in DeckID.allCases.enumerated() {
            events.removeAll()
            let number = UInt8(number)
            xone96Packet([0x9F, number, 127, number, 127, number, 0, number, 127, 0x8F, number, 127], input)
            #expect(events.map(\.1) == [1, 1, 0, 1, 0])
            #expect(events.allSatisfy { $0.0 == .init(ControllerAction.cueStateA.assigned(to: deck), deck: deck) })
        }
    }
}

@Test @MainActor func controllerCatalogueXone96SourceSelectionRearmsOnlyItsOwnFaderPickup() throws {
    try withXone96 { input in
        input.currentTargetValue = { _ in 0.5 }
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        for number: UInt8 in [0, 1] {
            xone96Packet([0xBF, number, 64], input)
            xone96Packet([0xBF, number, 127], input)
        }
        events.removeAll()
        xone96Packet([0x9F, 20, 127], input)
        xone96Packet([0xBF, 0, 0], input)
        #expect(events.isEmpty)
        xone96Packet([0xBF, 1, 0], input)
        #expect(events.map(\.deck) == [.b])
        xone96Packet([0xBF, 0, 64], input)
        #expect(events.map(\.deck) == [.b, .a])
    }
}

@Test @MainActor func controllerCatalogueXone96DoesNotWriteHardwareStatesOrInventAnalogueKnobs() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["Xone:96"]))
    let data = try #require(profile.definition)
    #expect(!profile.selectsAutomatically && !profile.hasAutomaticSplitOutput)
    #expect(data.outputs.isEmpty && data.startup.isEmpty && data.shutdown.isEmpty && data.audioOutput == nil)
    for name in ["Xone:92", "Xone:PX5", "Xone:23C", "Xone:24C", "Xone:96 clone"] {
        #expect(ControllerFactoryProfile.matching([name]) != profile)
    }
    try withXone96 { input in
        var actions: [ControllerAction] = []
        input.onAction = { action, value in if !(action.isJog && value == 0.5) { actions.append(action) } }
        for number: UInt8 in [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 43, 44, 45, 46, 47, 48, 49, 50, 51]
        {
            xone96Packet([0x9F, number, 127, number, 0], input)
        }
        xone96Packet([0xBF, 4, 127, 6, 127, 7, 127, 8, 127], input)
        input.stop()
        #expect(actions.isEmpty)
    }
}
