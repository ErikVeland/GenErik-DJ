import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withDDJ1000(
    _ decks: [DeckID] = DeckID.allCases, _ body: (ControllerMIDIConnection) throws -> Void
) rethrows {
    let suite = "ddj1000-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences, factoryPacketSender: { _, _ in true }, deckAvailability: { decks })
    input.sources = [
        .init(id: 10, reference: 100, name: "DDJ-1000", identity: .init(id: 10, device: 1, names: ["DDJ-1000"]))
    ]
    input.destinations = [
        .init(id: 20, reference: 200, name: "DDJ-1000", identity: .init(id: 20, device: 1, names: ["DDJ-1000"]))
    ]
    input.reconcileFactoryProfiles()
    try body(input)
}

@MainActor private func ddj1000Packet(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueDDJ1000UsesNormalSyncTempoAndLoopAddresses() {
    withDDJ1000 { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        ddj1000Packet([0x90, 88, 127, 26, 127, 20, 127, 0xB0, 0, 64, 32, 0], to: input)
        #expect(events.map(\.action) == [.syncA, .keylockA, .toggleFixedLoopA, .tempoA])
        #expect(events.map(\.deck) == [.a, .a, .a, .a])
        #expect(events.first { $0.action == .toggleFixedLoopA }?.argument == 4)
    }
}

@Test @MainActor func controllerCatalogueDDJ1000TargetsTheThirdAndFourthDecks() {
    withDDJ1000 { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        ddj1000Packet([0x92, 11, 127, 0x93, 12, 127, 0x96, 72, 127, 0x9D, 7, 127], to: input)
        #expect(
            events == [
                .init(.playA, deck: .c), .init(.cuePreviewB, deck: .d),
                .init(.loadA, deck: .c), .init(.hotcue8B, deck: .d),
            ])
    }
}

@Test @MainActor func controllerCatalogueDDJ1000SwitchEventsProtectOnlyTheirPhysicalSide() {
    withDDJ1000 { input in
        input.currentTargetValue = { [.tempoA, .tempoB].contains($0.action) ? 0.5 : nil }
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
        ddj1000Packet([0xB0, 0, 64, 32, 0, 0xB1, 0, 64, 32, 0, 0x90, 12, 127, 0x91, 12, 127], to: input)
        events.removeAll()
        ddj1000Packet([0x92, 60, 127], to: input)
        #expect(events.isEmpty)
        ddj1000Packet([0x92, 114, 127], to: input)
        #expect(events.map(\.0) == [.init(.cuePreviewA, deck: .a)])
        #expect(events.map(\.1) == [0])
        events.removeAll()
        ddj1000Packet([0xB0, 0, 0, 32, 0, 0xB1, 0, 0, 32, 0], to: input)
        #expect(events.map(\.0) == [.init(.tempoB, deck: .b)])
    }
}

@Test @MainActor func controllerCatalogueDDJ1000RetainsShiftAcrossBanksWithoutUsingShiftedMasterControls() {
    withDDJ1000 { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in if !target.action.isJog { events.append(target) } }
        ddj1000Packet(
            [
                0x90, 63, 127, 0x92, 114, 127, 11, 127, 92, 127, 96, 127, 104, 127,
                0x91, 11, 127, 0xB2, 5, 64, 37, 0,
            ], to: input)
        #expect(events == [.init(.playB, deck: .b), .init(.tempoA, deck: .c)])
        events.removeAll()
        ddj1000Packet([0x82, 11, 0, 63, 0, 0x92, 11, 127, 0xB2, 0, 64, 32, 0], to: input)
        #expect(events == [.init(.playA, deck: .c), .init(.tempoA, deck: .c)])
    }
}

@Test @MainActor func controllerCatalogueDDJ1000SeparatesPlatterWheelAndGridReports() {
    withDDJ1000 { input in
        var events: [ControllerActionTarget] = []
        input.onJogAction = { target, _ in events.append(target) }
        ddj1000Packet([0xB0, 34, 65], to: input)
        ddj1000Packet([0xB0, 33, 65], to: input)
        ddj1000Packet([0xB0, 35, 65], to: input)
        #expect(events.map(\.action) == [.jogA, .wheelJogA, .wheelJogA])
        events.removeAll()
        ddj1000Packet([0x90, 63, 127, 0xB0, 31, 65, 38, 65], to: input)
        #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueDDJ1000KeepsSRTSeparateAndRespectsDeckCapacity() throws {
    #expect(ControllerFactoryProfile.matching(["DDJ-1000"]) == .ddj1000)
    #expect(ControllerFactoryProfile.matching(["DDJ-1000SRT"]) != .ddj1000)
    #expect(ControllerFactoryProfile.matching(["DDJ-1000+"]) == nil)
    let profile = try #require(ControllerFactoryProfile.ddj1000.definition)
    #expect(profile.inputs.count == 221 && profile.outputs.count == 48)
    #expect(profile.bankChanges?.map(\.channel) == [2, 3])
    let feedback = ControllerMIDIConnection.ddj1000FeedbackBindings(destination: 20)
    for deck in DeckID.allCases {
        let scoped = feedback.filter { $0.targetDeck == deck }
        #expect(scoped.count == 12)
        #expect(scoped.contains { [.syncA, .syncB].contains($0.action) && $0.number == 88 })
        #expect(scoped.contains { [.keylockA, .keylockB].contains($0.action) && $0.number == 26 })
    }
    withDDJ1000([.a, .b]) { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        ddj1000Packet([0x92, 11, 127, 0x93, 12, 127, 0x96, 72, 127, 0x9B, 7, 127, 0x9C, 7, 127, 0x9E, 7, 127], to: input)
        #expect(events.isEmpty)
    }
}
