import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withFour(decks: [DeckID] = DeckID.allCases, _ body: (ControllerMIDIConnection) throws -> Void)
    throws
{
    let suite = "four-manual-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences, factoryPacketSender: { _, _ in true }, deckAvailability: { decks })
    let name = "RANE FOUR Control"
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    #expect(!input.isInputActive(10))
    input.select(10)
    input.applyFactoryProfile(try #require(ControllerFactoryProfile.matching([name])))
    try body(input)
}

@MainActor private func fourPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueRaneFourIsManualAndExcludesDisplayEndpointsAndHardwareMixer() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["RANE FOUR Control"]))
    #expect(ControllerFactoryProfile.matching(["RANE FOUR"], automaticOnly: true) == nil)
    #expect(ControllerFactoryProfile.matching(["RANE FOUR", "RANE FOUR LCD Left"]) == nil)
    #expect(ControllerFactoryProfile.matching(["RANE FOUR", "RANE FOUR LCD Right"]) == nil)
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 108 && data.outputs.count == 16)
    #expect(data.startup.isEmpty && !profile.hasAutomaticSplitOutput)
    #expect(
        !data.inputs.contains {
            $0.action.isJog || $0.action.hotcueSlot != nil || $0.kind == .pitch || $0.action == .crossfader
        })
    let cue = try #require(profile.feedback(destination: 20).first { $0.action == .cuePreviewA && $0.targetDeck == .c })
    #expect(cue.message(value: 1) == [0x92, 1, 127])
    #expect(cue.message(value: 0) == [0x92, 1, 1])
}

@Test @MainActor func controllerCatalogueRaneFourKeepsTransportTargetsAndHiddenDeckIsolation() throws {
    try withFour { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        for channel: UInt8 in 0...3 { fourPacket([0x90 + channel, 0, 127, 2, 127, 6, 127], to: input) }
        #expect(events.compactMap(\.deck) == [.a, .a, .a, .b, .b, .b, .c, .c, .c, .d, .d, .d])
    }
    try withFour(decks: DeckID.primary) { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        fourPacket([0x92, 0, 127, 6, 127, 0x93, 0, 127, 6, 127], to: input)
        #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueRaneFourReleasesCueAndBendAcrossShiftAndDeckBank() throws {
    try withFour { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        fourPacket([0x90, 1, 127, 11, 127, 0x92, 5, 127, 0x82, 5, 127, 11, 127], to: input)
        #expect(events.map { $0.0.action } == [.cuePreviewA, .pitchBendUpA, .cuePreviewA, .pitchBendUpA])
        #expect(events.map(\.1) == [1, 1, 0, 0])
        events.removeAll()
        fourPacket([0x93, 1, 127, 12, 127, 0x91, 1, 0, 12, 0], to: input)
        #expect(events.map { $0.0.deck } == [.d, .d, .d, .d])
        #expect(events.map(\.1) == [1, 1, 0, 0])
        events.removeAll()
        fourPacket([0x90, 0, 127, 0x92, 0, 0, 0x90, 0, 127], to: input)
        #expect(events.map { $0.0.action } == [.playA, .playA])
    }
}

@Test @MainActor func controllerCatalogueRaneFourPairsPitchAndKeepsClocksPadsAndMixingInactive() throws {
    try withFour { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        fourPacket([0xB2, 9, 64, 41, 0], to: input)
        #expect(events.last?.0 == .init(.tempoA, deck: .c))
        #expect(abs((events.last?.1 ?? 0) - 0.5) < 0.0001)
        fourPacket([0xB3, 0, 65], to: input)
        #expect(events.last?.0.action == .browse && events.last?.1 == 0.5 + 1.0 / 126)
        let count = events.count
        fourPacket(
            [0xE0, 0, 64, 0xB0, 6, 70, 22, 127, 28, 127, 23, 127, 0xBF, 8, 127, 0x94, 20, 127, 0x90, 80, 127], to: input
        )
        #expect(events.count == count)
        events.removeAll()
        fourPacket([0x94, 52, 127, 53, 127, 54, 127, 55, 127, 63, 127, 65, 127], to: input)
        #expect(events.map { $0.0.action } == [.loopDownA, .loopUpA, .loopInA, .loopOutA, .loopA, .reloopA])
    }
}
