import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withVMS41Traktor(
    decks: [DeckID] = DeckID.allCases, _ body: (ControllerMIDIConnection) throws -> Void
) throws {
    let suite = "vms41-traktor-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { _, _ in
            Issue.record("The Traktor-edition mixer subset must not write hardware state.")
            return false
        }, deckAvailability: { decks })
    input.sources = [
        .init(
            id: 10, reference: 100, name: "VMS4.1 Traktor",
            identity: .init(id: 10, device: 1, names: ["VMS4.1 Traktor"]))
    ]
    input.reconcileFactoryProfiles()
    #expect(!input.isInputActive(10))
    input.select(10)
    input.applyFactoryProfile(try #require(ControllerFactoryProfile.matching(["VMS4.1 Traktor"])))
    #expect(input.bindingCount == 24)
    try body(input)
}

@MainActor private func vms41Packet(_ bytes: [UInt8], _ input: ControllerMIDIConnection) {
    input.receiveBytes(bytes, source: 10)
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueVMS41TraktorKeepsEachPhysicalStripAndFourDeckOptIn() throws {
    for decks in [DeckID.primary, DeckID.allCases] {
        try withVMS41Traktor(decks: decks) { input in
            input.currentTargetValue = { _ in 0.5 }
            var events: [(ControllerActionTarget, Double)] = []
            input.onTargetAction = { events.append(($0, $1)) }
            for (index, deck) in DeckID.allCases.enumerated() {
                for (delta, action): (Int, ControllerAction) in [
                    (0, .gainA), (1, .highA), (2, .midA), (3, .lowA), (4, .levelA),
                ] {
                    let number = UInt8(index * 5 + delta)
                    events.removeAll()
                    vms41Packet([0xB0, number, 0], input)
                    #expect(events.isEmpty)
                    vms41Packet([0xB0, number, 64], input)
                    vms41Packet([0xB0, number, 127], input)
                    #expect(events.count == (decks.contains(deck) ? 2 : 0))
                    #expect(events.allSatisfy { $0.0 == .init(action.assigned(to: deck), deck: deck) })
                    if decks.contains(deck) { #expect(events.last?.1 == 1) }
                }
            }
        }
    }
}

@Test @MainActor func controllerCatalogueVMS41TraktorKeepsNormalCrossfaderAndDistinctCueGain() throws {
    try withVMS41Traktor { input in
        input.currentTargetValue = { _ in 0.5 }
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        for (number, action): (UInt8, ControllerAction) in [
            (28, .master), (31, .crossfader), (34, .cueMix), (35, .monitor),
        ] {
            events.removeAll()
            vms41Packet([0xB0, number, 64], input)
            vms41Packet([0xB0, number, 0], input)
            vms41Packet([0xB0, number, 127], input)
            #expect(events.map(\.1) == [64.0 / 127, 0, 1] && events.allSatisfy { $0.0 == .init(action) })
        }
    }
}

@Test @MainActor func controllerCatalogueVMS41TraktorIgnoresConflictingTransportAndOtherChannels() throws {
    try withVMS41Traktor { input in
        var events: [ControllerAction] = []
        input.onAction = { action, value in if !(action.isJog && value == 0.5) { events.append(action) } }
        for number: UInt8 in 0..<128 { vms41Packet([0x90, number, 127, number, 0], input) }
        for number: UInt8 in [20, 21, 27, 29, 30, 32, 33, 36, 40, 48, 49, 50, 51, 52] {
            vms41Packet([0xB0, number, 127], input)
        }
        vms41Packet([0xB1, 4, 127, 0xE0, 127, 127], input)
        input.stop()
        #expect(events.isEmpty)
    }
}

@Test func controllerCatalogueVMS41TraktorRemainsDistinctManualAndWithoutAutomaticAudio() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["VMS4.1 Traktor Edition"]))
    let data = try #require(profile.definition)
    #expect(!profile.selectsAutomatically && !profile.hasAutomaticSplitOutput)
    #expect(data.inputs.count == 24 && data.outputs.isEmpty && data.startup.isEmpty && data.shutdown.isEmpty)
    #expect(data.bankChanges == nil && data.audioOutput == nil)
    for name in ["VMS4", "VMS4.1", "VMS5", "VMS4.1 Traktor clone"] {
        #expect(ControllerFactoryProfile.matching([name]) != profile)
    }
}
