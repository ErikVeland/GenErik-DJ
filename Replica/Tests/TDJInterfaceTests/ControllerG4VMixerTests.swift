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
    #expect(input.bindingCount == 78)
    try body(input)
}

@MainActor private func g4vMixerPacket(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source); input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueG4VMixerManualIdentityKeepsPlayersAndAudioUnowned() throws {
    let p = try #require(ControllerFactoryProfile.matching(["Gemini G4V"]))
    let d = try #require(p.definition)
    #expect(
        d.isValid && d.inputs.count == 39 && d.role == nil && !p.selectsAutomatically
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
        let numbers: [UInt8] = Array(1...27)
        for ch: UInt8 in 0..<16 where ch != 3 {
            for n in numbers { g4vMixerPacket([0xB0 + ch, n, 0, n, 64, n, 127], input) }
        }
        for n: UInt8 in 0..<128 where !numbers.contains(n) { g4vMixerPacket([0xB3, n, 0, n, 64, n, 127], input) }
        for ch: UInt8 in 0..<16 {
            g4vMixerPacket(
                [0x90 + ch, 51, 127, 51, 0, 52, 127, 52, 0, 53, 127, 53, 0, 0xE0 + ch, 0, 64], input)
        }
        g4vMixerPacket([0xB3, 9, 64], input, source: 999)
        input.receive(.init(kind: .control, group: 1, channel: 3, number: 9, value: 64), source: 10);
        input.flushPendingActions()
        #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueG4VMixerManualBanksKeepTransportAndSideIndependence() throws {
    try withG4VMixer { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        for (ch, decks): (UInt8, [DeckID]) in [(0, [.a, .c]), (1, [.b, .d])] {
            for deck in decks {
                for (action, n): (ControllerAction, UInt8) in [(.playA, 1), (.syncA, 4), (.keylockA, 5)] {
                    for off: UInt8 in [0x80, 0x90] {
                        events.removeAll();
                        g4vMixerPacket(
                            [0x90 + ch, n, 127, n, 127, off + ch, n, off == 0x80 ? 127 : 0, 0x90 + ch, n, 1, n, 0],
                            input)
                        #expect(events == Array(repeating: .init(action.assigned(to: deck), deck: deck), count: 2))
                    }
                }
                g4vMixerPacket([0x90 + ch, 38, 127, 38, 127, 38, 0], input)
            }
        }
    }
}

@Test @MainActor func controllerCatalogueG4VMixerHeldCueKeepsBothBanksVelocitiesAndOffForms() throws {
    try withG4VMixer { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        for (ch, decks): (UInt8, [DeckID]) in [(0, [.a, .c]), (1, [.b, .d])] {
            for deck in decks {
                for velocity: UInt8 in [1, 64, 127] {
                    for off: UInt8 in [0x80, 0x90] {
                        events.removeAll();
                        g4vMixerPacket([0x90 + ch, 2, velocity, 2, 127, off + ch, 2, off == 0x80 ? 127 : 0], input)
                        #expect(events.map(\.1) == [Double(velocity) / 127, 0])
                        #expect(
                            events.allSatisfy {
                                $0.0 == .init(ControllerAction.cuePreviewA.assigned(to: deck), deck: deck)
                            })
                    }
                }
                g4vMixerPacket([0x90 + ch, 38, 127, 38, 0], input)
            }
        }
    }
}

@Test @MainActor func controllerCatalogueG4VMixerBankCleanupKeepsSourceOwnershipAndManualReset() throws {
    try withG4VMixer { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        g4vMixerPacket([0x90, 2, 127, 0x91, 2, 127], input)
        g4vMixerPacket([0x90, 2, 127], input, source: 11); events.removeAll()
        g4vMixerPacket([0x90, 38, 127, 38, 0], input); #expect(events.isEmpty)
        g4vMixerPacket([0x80, 2, 127], input); #expect(events.isEmpty)
        g4vMixerPacket([0x90, 2, 0], input, source: 11)
        #expect(events.map(\.0) == [.init(.cuePreviewA, deck: .a)] && events.map(\.1) == [0])
        events.removeAll(); g4vMixerPacket([0x90, 2, 127], input)
        #expect(events.map(\.0) == [.init(.cuePreviewA, deck: .c)])
        events.removeAll(); g4vMixerPacket([0x81, 2, 127], input)
        #expect(events.map(\.0) == [.init(.cuePreviewB, deck: .b)] && events.map(\.1) == [0])
        let p = try #require(ControllerFactoryProfile.matching(["G4V"]))
        events.removeAll(); input.select(10); input.applyFactoryProfile(p)
        #expect(events.map(\.0) == [.init(.cuePreviewA, deck: .c)] && events.map(\.1) == [0])
        events.removeAll(); g4vMixerPacket([0x90, 2, 127, 2, 0], input)
        #expect(events.map(\.0) == Array(repeating: .init(.cuePreviewA, deck: .a), count: 2))
    }
    try withG4VMixer(decks: DeckID.primary) { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        g4vMixerPacket([0x90, 38, 127, 38, 0, 1, 127, 1, 0, 2, 127, 2, 0], input); #expect(events.isEmpty)
        g4vMixerPacket([0x93, 13, 127, 13, 0], input)
        #expect(events == [.init(.cueA, deck: .a)])
    }
}

@Test @MainActor func controllerCatalogueG4VMixerFixedPFLAndGlobalsIgnorePlayerBankChanges() throws {
    try withG4VMixer { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        g4vMixerPacket([0x90, 38, 127, 38, 0, 0x91, 38, 127, 38, 0], input)
        for (i, deck) in DeckID.allCases.enumerated() {
            events.removeAll(); g4vMixerPacket([0x93, UInt8(13 + i), 127, UInt8(13 + i), 127, UInt8(13 + i), 0], input)
            #expect(events.map(\.0) == [.init(ControllerAction.cueA.assigned(to: deck), deck: deck)])
        }
        input.currentTargetValue = { _ in 0.5 }
        for (n, action): (UInt8, ControllerAction) in [(25, .crossfader), (26, .cueMix), (27, .master)] {
            events.removeAll(); g4vMixerPacket([0xB3, n, 0], input); #expect(events.isEmpty)
            g4vMixerPacket([0xB3, n, 64], input); g4vMixerPacket([0xB3, n, 127], input)
            #expect(events.count == 2 && events.allSatisfy { $0.0 == .init(action) })
            #expect(events.last?.1 == (n == 25 ? 0 : 1))
        }
    }
}
