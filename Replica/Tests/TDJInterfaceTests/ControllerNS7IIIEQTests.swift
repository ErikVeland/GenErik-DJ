import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withNS7IIIEQ(
    decks: [DeckID] = DeckID.allCases, _ body: (ControllerMIDIConnection) throws -> Void
) throws {
    let suite = "ns7iii-eq-\(UUID().uuidString)"; let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { _, _ in
            Issue.record("The manual NS7III EQ subset must not send hardware commands."); return false
        }, deckAvailability: { decks }, factoryInputConnector: { _ in true })
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id), name: "NS7III",
            identity: .init(id: id, device: UInt32(id), names: ["NS7III"]))
    }
    input.destinations = [
        .init(id: 20, reference: 200, name: "NS7III", identity: .init(id: 20, device: 10, names: ["NS7III"]))
    ]
    input.reconcileFactoryProfiles(); #expect(!input.isInputActive(10) && !input.isInputActive(11))
    let p = try #require(ControllerFactoryProfile.matching(["NS7III"]))
    for source: Int32 in [10, 11] { input.select(source); input.applyFactoryProfile(p) }
    #expect(input.bindingCount == 24)
    try body(input)
}

@MainActor private func ns7iiiEQPacket(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source); input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueNS7IIIEQManualIdentityKeepsMotorsAndAudioUnowned() throws {
    let p = try #require(ControllerFactoryProfile.matching(["Numark NS7 III"]))
    let d = try #require(p.definition)
    #expect(
        d.isValid && d.inputs.count == 12 && d.role == "accessory" && !p.selectsAutomatically
            && !p.hasAutomaticSplitOutput)
    #expect(d.outputs.isEmpty && d.startup.isEmpty && d.shutdown.isEmpty && d.audioOutput == nil)
    for name in ["Numark NS7III", "NS7III", "NS7 III"] { #expect(ControllerFactoryProfile.matching([name]) == p) }
    #expect(ControllerFactoryProfile.matching(["NS7III"], automaticOnly: true) == nil)
    for name in ["NS7", "NS7II", "NS7 II", "Numark NS7", "Numark NS7II"] {
        #expect(ControllerFactoryProfile.matching([name]) != p)
    }
    #expect(p.feedback(destination: 20).isEmpty)
    try withNS7IIIEQ { _ in }
}

@Test @MainActor func controllerCatalogueNS7IIIEQProbedPhysicalStripsKeepPickupAndFourDeckOptIn() throws {
    for decks in [DeckID.primary, DeckID.allCases] {
        try withNS7IIIEQ(decks: decks) { input in
            input.currentTargetValue = { _ in 0.5 }
            var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
            for (deck, base): (DeckID, UInt8) in [(.a, 9), (.b, 14), (.c, 20), (.d, 25)] {
                for (offset, action): (UInt8, ControllerAction) in [(0, .lowA), (1, .midA), (2, .highA)] {
                    events.removeAll(); let number = base + offset
                    ns7iiiEQPacket([0xB0, number, 0], input); #expect(events.isEmpty)
                    ns7iiiEQPacket([0xB0, number, 64], input); ns7iiiEQPacket([0xB0, number, 127], input)
                    #expect(events.count == (decks.contains(deck) ? 2 : 0))
                    #expect(events.allSatisfy { $0.0 == .init(action.assigned(to: deck), deck: deck) })
                    if decks.contains(deck) { #expect(events.map(\.1) == [64.0 / 127, 1]) }
                }
            }
        }
    }
}

@Test @MainActor func controllerCatalogueNS7IIIEQPickupDoesNotTransferBetweenSources() throws {
    try withNS7IIIEQ { input in
        input.currentTargetValue = { _ in 0.5 }
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        ns7iiiEQPacket([0xB0, 9, 64], input); ns7iiiEQPacket([0xB0, 9, 127], input)
        events.removeAll(); ns7iiiEQPacket([0xB0, 9, 0], input, source: 11); #expect(events.isEmpty)
        ns7iiiEQPacket([0xB0, 9, 0], input); #expect(events.map(\.1) == [0])
        events.removeAll(); ns7iiiEQPacket([0xB0, 9, 64], input, source: 11)
        #expect(events.map(\.0) == [.init(.lowA, deck: .a)] && events.map(\.1) == [64.0 / 127])
    }
}

@Test @MainActor func controllerCatalogueNS7IIIEQUnqualifiedModesLowBytesAndReportsStayInactive() throws {
    try withNS7IIIEQ { input in
        input.currentTargetValue = { _ in 0.5 }
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        let numbers: [UInt8] = [9, 10, 11, 14, 15, 16, 20, 21, 22, 25, 26, 27]
        for ch: UInt8 in 1..<16 { for n in numbers { ns7iiiEQPacket([0xB0 + ch, n, 0, n, 64, n, 127], input) } }
        for n: UInt8 in 0..<128 where !numbers.contains(n) { ns7iiiEQPacket([0xB0, n, 0, n, 64, n, 127], input) }
        for ch: UInt8 in 0..<16 {
            ns7iiiEQPacket(
                [0x90 + ch, 13, 127, 13, 0, 51, 127, 51, 0, 52, 127, 52, 0, 53, 127, 53, 0, 0xE0 + ch, 0, 64], input)
        }
        ns7iiiEQPacket([0xB0, 9, 64], input, source: 999)
        input.receive(.init(kind: .control, group: 1, channel: 0, number: 9, value: 64), source: 10);
        input.flushPendingActions()
        #expect(events.isEmpty)
    }
}
