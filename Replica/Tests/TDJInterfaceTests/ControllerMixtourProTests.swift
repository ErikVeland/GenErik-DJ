import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withMixtourPro(
    _ decks: [DeckID] = DeckID.allCases, _ body: (ControllerMIDIConnection) throws -> Void
) throws {
    let suite = "mixtour-pro-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences, factoryPacketSender: { _, _ in true }, deckAvailability: { decks })
    let name = "Reloop Mixtour Pro"
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    #expect(!input.isInputActive(10))
    input.select(10)
    input.applyFactoryProfile(try #require(ControllerFactoryProfile.matching([name])))
    try body(input)
}

@MainActor private func mixtourProPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueMixtourProStaysManualAndUsesOnlyReviewedNormalControls() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["Mixtour Pro"]))
    #expect(profile.rawValue == "Reloop Mixtour Pro")
    #expect(ControllerFactoryProfile.matching(["Mixtour Pro"], automaticOnly: true) == nil)
    #expect(profile != ControllerFactoryProfile.matching(["Mixtour"], automaticOnly: true))
    #expect(!profile.hasAutomaticSplitOutput)
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 47 && data.outputs.count == 12)
    #expect(data.startup.isEmpty && data.shutdown.count == 12)
    #expect(
        !data.inputs.contains {
            $0.action.isJog || $0.action.hotcueSlot != nil || [.tempoA, .tempoB, .master, .monitor].contains($0.action)
        })
    let play = try #require(profile.feedback(destination: 20).first { $0.action == .playA && $0.targetDeck == .c })
    #expect(play.message(value: 1) == [0x92, 0, 5])
    #expect(play.message(value: 0) == [0x92, 0, 1])
}

@Test @MainActor func controllerCatalogueMixtourProLoadAndTransportKeepAllFourWireTargets() throws {
    try withMixtourPro { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        for channel: UInt8 in 4...7 { mixtourProPacket([0x90 + channel, 10, 127], to: input) }
        #expect(events.compactMap(\.deck) == DeckID.allCases)
        #expect(events.map(\.action) == [.loadA, .loadB, .loadA, .loadB])
        events.removeAll()
        for channel: UInt8 in 0...3 { mixtourProPacket([0x90 + channel, 0, 127, 2, 127, 27, 127], to: input) }
        #expect(events.count == 12)
        #expect(events.filter { $0.action == .playA || $0.action == .playB }.compactMap(\.deck) == DeckID.allCases)
    }
    try withMixtourPro(DeckID.primary) { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        mixtourProPacket([0x92, 0, 127, 0x93, 0, 127, 0x96, 10, 127, 0x97, 10, 127], to: input)
        #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueMixtourProCueAcceptsBothReleaseFormsAndDuplicatePressesDoNotRetrigger() throws
{
    try withMixtourPro { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        mixtourProPacket([0x90, 1, 127, 1, 127, 0x92, 1, 127, 0x80, 1, 127, 0x92, 1, 0], to: input)
        #expect(events.map { $0.0.deck } == [.a, .c, .a, .c])
        #expect(events.map(\.1) == [1, 1, 0, 0])
    }
}

@Test @MainActor func controllerCatalogueMixtourProMixerPickupAndInvertedBrowseUseOwnAddresses() throws {
    try withMixtourPro { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        input.currentTargetValue = { $0.action == .highA && $0.deck == .c ? 0.5 : nil }
        mixtourProPacket([0xB2, 23, 127], to: input)
        #expect(events.isEmpty)
        mixtourProPacket([0xB2, 23, 64, 0xBF, 0, 65], to: input)
        #expect(events.contains { $0.0 == .init(.highA, deck: .c) && $0.1 == 0.5 })
        #expect(events.contains { $0.0.action == .browse && $0.1 == 0.5 - 1.0 / 126 })
        mixtourProPacket([0xBF, 0, 63, 13, 127, 8, 0], to: input)
        #expect(events.contains { $0.0.action == .browse && $0.1 == 0.5 + 1.0 / 126 })
        #expect(events.contains { $0.0.action == .cueMix && $0.1 == 1 })
        #expect(events.contains { $0.0.action == .crossfader && $0.1 == 0 })
    }
}

@Test @MainActor func controllerCatalogueMixtourProSharedPadsAndUnqualifiedLoopOrModeControlsStayInactive() throws {
    try withMixtourPro { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        mixtourProPacket([0x94, 20, 127, 21, 127, 28, 127, 0x90, 3, 127, 16, 127, 18, 127, 0xBF, 2, 65], to: input)
        input.receive(.init(kind: .note, group: 1, channel: 0, number: 0, value: 127), source: 10)
        input.receive(.init(kind: .note, channel: 0, number: 0, value: 127), source: 11)
        input.flushPendingActions()
        #expect(events.isEmpty)
    }
}
