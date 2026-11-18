import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withReloopTouch(
    decks: [DeckID] = [.a, .b], _ body: (ControllerMIDIConnection) throws -> Void
) throws {
    let suite = "reloop-touch-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences, factoryPacketSender: { _, _ in true }, deckAvailability: { decks })
    input.sources = [
        .init(id: 10, reference: 100, name: "Reloop TOUCH", identity: .init(id: 10, device: 1, names: ["Reloop TOUCH"]))
    ]
    input.reconcileFactoryProfiles()
    #expect(!input.isInputActive(10))
    input.select(10)
    input.applyFactoryProfile(try #require(ControllerFactoryProfile.matching(["Reloop TOUCH"])))
    input.enabled = true
    try body(input)
}

@MainActor private func reloopTouchPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueReloopTouchStaysManualWithoutScreenOrPadSetup() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["Reloop TOUCH"]))
    #expect(!profile.selectsAutomatically && !profile.hasAutomaticSplitOutput)
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 126 && data.outputs.count == 16)
    #expect(data.startup.isEmpty && data.shutdown.isEmpty && data.inputModes == nil)
    #expect(!data.inputs.contains { $0.action.hotcueSlot != nil || $0.number == 127 })
    let lamp = try #require(
        profile.feedback(destination: 20).first { $0.action == .cuePreviewA && $0.targetDeck == .c })
    #expect(lamp.message(value: 1) == [0x93, 35, 127])
    #expect(lamp.message(value: 0) == [0x93, 35, 0])
}

@Test @MainActor func controllerCatalogueReloopTouchKeepsFourDeckOptInAndGlobalChannel() throws {
    for decks: [DeckID] in [[.a, .b], DeckID.allCases] {
        try withReloopTouch(decks: decks) { input in
            var events: [ControllerActionTarget] = []
            input.onTargetAction = { target, _ in events.append(target) }
            reloopTouchPacket([0x91, 36, 127, 0x92, 36, 127, 0x93, 36, 127, 0x94, 36, 127], to: input)
            #expect(events.map(\.deck) == decks.map { Optional($0) })
            events.removeAll()
            reloopTouchPacket([0x95, 8, 127, 9, 127, 0x90, 36, 127, 0x95, 36, 127], to: input)
            #expect(events.map(\.action) == [.openGroup, .openGroup])
        }
    }
}

@Test @MainActor func controllerCatalogueReloopTouchShiftAndBankReleasesKeepOriginalOwners() throws {
    try withReloopTouch(decks: DeckID.allCases) { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        reloopTouchPacket([0x91, 35, 127, 63, 127, 38, 127, 39, 127, 0x93, 99, 127, 102, 127, 103, 127], to: input)
        #expect(events.map { $0.0.deck } == [.a, .a, .a, .a])
        reloopTouchPacket([0x83, 99, 127, 63, 127, 102, 127, 103, 127], to: input)
        #expect(events.suffix(4).map { $0.0.deck } == [.a, .a, .a, .a])
        #expect(events.suffix(4).map(\.1) == [0, 0, 0, 0])
        reloopTouchPacket([0x91, 35, 127, 35, 0], to: input)
        #expect(events.suffix(2).map(\.1) == [1, 0])
    }
}

@Test @MainActor func controllerCatalogueReloopTouchKeepsNormalSourceMixerPitchAndJogAddresses() throws {
    try withReloopTouch { input in
        var events: [(ControllerAction, Double)] = []
        var jogs: [ControllerMIDIValue] = []
        input.onAction = { events.append(($0, $1)) }
        input.onJogAction = { _, value in jogs.append(value) }
        reloopTouchPacket([0xB1, 16, 127, 17, 127, 18, 127, 19, 127, 20, 127, 50, 127], to: input)
        #expect(Set(events.map(\.0)) == Set([.gainA, .highA, .lowA, .filterKnobA, .levelA, .midA]))
        reloopTouchPacket([0xE1, 0, 0], to: input)
        #expect(events.last?.0 == .tempoA && events.last?.1 == 0)
        reloopTouchPacket([0xE2, 127, 127], to: input)
        #expect(events.last?.0 == .tempoB && events.last?.1 == 1)
        reloopTouchPacket([0xB1, 96, 63], to: input)
        reloopTouchPacket([0xB2, 96, 65], to: input)
        #expect(jogs == [.relative(-1), .relative(1)])
        reloopTouchPacket([0xB5, 96, 65], to: input)
        #expect(events.last?.0 == .browse && events.last?.1 == 0.5 + 1.0 / 126)
        events.removeAll()
        reloopTouchPacket([0x91, 0, 127, 41, 127, 42, 127, 100, 127, 0xB1, 112, 65], to: input)
        #expect(events.isEmpty)
    }
}
