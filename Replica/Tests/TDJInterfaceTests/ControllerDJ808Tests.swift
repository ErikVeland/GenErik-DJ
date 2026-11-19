import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withDJ808(
    decks: [DeckID] = DeckID.allCases, _ body: (ControllerMIDIConnection) throws -> Void
) throws {
    let suite = "dj808-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { _, _ in
            Issue.record("Manual DJ-808 must not send setup or keepalive."); return false
        }, deckAvailability: { decks }, factoryInputConnector: { _ in true })
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id), name: "DJ-808",
            identity: .init(id: id, device: UInt32(id), names: ["DJ-808"]))
    }
    input.reconcileFactoryProfiles(); #expect(!input.isInputActive(10) && !input.isInputActive(11))
    let p = try #require(ControllerFactoryProfile.matching(["DJ-808"]))
    for source: Int32 in [10, 11] { input.select(source); input.applyFactoryProfile(p) }
    #expect(input.bindingCount == 226)
    try body(input)
}

@MainActor private func dj808Packet(_ bytes: [UInt8], to input: ControllerMIDIConnection, source: Int32 = 10) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: source) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueDJ808KeepsItsManualIdentityAndIncompleteLifecycleExplicit() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["Roland DJ-808"]))
    #expect(!profile.selectsAutomatically && !profile.hasAutomaticSplitOutput)
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 113 && data.outputs.isEmpty && data.startup.isEmpty && data.shutdown.isEmpty)
    #expect(!data.inputs.contains { $0.action.isJog || [.loadA, .loadB, .crossfader].contains($0.action) })
    for name in ["Roland DJ-202", "DJ-505", "DJ-707M", "USB MIDI"] {
        #expect(ControllerFactoryProfile.matching([name]) != profile)
    }
}

@Test @MainActor func controllerCatalogueDJ808AssemblesAllTwentyExplicitPairsAndKeepsDeckTargets() throws {
    try withDJ808 { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        let pairs: [(UInt8, UInt8, ControllerAction, ControllerAction)] = [
            (22, 52, .gainA, .gainB), (23, 53, .highA, .highB),
            (24, 54, .midA, .midB), (25, 55, .lowA, .lowB), (28, 58, .levelA, .levelB),
        ]
        for (side, deck) in DeckID.allCases.enumerated() {
            for (high, low, a, b) in pairs {
                for value: UInt8 in [0, 127] {
                    events.removeAll()
                    dj808Packet([0xB0 + UInt8(side), high, value, low, value], to: input)
                    #expect(events.last?.0 == .init(side % 2 == 0 ? a : b, deck: deck))
                    let normalised = Double(value) / 127
                    #expect(events.last?.1 == (high == 9 ? 1 - normalised : normalised))
                }
            }
        }
    }
}

@Test @MainActor func controllerCatalogueDJ808RequiresCDOptInAndGuardsShiftedTransportAndPitch() throws {
    for decks in [DeckID.primary, DeckID.allCases] {
        try withDJ808(decks: decks) { input in
            var events: [ControllerActionTarget] = []
            input.onTargetAction = { target, _ in events.append(target) }
            dj808Packet([0x90, 0, 127, 0x91, 0, 127, 0x92, 0, 127, 0x93, 0, 127], to: input)
            #expect(events.map(\.deck) == decks.map { Optional($0) })
            events.removeAll()
            dj808Packet([0x9F, 0, 127, 0x90, 4, 127, 5, 127, 3, 127, 14, 127, 1, 127], to: input)
            dj808Packet([0xB0, 9, 127, 59, 127], to: input)
            #expect(events.isEmpty)
        }
    }
}

@Test @MainActor func controllerCatalogueDJ808ShiftedOppositeBankReleasesPreserveCueAndPlayRearming() throws {
    try withDJ808 { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        dj808Packet([0x90, 1, 127, 0, 127, 0x9F, 0, 127, 0x92, 5, 0, 4, 0], to: input)
        #expect(events.map { $0.0.action } == [.cuePreviewA, .playA, .cuePreviewA])
        #expect(events.map(\.1) == [1, 1, 0])
        dj808Packet([0x8F, 0, 127, 0x90, 0, 127, 1, 127, 0x82, 5, 127], to: input)
        #expect(events.filter { $0.0.action == .playA && $0.1 == 1 }.count == 2)
        #expect(events.last?.0 == .init(.cuePreviewA, deck: .a) && events.last?.1 == 0)
    }
}

