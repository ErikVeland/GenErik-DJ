import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withDJ202(
    decks: [DeckID] = DeckID.allCases, _ body: (ControllerMIDIConnection) throws -> Void
) throws {
    let suite = "dj202-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { _, _ in
            Issue.record("Unexpected DJ-202 write"); return true
        }, deckAvailability: { decks }, factoryInputConnector: { _ in true })
    input.sources = [
        .init(id: 10, reference: 100, name: "DJ-202", identity: .init(id: 10, device: 1, names: ["DJ-202"])),
        .init(id: 11, reference: 101, name: "DJ-202", identity: .init(id: 11, device: 2, names: ["DJ-202"])),
    ]
    input.reconcileFactoryProfiles()
    #expect(!input.isInputActive(10))
    input.select(10)
    input.applyFactoryProfile(try #require(ControllerFactoryProfile.matching(["DJ-202"])))
    input.select(11)
    input.applyFactoryProfile(try #require(ControllerFactoryProfile.matching(["DJ-202"])))
    #expect(input.bindingCount == 220)
    try body(input)
}

@MainActor private func dj202Packet(_ bytes: [UInt8], to input: ControllerMIDIConnection, source: Int32 = 10) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: source) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueDJ202CueOwnershipStrictBrowserAndSeparatePickup() throws {
    try withDJ202 { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        for velocity: UInt8 in [1, 64, 127] {
            for off: UInt8 in [0x80, 0x90] {
                events.removeAll()
                dj202Packet([0x90, 1, velocity], to: input)
                dj202Packet([0x90, 1, 127], to: input, source: 11)
                dj202Packet([off + 2, 5, off == 0x80 ? 127 : 0], to: input)
                #expect(events.count == 1)
                dj202Packet([off, 1, off == 0x80 ? 127 : 0], to: input, source: 11)
                #expect(events.map(\.1) == [Double(velocity) / 127, 0])
            }
        }
        events.removeAll(); dj202Packet([0xBF, 0, 1], to: input)
        #expect(events.count == 1 && events.last?.0.action == .browse && events.last?.1 == 0.5 + 1.0 / 126)
        dj202Packet([0xBF, 0, 127], to: input)
        #expect(events.count == 2 && events.last?.1 == 0.5 - 1.0 / 126)
        events.removeAll(); dj202Packet([0xBF, 0, 2, 0, 126, 1, 1, 0x9F, 0, 127, 0xBF, 0, 1], to: input)
        #expect(events.isEmpty)
        dj202Packet([0x8F, 0, 127], to: input)
        input.currentTargetValue = { _ in 0.5 }
        dj202Packet([0xB0, 28, 0, 58, 0], to: input); #expect(events.isEmpty)
        dj202Packet([0xB0, 28, 64, 58, 0], to: input)
        #expect(events.last?.0.action == .levelA)
        let count = events.count
        dj202Packet([0xB0, 28, 0, 58, 0], to: input, source: 11); #expect(events.count == count)
        dj202Packet([0xB0, 28, 127, 58, 127], to: input); #expect(events.last?.1 == 1)
    }
}

@Test @MainActor func controllerCatalogueDJ202KeepsItsManualIdentityAndIncompleteLifecycleExplicit() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["Roland DJ-202"]))
    #expect(!profile.selectsAutomatically && !profile.hasAutomaticSplitOutput)
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 110 && data.outputs.isEmpty && data.startup.isEmpty && data.shutdown.isEmpty)
    #expect(!data.inputs.contains { $0.action.isJog || [.loadA, .loadB, .crossfader].contains($0.action) })
    for name in ["Roland DJ-505", "DJ-808", "USB MIDI"] {
        #expect(ControllerFactoryProfile.matching([name]) != profile)
    }
}

@Test @MainActor func controllerCatalogueDJ202AssemblesAllTwentyFourExplicitPairsAndKeepsDeckTargets() throws {
    try withDJ202 { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        let pairs: [(UInt8, UInt8, ControllerAction, ControllerAction)] = [
            (9, 59, .tempoA, .tempoB), (22, 52, .gainA, .gainB), (23, 53, .highA, .highB),
            (24, 54, .midA, .midB), (25, 55, .lowA, .lowB), (28, 58, .levelA, .levelB),
        ]
        for (side, deck) in DeckID.allCases.enumerated() {
            for (high, low, a, b) in pairs {
                for value: UInt8 in [0, 127] {
                    events.removeAll()
                    dj202Packet([0xB0 + UInt8(side), high, value, low, value], to: input)
                    #expect(events.last?.0 == .init(side % 2 == 0 ? a : b, deck: deck))
                    let normalised = Double(value) / 127
                    #expect(events.last?.1 == (high == 9 ? 1 - normalised : normalised))
                }
            }
        }
    }
}

@Test @MainActor func controllerCatalogueDJ202RequiresCDOptInAndGuardsShiftedTransportAndPitch() throws {
    for decks in [DeckID.primary, DeckID.allCases] {
        try withDJ202(decks: decks) { input in
            var events: [ControllerActionTarget] = []
            input.onTargetAction = { target, _ in events.append(target) }
            dj202Packet([0x90, 0, 127, 0x91, 0, 127, 0x92, 0, 127, 0x93, 0, 127], to: input)
            #expect(events.map(\.deck) == decks.map { Optional($0) })
            events.removeAll()
            dj202Packet([0x9F, 0, 127, 0x90, 4, 127, 5, 127, 3, 127, 14, 127, 1, 127], to: input)
            dj202Packet([0xB0, 9, 127, 59, 127], to: input)
            #expect(events.isEmpty)
        }
    }
}

@Test @MainActor func controllerCatalogueDJ202ShiftedOppositeBankReleasesPreserveCueAndPlayRearming() throws {
    try withDJ202 { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        dj202Packet([0x90, 1, 127, 0, 127, 0x9F, 0, 127, 0x92, 5, 0, 4, 0], to: input)
        #expect(events.map { $0.0.action } == [.cuePreviewA, .playA, .cuePreviewA])
        #expect(events.map(\.1) == [1, 1, 0])
        dj202Packet([0x8F, 0, 127, 0x90, 0, 127, 1, 127, 0x82, 5, 127], to: input)
        #expect(events.filter { $0.0.action == .playA && $0.1 == 1 }.count == 2)
        #expect(events.last?.0 == .init(.cuePreviewA, deck: .a) && events.last?.1 == 0)
    }
}

@Test @MainActor func controllerCatalogueDJ202UsesSeparateFilterPFLAndLoopRowsWithoutSharedPadsOrLoad() throws {
    try withDJ202 { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        for channel: UInt8 in 0..<4 {
            dj202Packet([0xB0 + channel, 26, 127, 0x90 + channel, 27, 127], to: input)
            dj202Packet([0x94 + channel, 21, 127, 22, 127, 24, 127], to: input)
        }
        #expect(events.count == 20)
        #expect(Set(events.compactMap(\.deck)) == Set(DeckID.allCases))
        #expect(
            Set(events.map(\.action))
                == Set([
                    .filterKnobA, .filterKnobB, .cueA, .cueB, .reloopA, .reloopB,
                    .loopInA, .loopInB, .loopOutA, .loopOutB,
                ]))
        events.removeAll()
        dj202Packet(
            [0x9F, 2, 127, 3, 127, 4, 127, 5, 127, 0xBF, 8, 127, 88, 127, 0xB0, 6, 65, 0x90, 6, 127], to: input)
        dj202Packet([0x94, 0, 127, 0x98, 0, 127, 0x9A, 0, 127, 0xB4, 22, 127], to: input)
        #expect(events.isEmpty)
    }
}
