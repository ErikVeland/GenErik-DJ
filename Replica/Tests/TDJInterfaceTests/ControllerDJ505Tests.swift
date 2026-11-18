import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withDJ505(
    decks: [DeckID] = DeckID.allCases, _ body: (ControllerMIDIConnection) throws -> Void
) throws {
    let suite = "dj505-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences, factoryPacketSender: { _, _ in true }, deckAvailability: { decks })
    input.sources = [
        .init(id: 10, reference: 100, name: "DJ-505", identity: .init(id: 10, device: 1, names: ["DJ-505"]))
    ]
    input.reconcileFactoryProfiles()
    #expect(!input.isInputActive(10))
    input.select(10)
    input.applyFactoryProfile(try #require(ControllerFactoryProfile.matching(["DJ-505"])))
    try body(input)
}

@MainActor private func dj505Packet(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueDJ505KeepsItsManualIdentityAndIncompleteLifecycleExplicit() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["Roland DJ-505"]))
    #expect(!profile.selectsAutomatically && !profile.hasAutomaticSplitOutput)
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 117 && data.outputs.isEmpty && data.startup.isEmpty && data.shutdown.isEmpty)
    #expect(!data.inputs.contains { $0.action.isJog || [.loadA, .loadB, .crossfader].contains($0.action) })
    for name in ["Roland DJ-202", "DJ-808", "USB MIDI"] {
        #expect(ControllerFactoryProfile.matching([name]) != profile)
    }
}

@Test @MainActor func controllerCatalogueDJ505AssemblesAllTwentyFourExplicitPairsAndKeepsDeckTargets() throws {
    try withDJ505 { input in
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
                    dj505Packet([0xB0 + UInt8(side), high, value, low, value], to: input)
                    #expect(events.last?.0 == .init(side % 2 == 0 ? a : b, deck: deck))
                    let normalised = Double(value) / 127
                    #expect(events.last?.1 == (high == 9 ? 1 - normalised : normalised))
                }
            }
        }
    }
}

@Test @MainActor func controllerCatalogueDJ505RequiresCDOptInAndGuardsShiftedTransportAndPitch() throws {
    for decks in [DeckID.primary, DeckID.allCases] {
        try withDJ505(decks: decks) { input in
            var events: [ControllerActionTarget] = []
            input.onTargetAction = { target, _ in events.append(target) }
            dj505Packet([0x90, 0, 127, 0x91, 0, 127, 0x92, 0, 127, 0x93, 0, 127], to: input)
            #expect(events.map(\.deck) == decks.map { Optional($0) })
            events.removeAll()
            dj505Packet([0x9F, 0, 127, 0x90, 4, 127, 5, 127, 3, 127, 14, 127, 1, 127], to: input)
            dj505Packet([0xB0, 9, 127, 59, 127], to: input)
            #expect(events.isEmpty)
        }
    }
}

@Test @MainActor func controllerCatalogueDJ505ShiftedOppositeBankReleasesPreserveCueAndPlayRearming() throws {
    try withDJ505 { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        dj505Packet([0x90, 1, 127, 0, 127, 0x9F, 0, 127, 0x92, 5, 0, 4, 0], to: input)
        #expect(events.map { $0.0.action } == [.cuePreviewA, .playA, .cuePreviewA])
        #expect(events.map(\.1) == [1, 1, 0])
        dj505Packet([0x8F, 0, 127, 0x90, 0, 127, 1, 127, 0x82, 5, 127], to: input)
        #expect(events.filter { $0.0.action == .playA && $0.1 == 1 }.count == 2)
        #expect(events.last?.0 == .init(.cuePreviewA, deck: .a) && events.last?.1 == 0)
    }
}

@Test @MainActor func controllerCatalogueDJ505UsesSeparateFilterPFLAndLoopRowsWithoutSharedPadsOrLoad() throws {
    try withDJ505 { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        for channel: UInt8 in 0..<4 {
            dj505Packet([0xB0 + channel, 26, 127, 0x90 + channel, 27, 127], to: input)
            dj505Packet([0x94 + channel, 51, 127, 52, 127, 53, 127, 56, 127, 57, 127], to: input)
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
        dj505Packet(
            [0x9F, 2, 127, 3, 127, 4, 127, 5, 127, 0xBF, 8, 127, 88, 127, 0xB0, 6, 65, 0x90, 6, 127], to: input)
        dj505Packet([0x94, 0, 127, 0x98, 0, 127, 0x9A, 0, 127, 0xB4, 22, 127], to: input)
        #expect(events.isEmpty)
    }
}
