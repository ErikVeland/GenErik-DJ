import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withMCX8000(
    decks: [DeckID] = DeckID.allCases, _ body: (ControllerMIDIConnection) throws -> Void
) throws {
    let suite = "mcx8000-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences, factoryPacketSender: { _, _ in true }, deckAvailability: { decks })
    let name = "Denon DJ MCX8000"
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    #expect(!input.isInputActive(10))
    input.select(10)
    input.applyFactoryProfile(try #require(ControllerFactoryProfile.matching([name])))
    try body(input)
}

@MainActor private func mcx8000Packet(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test func controllerCatalogueMCX8000ManualSubsetHasNoInventedEncoderPadOrAudioProtocol() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["MCX8000"]))
    #expect(ControllerFactoryProfile.matching(["MCX8000"], automaticOnly: true) == nil)
    #expect(ControllerFactoryProfile.matching(["MC7000"]) != profile)
    #expect(!profile.hasAutomaticSplitOutput)
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 99 && data.outputs.count == 24)
    #expect(data.startup.count == 24 && data.shutdown.count == 24)
    #expect(
        !data.inputs.contains {
            $0.action.isJog || $0.action.hotcueSlot != nil || [.tempoA, .tempoB, .shift].contains($0.action)
        })
    #expect(data.outputs.allSatisfy { $0.onValue == 127 && $0.offValue == 0 })
}

@Test @MainActor func controllerCatalogueMCX8000FourLoadTargetsAndUnavailableDecksStayIsolated() throws {
    try withMCX8000 { input in
        var targets: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in targets.append(target) }
        mcx8000Packet([0x9F, 2, 127, 3, 127, 4, 127, 5, 127], to: input)
        #expect(targets.map(\.deck) == [.a, .b, .c, .d])
        #expect(targets.map(\.action) == [.loadA, .loadB, .loadA, .loadB])
    }
    try withMCX8000(decks: [.a, .b]) { input in
        var targets: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in targets.append(target) }
        mcx8000Packet([0x92, 0, 127, 0x93, 0, 127, 0x9F, 4, 127, 5, 127], to: input)
        #expect(targets.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueMCX8000CueAndBendAliasesOnlyReleaseTheirOwnedDeck() throws {
    try withMCX8000 { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        mcx8000Packet([0x90, 1, 127, 11, 127, 0x92, 1, 127, 12, 127], to: input)
        mcx8000Packet([0x90, 5, 127, 43, 127, 0x92, 5, 127, 44, 127], to: input)
        #expect(events.count == 4)
        mcx8000Packet([0x90, 5, 0, 0x80, 43, 127], to: input)
        #expect(events.suffix(2).map { $0.0.deck } == [.a, .a])
        #expect(events.suffix(2).allSatisfy { $0.1 == 0 })
        mcx8000Packet([0x82, 5, 127, 44, 0], to: input)
        #expect(events.suffix(2).map { $0.0.deck } == [.c, .c])
        #expect(events.suffix(2).allSatisfy { $0.1 == 0 })
    }
}

@Test @MainActor func controllerCatalogueMCX8000FactoryLoopChannelsAndMixerAddressesStayDistinct() throws {
    try withMCX8000 { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        mcx8000Packet([0x94, 50, 127, 52, 127, 53, 127, 51, 127, 56, 127, 57, 127, 0x97, 50, 127], to: input)
        #expect(events.map { $0.0.action } == [.loopA, .loopDownA, .loopUpA, .reloopA, .loopInA, .loopOutA, .loopB])
        #expect(events.last?.0.deck == .d)
        events.removeAll()
        mcx8000Packet([0xB2, 22, 127, 23, 0, 24, 127, 25, 0, 26, 127, 28, 127, 0xBF, 8, 0], to: input)
        #expect(Set(events.map { $0.0.action }) == [.gainA, .highA, .midA, .lowA, .filterKnobA, .levelA, .crossfader])
        #expect(events.filter { $0.0.action != .crossfader }.allSatisfy { $0.0.deck == .c })
    }
}

@Test @MainActor func controllerCatalogueMCX8000UnknownModesWheelsAndForeignSourcesStayInactive() throws {
    try withMCX8000 { input in
        var targets: [ControllerActionTarget] = []
        var jogs = 0
        input.onTargetAction = { target, _ in targets.append(target) }
        input.onJogAction = { _, _ in jogs += 1 }
        mcx8000Packet([0xB0, 6, 65, 9, 127, 119, 127, 0xBF, 0, 1, 68, 127, 0x94, 0, 127, 20, 127, 28, 127], to: input)
        input.receive(.init(kind: .note, group: 1, channel: 0, number: 0, value: 127), source: 10)
        input.receive(.init(kind: .note, channel: 0, number: 0, value: 127), source: 11)
        input.flushPendingActions()
        #expect(targets.isEmpty && jogs == 0)
    }
}
