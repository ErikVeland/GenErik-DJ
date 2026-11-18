import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withMixon8(decks: [DeckID] = DeckID.allCases, _ body: (ControllerMIDIConnection) throws -> Void)
    throws
{
    let suite = "mixon8-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences, factoryPacketSender: { _, _ in true }, deckAvailability: { decks })
    let name = "Reloop Mixon 8 Pro"
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    #expect(!input.isInputActive(10))
    input.select(10)
    input.applyFactoryProfile(try #require(ControllerFactoryProfile.matching([name])))
    try body(input)
}

@MainActor private func mixon8Packet(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueMixon8KeepsManualIdentityAndNoUnqualifiedOutput() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["Reloop Mixon 8 Pro"]))
    #expect(!profile.selectsAutomatically && !profile.hasAutomaticSplitOutput)
    #expect(profile != ControllerFactoryProfile.matching(["Mixon 4"]))
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 83)
    #expect(data.outputs.isEmpty && data.startup.isEmpty && data.shutdown.isEmpty)
    #expect(data.inputModes == nil)
    #expect(!data.inputs.contains { $0.action.isJog || $0.action.hotcueSlot != nil || $0.kind == .pitch })
}

@Test @MainActor func controllerCatalogueMixon8KeepsFourTransportTargetsAndOptInHiddenDecks() throws {
    try withMixon8 { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        for channel: UInt8 in 0...3 { mixon8Packet([0x90 + channel, 0, 127, 2, 127], to: input) }
        mixon8Packet([0x9E, 2, 127, 3, 127, 4, 127, 5, 127], to: input)
        #expect(events.map(\.deck) == [.a, .a, .b, .b, .c, .c, .d, .d, .a, .b, .c, .d])
    }
    try withMixon8(decks: DeckID.primary) { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        mixon8Packet([0x92, 0, 127, 0x93, 0, 127, 0x9E, 4, 127, 5, 127], to: input)
        #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueMixon8CueReleasesAcrossShiftAndBankWithoutShiftedPress() throws {
    try withMixon8 { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        mixon8Packet([0x90, 1, 127, 0x92, 5, 127, 0x82, 5, 127], to: input)
        #expect(events.map { $0.0.action } == [.cuePreviewA, .cuePreviewA])
        #expect(events.map { $0.0.deck } == [.a, .a] && events.map(\.1) == [1, 0])
        events.removeAll()
        mixon8Packet([0x93, 1, 127, 0x91, 1, 0], to: input)
        #expect(events.map { $0.0.deck } == [.d, .d] && events.map(\.1) == [1, 0])
        events.removeAll()
        mixon8Packet([0x90, 4, 127, 5, 127, 3, 127], to: input)
        #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueMixon8KeepsNormalLoopGainFilterAndFlippedBrowserOnly() throws {
    try withMixon8 { input in
        var events: [(ControllerAction, Double)] = []
        input.onAction = { events.append(($0, $1)) }
        mixon8Packet([0xB0, 22, 127, 26, 127, 0x94, 50, 127, 52, 127, 53, 127, 56, 127, 57, 127], to: input)
        #expect(Set(events.map(\.0)) == Set([.gainA, .filterKnobA, .loopA, .loopDownA, .loopUpA, .loopInA, .loopOutA]))
        events.removeAll()
        mixon8Packet([0xBE, 0, 65], to: input)
        #expect(events.last?.0 == .browse && events.last?.1 == 0.5 - 1.0 / 126)
        events.removeAll()
        mixon8Packet(
            [0xE0, 0, 64, 0xB0, 6, 65, 23, 127, 24, 127, 25, 127, 28, 127, 0x94, 20, 127, 0x9E, 50, 127], to: input)
        #expect(events.isEmpty)
    }
}
