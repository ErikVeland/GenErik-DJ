import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withXone43C(
    decks: [DeckID] = DeckID.allCases, _ body: (ControllerMIDIConnection) throws -> Void
) throws {
    let suite = "xone43c-\(UUID().uuidString)"; let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { _, _ in
            Issue.record("Xone:43C input must not change hardware Cue or filter states."); return false
        }, deckAvailability: { decks }, factoryInputConnector: { _ in true })
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id), name: "Xone:43C",
            identity: .init(id: id, device: UInt32(id), names: ["Xone:43C"]))
    }
    input.destinations = [
        .init(id: 20, reference: 200, name: "Xone:43C", identity: .init(id: 20, device: 10, names: ["Xone:43C"]))
    ]
    input.reconcileFactoryProfiles(); #expect(!input.isInputActive(10) && !input.isInputActive(11))
    let p = try #require(ControllerFactoryProfile.matching(["Xone:43C"]))
    for source: Int32 in [10, 11] { input.select(source); input.applyFactoryProfile(p) }
    #expect(input.bindingCount == 16)
    try body(input)
}

@MainActor private func xone43CPacket(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source); input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueXone43CManualIdentityDoesNotOwnAnalogueMixer() throws {
    let p = try #require(ControllerFactoryProfile.matching(["Allen & Heath XONE 43C"]))
    let d = try #require(p.definition)
    #expect(d.isValid && d.inputs.count == 8 && !p.selectsAutomatically && !p.hasAutomaticSplitOutput)
    #expect(d.outputs.isEmpty && d.startup.isEmpty && d.shutdown.isEmpty && d.audioOutput == nil)
    #expect(ControllerFactoryProfile.matching(["Xone:43C"], automaticOnly: true) == nil)
    for name in ["XONE43C", "Xone 43C", "Allen & Heath Xone:43C"] {
        #expect(ControllerFactoryProfile.matching([name]) == p)
    }
    for name in ["Xone:43", "Xone:23C", "Xone:24C", "Xone:96", "Xone:PX5"] {
        #expect(ControllerFactoryProfile.matching([name]) != p)
    }
    #expect(p.feedback(destination: 20).isEmpty)
    try withXone43C { _ in }
}

@Test @MainActor func controllerCatalogueXone43CFadersKeepPickupAndFourDeckOptIn() throws {
    for decks in [DeckID.primary, DeckID.allCases] {
        try withXone43C(decks: decks) { input in
            input.currentTargetValue = { _ in 0.5 }
            var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
            for (number, deck) in DeckID.allCases.enumerated() {
                events.removeAll()
                xone43CPacket([0xBF, UInt8(number), 0], input); #expect(events.isEmpty)
                xone43CPacket([0xBF, UInt8(number), 64], input); xone43CPacket([0xBF, UInt8(number), 127], input)
                #expect(events.count == (decks.contains(deck) ? 2 : 0))
                #expect(events.allSatisfy { $0.0 == .init(ControllerAction.levelA.assigned(to: deck), deck: deck) })
                if decks.contains(deck) { #expect(events.last?.1 == 1) }
            }
        }
    }
}

@Test @MainActor func controllerCatalogueXone43CAsymmetricCueNotesSetStateAndKeepBothOffForms() throws {
    for decks in [DeckID.primary, DeckID.allCases] {
        try withXone43C(decks: decks) { input in
            var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
            for (n, deck): (UInt8, DeckID) in [(77, .a), (57, .b), (37, .c), (17, .d)] {
                events.removeAll()
                xone43CPacket([0x9F, n, 127, n, 127, n, 0, n, 127, 0x8F, n, 127], input)
                #expect(events.map(\.1) == (decks.contains(deck) ? [1, 1, 0, 1, 0] : []))
                #expect(events.allSatisfy { $0.0 == .init(ControllerAction.cueStateA.assigned(to: deck), deck: deck) })
            }
        }
    }
}

@Test @MainActor func controllerCatalogueXone43CPickupRemainsOwnedByItsSource() throws {
    try withXone43C { input in
        input.currentTargetValue = { _ in 0.5 }
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        xone43CPacket([0xBF, 0, 64], input); xone43CPacket([0xBF, 0, 127], input)
        events.removeAll(); xone43CPacket([0xBF, 0, 0], input, source: 11); #expect(events.isEmpty)
        xone43CPacket([0xBF, 0, 0], input); #expect(events.map(\.1) == [0])
        events.removeAll(); xone43CPacket([0xBF, 0, 64], input, source: 11)
        #expect(events.map(\.0) == [.init(.levelA, deck: .a)] && events.map(\.1) == [64.0 / 127])
    }
}

@Test @MainActor func controllerCatalogueXone43CUnqualifiedChannelsKnobsAndStatesStayInactive() throws {
    try withXone43C { input in
        input.currentTargetValue = { _ in 0.5 }
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        for ch: UInt8 in 0..<15 {
            xone43CPacket(
                [0xB0 + ch, 0, 64, 1, 64, 2, 64, 3, 64, 0x90 + ch, 77, 127, 57, 127, 37, 127, 17, 127], input)
        }
        for n: UInt8 in 0..<128 where ![77, 57, 37, 17].contains(n) {
            xone43CPacket([0x9F, n, 127, n, 0], input)
        }
        for n: UInt8 in 4..<128 { xone43CPacket([0xBF, n, 0, n, 64, n, 127], input) }
        xone43CPacket([0xEF, 0, 64], input)
        xone43CPacket([0xBF, 0, 64, 0x9F, 77, 127], input, source: 999)
        input.receive(.init(kind: .control, group: 1, channel: 15, number: 0, value: 64), source: 10);
        input.flushPendingActions()
        #expect(events.isEmpty)
    }
}
