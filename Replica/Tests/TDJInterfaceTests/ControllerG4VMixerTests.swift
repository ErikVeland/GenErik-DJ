import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withG4VMixer(
    decks: [DeckID] = DeckID.allCases, _ body: (ControllerMIDIConnection) throws -> Void
) throws {
    let suite = "g4v-mixer-\(UUID().uuidString)"; let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { _, _ in
            Issue.record("The manual G4V mixer must not send hardware commands."); return false
        }, deckAvailability: { decks }, factoryInputConnector: { _ in true })
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id), name: "G4V",
            identity: .init(id: id, device: UInt32(id), names: ["G4V"]))
    }
    input.destinations = [
        .init(id: 20, reference: 200, name: "G4V", identity: .init(id: 20, device: 10, names: ["G4V"]))
    ]
    input.reconcileFactoryProfiles(); #expect(!input.isInputActive(10) && !input.isInputActive(11))
    let p = try #require(ControllerFactoryProfile.matching(["G4V"]))
    for source: Int32 in [10, 11] { input.select(source); input.applyFactoryProfile(p) }
    #expect(input.bindingCount == 48)
    try body(input)
}

@MainActor private func g4vMixerPacket(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source); input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueG4VMixerManualIdentityKeepsPlayersAndAudioUnowned() throws {
    let p = try #require(ControllerFactoryProfile.matching(["Gemini G4V"]))
    let d = try #require(p.definition)
    #expect(
        d.isValid && d.inputs.count == 24 && d.role == "accessory" && !p.selectsAutomatically
            && !p.hasAutomaticSplitOutput)
    #expect(d.outputs.isEmpty && d.startup.isEmpty && d.shutdown.isEmpty && d.audioOutput == nil)
    for name in ["Gemini G4V", "G4V", "G4V Audio"] { #expect(ControllerFactoryProfile.matching([name]) == p) }
    #expect(ControllerFactoryProfile.matching(["G4V"], automaticOnly: true) == nil)
    for name in ["G2V", "Gemini G2V", "G2V Audio", "Slate 4"] {
        #expect(ControllerFactoryProfile.matching([name]) != p)
    }
    #expect(p.feedback(destination: 20).isEmpty)
    try withG4VMixer { _ in }
}

@Test @MainActor func controllerCatalogueG4VMixerPhysicalStripsKeepPickupAndFourDeckOptIn() throws {
    for decks in [DeckID.primary, DeckID.allCases] {
        try withG4VMixer(decks: decks) { input in
            input.currentTargetValue = { _ in 0.5 }
            var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
            for (deck, base): (DeckID, UInt8) in [(.a, 0), (.b, 1), (.c, 2), (.d, 3)] {
                for (offset, action): (UInt8, ControllerAction) in [
                    (1, .gainA), (9, .highA), (5, .midA), (13, .lowA), (17, .filterKnobA), (21, .levelA),
                ] {
                    events.removeAll(); let number = base + offset
                    g4vMixerPacket([0xB3, number, 0], input); #expect(events.isEmpty)
                    g4vMixerPacket([0xB3, number, 64], input); g4vMixerPacket([0xB3, number, 127], input)
                    #expect(events.count == (decks.contains(deck) ? 2 : 0))
                    #expect(events.allSatisfy { $0.0 == .init(action.assigned(to: deck), deck: deck) })
                    if decks.contains(deck) { #expect(events.map(\.1) == [64.0 / 127, 1]) }
                }
            }
        }
    }
}

@Test @MainActor func controllerCatalogueG4VMixerPickupDoesNotTransferBetweenSources() throws {
    try withG4VMixer { input in
        input.currentTargetValue = { _ in 0.5 }
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        g4vMixerPacket([0xB3, 9, 64], input); g4vMixerPacket([0xB3, 9, 127], input)
        events.removeAll(); g4vMixerPacket([0xB3, 9, 0], input, source: 11); #expect(events.isEmpty)
        g4vMixerPacket([0xB3, 9, 0], input); #expect(events.map(\.1) == [0])
        events.removeAll(); g4vMixerPacket([0xB3, 9, 64], input, source: 11)
        #expect(events.map(\.0) == [.init(.highA, deck: .a)] && events.map(\.1) == [64.0 / 127])
    }
}

@Test @MainActor func controllerCatalogueG4VMixerUnqualifiedPlayersGlobalsAndReportsStayInactive() throws {
    try withG4VMixer { input in
        input.currentTargetValue = { _ in 0.5 }
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        let numbers: [UInt8] = Array(1...24)
        for ch: UInt8 in 0..<16 where ch != 3 {
            for n in numbers { g4vMixerPacket([0xB0 + ch, n, 0, n, 64, n, 127], input) }
        }
        for n: UInt8 in 0..<128 where !numbers.contains(n) { g4vMixerPacket([0xB3, n, 0, n, 64, n, 127], input) }
        for ch: UInt8 in 0..<16 {
            g4vMixerPacket(
                [0x90 + ch, 13, 127, 13, 0, 51, 127, 51, 0, 52, 127, 52, 0, 53, 127, 53, 0, 0xE0 + ch, 0, 64], input)
        }
        g4vMixerPacket([0xB3, 9, 64], input, source: 999)
        input.receive(.init(kind: .control, group: 1, channel: 3, number: 9, value: 64), source: 10);
        input.flushPendingActions()
        #expect(events.isEmpty)
    }
}
