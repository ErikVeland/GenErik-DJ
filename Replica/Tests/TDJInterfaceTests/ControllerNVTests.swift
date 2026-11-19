import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withNV(decks: [DeckID] = [.a, .b], _ body: (ControllerMIDIConnection) throws -> Void) throws {
    let suite = "nv-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences, factoryPacketSender: { _, _ in true }, deckAvailability: { decks })
    input.sources = [
        .init(id: 10, reference: 100, name: "Numark NV", identity: .init(id: 10, device: 1, names: ["Numark NV"]))
    ]
    input.reconcileFactoryProfiles()
    #expect(!input.isInputActive(10))
    input.select(10)
    input.applyFactoryProfile(try #require(ControllerFactoryProfile.matching(["Numark NV"])))
    try body(input)
}

@MainActor private func nvPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueNVStaysManualAndCannotClaimNVIIOrPrototypeSetup() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["Numark NV"]))
    #expect(!profile.selectsAutomatically && !profile.hasAutomaticSplitOutput)
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 79)
    #expect(data.outputs.isEmpty && data.startup.isEmpty && data.shutdown.isEmpty)
    #expect(
        !data.inputs.contains {
            $0.action.isJog || $0.action.hotcueSlot != nil || $0.action.isMomentary && $0.number == 93
        })
    for name in ["NVII", "Numark NVII", "NV2"] {
        #expect(ControllerFactoryProfile.matching([name]) != profile)
    }
}

@Test @MainActor func controllerCatalogueNVRequiresFourDeckOptInAndBlocksShiftedNormalPresses() throws {
    for decks: [DeckID] in [[.a, .b], DeckID.allCases] {
        try withNV(decks: decks) { input in
            var events: [ControllerActionTarget] = []
            input.onTargetAction = { target, _ in events.append(target) }
            nvPacket([0x91, 33, 127, 0x92, 33, 127, 0x93, 33, 127, 0x94, 33, 127], to: input)
            #expect(events.map(\.deck) == decks.map { Optional($0) })
            events.removeAll()
            nvPacket([0x91, 13, 127, 0x92, 32, 127, 31, 127, 5, 127], to: input)
            #expect(events.isEmpty)
            nvPacket([0x81, 13, 127, 0x92, 32, 0, 31, 0, 5, 0, 5, 127], to: input)
            #expect(events.map(\.action) == [.loadB])
        }
    }
}

@Test @MainActor func controllerCatalogueNVReleasesOriginalCueBendPlayAndLoadAcrossDeckBanks() throws {
    try withNV(decks: DeckID.allCases) { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        nvPacket(
            [0x91, 32, 127, 16, 127, 17, 127, 33, 127, 5, 127, 0x83, 32, 127, 16, 127, 17, 127, 33, 127, 5, 127],
            to: input)
        #expect(events.suffix(3).map(\.1) == [0, 0, 0])
        nvPacket([0x91, 33, 127, 5, 127], to: input)
        #expect(events.suffix(2).map { $0.0.action } == [.playA, .loadA])
        #expect(events.filter { $0.0.action == .playA && $0.0.deck == .a && $0.1 == 1 }.count == 2)
        #expect(events.filter { $0.0.action == .loadA && $0.0.deck == .a && $0.1 == 1 }.count == 2)
    }
}

@Test @MainActor func controllerCatalogueNVKeepsNormalMixerAndCoarsePitchAddresses() throws {
    try withNV { input in
        var events: [(ControllerAction, Double)] = []
        input.onAction = { events.append(($0, $1)) }
        nvPacket(
            [
                0xB0, 8, 127, 12, 127, 9, 127, 10, 127, 11, 127, 13, 127, 17, 127, 14, 127, 15, 127, 16, 127, 7, 127,
                68, 127, 18, 127,
            ], to: input)
        #expect(
            Set(events.map(\.0))
                == Set([
                    .levelA, .gainA, .lowA, .midA, .highA, .levelB, .gainB, .lowB, .midB, .highB, .crossfader, .monitor,
                    .cueMix,
                ]))
        nvPacket([0xB1, 1, 0], to: input)
        #expect(events.last?.0 == .tempoA && events.last?.1 == 1)
        nvPacket([0xB2, 1, 127], to: input)
        #expect(events.last?.0 == .tempoB && events.last?.1 == 0)
        events.removeAll()
        nvPacket([0x91, 93, 127, 26, 127, 14, 127, 15, 127, 3, 127, 0xB1, 0, 65, 0xB0, 100, 127], to: input)
        #expect(events.isEmpty)
    }
}
