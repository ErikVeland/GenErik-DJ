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
    #expect(input.isInputActive(10))
    try body(input)
}

@MainActor private func mcx8000Packet(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test func controllerCatalogueMCX8000CoreKeepsPadsHighResolutionAndAudioOpen() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["MCX8000"]))
    #expect(ControllerFactoryProfile.matching(["MCX8000"], automaticOnly: true) != nil)
    #expect(ControllerFactoryProfile.matching(["MC7000"]) != profile)
    #expect(!profile.hasAutomaticSplitOutput)
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 121 && data.outputs.count == 24)
    #expect(data.startup.count == 30 && data.shutdown.count == 28)
    #expect(
        !data.inputs.contains {
            $0.action.hotcueSlot != nil || $0.action == .shift || $0.encoding == .paired14Bit
        })
    #expect(
        data.outputs.allSatisfy { $0.onValue == 127 && $0.offValue == ([.cueA, .cueB].contains($0.action) ? 0 : 1) })
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

@Test @MainActor func controllerCatalogueMCX8000UnknownPadsLowPitchBytesAndForeignSourcesStayInactive() throws {
    try withMCX8000 { input in
        var targets: [ControllerActionTarget] = []
        var jogs = 0
        input.onTargetAction = { target, _ in targets.append(target) }
        input.onJogAction = { _, _ in jogs += 1 }
        mcx8000Packet([0xB0, 119, 127, 0x94, 0, 127, 20, 127, 28, 127], to: input)
        input.receive(.init(kind: .note, group: 1, channel: 0, number: 0, value: 127), source: 10)
        input.receive(.init(kind: .note, channel: 0, number: 0, value: 127), source: 11)
        input.flushPendingActions()
        #expect(targets.isEmpty && jogs == 0)
    }
}

@Test @MainActor func controllerCatalogueMCX8000SourceEncodersAndCoarsePitchKeepDirectionsAndIgnoreLowByte() throws {
    try withMCX8000 { input in
        var events: [(ControllerActionTarget, Double)] = []
        var jogs: [(ControllerActionTarget, ControllerMIDIValue)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        input.onJogAction = { jogs.append(($0, $1)) }
        mcx8000Packet([0xB0, 6, 65, 0xB1, 6, 63], to: input)
        #expect(jogs.contains { $0.0 == .init(.jogA, deck: .a) && $0.1 == .relative(-1) })
        #expect(jogs.contains { $0.0 == .init(.jogB, deck: .b) && $0.1 == .relative(1) })
        mcx8000Packet([0xBF, 0, 1], to: input)
        #expect(events.last?.0.action == .browse && events.last?.1 == 0.5 + 1.0 / 126)
        mcx8000Packet([0xBF, 68, 127], to: input)
        #expect(events.last?.0.action == .browse && events.last?.1 == 0.5 - 1.0 / 126)
        let count = events.count
        mcx8000Packet([0xBF, 0, 64, 68, 64, 0xB0, 119, 127], to: input)
        #expect(events.count == count)
        mcx8000Packet([0xB0, 9, 0], to: input)
        #expect(events.last?.0.action == .tempoA && events.last?.1 == 1)
        mcx8000Packet([0xB0, 9, 127], to: input)
        #expect(events.last?.0.action == .tempoA && events.last?.1 == 0)
    }
}

@Test @MainActor func controllerCatalogueMCX8000DeckBankChangeReleasesOwnedCueAndContact() throws {
    try withMCX8000 { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in
            if [.cuePreviewA, .cuePreviewB, .jogTouchA, .jogTouchB].contains(target.action) {
                events.append((target, value))
            }
        }
        mcx8000Packet([0x90, 1, 127, 6, 127, 0x92, 8, 127], to: input)
        #expect(events.count == 4)
        #expect(events.allSatisfy { $0.0.deck == .a })
        #expect(events.prefix(2).map(\.1) == [1, 1] && events.suffix(2).map(\.1) == [0, 0])
        events.removeAll()
        mcx8000Packet([0x91, 1, 127, 6, 127, 0x93, 8, 127], to: input)
        #expect(events.count == 4 && events.allSatisfy { $0.0.deck == .b })
        #expect(events.suffix(2).allSatisfy { $0.1 == 0 })
    }
}

@Test @MainActor func controllerCatalogueMCX8000LifecycleAndFeedbackKeepSourceValuesAndFailureGuard() throws {
    let suite = "mcx-lifecycle-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    var packets: [[UInt8]] = []
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { bytes, _ in
            packets.append(bytes); return true
        })
    let source = ControllerMIDIConnection.Source(
        id: 10, reference: 100, name: "MCX8000", identity: .init(id: 10, device: 1, names: ["MCX8000"]))
    let destination = ControllerMIDIConnection.Source(
        id: 20, reference: 200, name: "MCX8000", identity: .init(id: 20, device: 1, names: ["MCX8000"]))
    input.sources = [source]
    input.destinations = [destination]
    input.reconcileFactoryProfiles()
    #expect(input.isInputActive(10) && packets.count == 30)
    #expect(Array(packets.prefix(2)) == [[0x90, 8, 127], [0x91, 8, 127]])
    input.reconcileFactoryProfiles()
    #expect(packets.count == 30)
    let profile = try #require(ControllerFactoryProfile.matching(["MCX8000"]))
    let cue = try #require(profile.feedback(destination: 20).first { $0.action == .cuePreviewA && $0.targetDeck == .a })
    #expect(cue.message(value: 0) == [0x90, 1, 1])
    let pfl = try #require(profile.feedback(destination: 20).first { $0.action == .cueA && $0.targetDeck == .a })
    #expect(pfl.message(value: 0) == [0x90, 27, 0])
    input.sources = []
    input.reconcileFactoryProfiles()
    input.sources = [source]
    input.reconcileFactoryProfiles()
    #expect(packets.count == 88)
    #expect(Array(packets.suffix(30).prefix(2)) == [[0x90, 8, 127], [0x91, 8, 127]])
    let failing = ControllerMIDIConnection(
        preferences: UserDefaults(suiteName: suite + "-failure")!, factoryPacketSender: { _, _ in false })
    defer { UserDefaults(suiteName: suite + "-failure")?.removePersistentDomain(forName: suite + "-failure") }
    failing.sources = [source]
    failing.destinations = [destination]
    failing.reconcileFactoryProfiles()
    #expect(!failing.isInputActive(10))
}