@Test @MainActor func controllerCatalogueDJ808UsesSeparateFilterPFLAndLoopRowsWithoutSharedPadsOrLoad() throws {
    try withDJ808 { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        for channel: UInt8 in 0..<4 {
            dj808Packet([0xB0 + channel, 26, 127, 0x90 + channel, 27, 127], to: input)
            dj808Packet([0x94 + channel, 51, 127, 52, 127, 53, 127, 56, 127, 57, 127], to: input)
        }
        #expect(events.count == 28)
        #expect(Set(events.compactMap(\.deck)) == Set(DeckID.allCases))
        #expect(
            Set(events.map(\.action))
                == Set([
                    .filterKnobA, .filterKnobB, .cueA, .cueB, .reloopA, .reloopB,
                    .loopDownA, .loopDownB, .loopUpA, .loopUpB, .loopInA, .loopInB, .loopOutA, .loopOutB,
                ]))
        events.removeAll()
        dj808Packet(
            [0x9F, 2, 127, 3, 127, 4, 127, 5, 127, 0xBF, 8, 127, 88, 127, 0xB0, 6, 65, 0x90, 6, 127], to: input)
        dj808Packet([0x94, 0, 127, 0x98, 0, 127, 0x9A, 0, 127, 0xB4, 22, 127], to: input)
        #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueDJ808HeldCueKeepsAllVelocitiesAndBothOppositeReleaseForms() throws {
    try withDJ808 { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        for (i, deck) in DeckID.allCases.enumerated() {
            let ch = UInt8(i)
            for velocity: UInt8 in [1, 64, 127] {
                for off: UInt8 in [0x80, 0x90] {
                    events.removeAll();
                    dj808Packet(
                        [0x90 + ch, 1, velocity, 1, 127, off + (ch + 2) % 4, 5, off == 0x80 ? 127 : 0], to: input)
                    #expect(events.map(\.1) == [Double(velocity) / 127, 0])
                    #expect(
                        events.allSatisfy { $0.0 == .init(ControllerAction.cuePreviewA.assigned(to: deck), deck: deck) }
                    )
                }
            }
        }
    }
}

@Test @MainActor func controllerCatalogueDJ808PairPickupDoesNotTransferAcrossSources() throws {
    try withDJ808 { input in
        input.currentTargetValue = { _ in 0.5 }
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        dj808Packet([0xB0, 28, 0, 58, 0], to: input); #expect(events.isEmpty)
        dj808Packet([0xB0, 28, 64, 58, 0], to: input); dj808Packet([0xB0, 28, 127, 58, 127], to: input)
        #expect(events.last?.0 == .init(.levelA, deck: .a) && events.last?.1 == 1)
        events.removeAll(); dj808Packet([0xB0, 28, 0, 58, 0], to: input, source: 11); #expect(events.isEmpty)
        dj808Packet([0xB0, 28, 0, 58, 0], to: input); #expect(events.last?.1 == 0)
        events.removeAll(); dj808Packet([0xB0, 28, 64, 58, 0], to: input, source: 11)
        #expect(events.last?.0 == .init(.levelA, deck: .a))
    }
}

@Test @MainActor func controllerCatalogueDJ808SelectorsRetireOnlyOwnedSideHolds() throws {
    try withDJ808 { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        dj808Packet([0x90, 1, 127, 0x91, 1, 127], to: input); dj808Packet([0x90, 1, 127], to: input, source: 11)
        events.removeAll(); dj808Packet([0x90, 8, 1, 8, 0], to: input); #expect(events.isEmpty)
        dj808Packet([0x80, 1, 0], to: input); #expect(events.isEmpty)
        dj808Packet([0x80, 1, 0], to: input, source: 11)
        #expect(events.map(\.0) == [.init(.cuePreviewA, deck: .a)] && events.map(\.1) == [0])
        events.removeAll(); dj808Packet([0x81, 1, 127], to: input)
        #expect(events.map(\.0) == [.init(.cuePreviewB, deck: .b)] && events.map(\.1) == [0])
        events.removeAll(); dj808Packet([0x92, 1, 127, 1, 0], to: input)
        #expect(events.map(\.0) == Array(repeating: .init(.cuePreviewA, deck: .c), count: 2))
    }
}
