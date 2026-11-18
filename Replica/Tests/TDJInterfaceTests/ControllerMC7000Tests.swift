import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withMC7000(decks: [DeckID] = DeckID.allCases, body: (ControllerMIDIConnection) throws -> Void)
    rethrows
{
    let suite = "mc7000-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences, factoryPacketSender: { _, _ in true }, deckAvailability: { decks })
    input.sources = [
        .init(id: 10, reference: 100, name: "MC7000", identity: .init(id: 10, device: 1, names: ["MC7000"]))
    ]
    input.destinations = [
        .init(id: 20, reference: 200, name: "MC7000", identity: .init(id: 20, device: 1, names: ["MC7000"]))
    ]
    input.reconcileFactoryProfiles()
    try body(input)
}

@MainActor private func mc7000Packet(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
}

@Test @MainActor func controllerCatalogueMC7000KeepsFourSequentialDeckChannelsAndGlobalLoad() throws {
    #expect(ControllerFactoryProfile.matching(["Denon DJ MC7000"], automaticOnly: true) != nil)
    #expect(ControllerFactoryProfile.matching(["MC7000 clone"], automaticOnly: true) == nil)
    withMC7000 { input in
        var targets: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in targets.append(target) }
        mc7000Packet([0x90, 0, 127, 0x91, 0, 127, 0x92, 0, 127, 0x93, 0, 127, 0x9F, 4, 127, 5, 127], to: input)
        #expect(
            targets == [
                .init(.playA, deck: .a), .init(.playB, deck: .b), .init(.playA, deck: .c), .init(.playB, deck: .d),
                .init(.loadA, deck: .c), .init(.loadB, deck: .d),
            ])
    }
    withMC7000(decks: DeckID.primary) { input in
        var targets: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in targets.append(target) }
        mc7000Packet([0x92, 0, 127, 0x93, 0, 127, 0x9F, 4, 127, 5, 127, 2, 127], to: input)
        #expect(targets == [.init(.loadA, deck: .a)])
    }
}

@Test func controllerCatalogueMC7000RetainsThePinnedJogBoundaryWithoutChangingOtherEncoders() {
    for (raw, ticks) in [(0, 0), (1, 1), (63, 63), (64, 64), (99, 99), (100, -28), (127, -1)] {
        var decoder = ControllerMIDIDecoder()
        var state = ControllerMIDIValueState()
        for message in decoder.append([0xB0, 6, UInt8(raw)]) {
            #expect(state.decode(message, encoding: .mc7000Jog, number: 6) == .relative(Double(ticks)))
        }
    }
    var decoder = ControllerMIDIDecoder()
    var state = ControllerMIDIValueState()
    for message in decoder.append([0xB0, 6, 64]) {
        #expect(state.decode(message, encoding: .twosComplement, number: 6) == .relative(-64))
        #expect(state.decode(message, encoding: .denonJog, number: 6) == .relative(0))
    }
}

@Test @MainActor func controllerCatalogueMC7000RetainsIndependentExplicitTempoPairsAndDirection() {
    withMC7000 { input in
        var values: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in values.append((target, value)) }
        mc7000Packet([0xB0, 9, 0, 0xB1, 9, 127, 0xB0, 119, 0, 0xB1, 119, 127], to: input)
        input.flushPendingActions()
        #expect(values.first { $0.0 == .init(.tempoA, deck: .a) }?.1 == 0)
        #expect(values.first { $0.0 == .init(.tempoB, deck: .b) }?.1 == 1)
        mc7000Packet([0xB0, 9, 127, 119, 127], to: input)
        input.flushPendingActions()
        #expect(values.last?.1 == 1)
    }
}

@Test @MainActor func controllerCatalogueMC7000ShiftGuardsLoadAndKeepsManualLoopsAndTouchRelease() {
    withMC7000 { input in
        var values: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in values.append((target, value)) }
        mc7000Packet(
            [0x90, 6, 127, 50, 127, 0x9F, 2, 127, 3, 127, 0x94, 56, 127, 57, 127, 51, 127, 0x80, 6, 0], to: input)
        #expect(
            values.map(\.0) == [
                .init(.jogTouchA, deck: .a), .init(.loadB, deck: .b), .init(.loopInA, deck: .a),
                .init(.loopOutA, deck: .a), .init(.reloopA, deck: .a), .init(.jogTouchA, deck: .a),
            ])
        #expect(values.last?.1 == 0)
        let sources = input.sources
        input.sources = []
        input.reconcileFactoryProfiles()
        input.sources = sources
        input.reconcileFactoryProfiles()
        mc7000Packet([0x90, 0, 127], to: input)
        #expect(values.last?.0 == .init(.playA, deck: .a))
    }
}

@Test @MainActor func controllerCatalogueMC7000KeepsPublishedDimFeedbackAndBoundedSetup() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["MC7000"], automaticOnly: true))
    let data = try #require(profile.definition)
    #expect(data.startup.first == [240, 0, 32, 127, 3, 1, 247])
    #expect(data.startup.contains([0x90, 8, 127]))
    #expect(data.startup.contains([0x91, 8, 127]))
    #expect(data.startup.count + data.shutdown.count <= 16)
    #expect(!data.inputs.contains { $0.action.rawValue.hasPrefix("hotcue") })
    let play = try #require(profile.feedback(destination: 20).first { $0.target == .init(.playB, deck: .d) })
    #expect(play.message(value: 1) == [0x93, 0, 127])
    #expect(play.message(value: 0) == [0x93, 0, 1])
}

@Test func controllerCatalogueMC7000RejectsJogEncodingOnNonControllerMessages() throws {
    let data = try JSONSerialization.data(withJSONObject: [
        "schemaVersion": 1,
        "profiles": [
            [
                "id": "invalid", "aliases": ["invalid"],
                "inputs": [
                    [
                        "action": "jogA", "kind": "note", "channel": 0, "number": 6,
                        "encoding": "mc7000Jog", "inverted": false,
                    ]
                ],
                "outputs": [], "startup": [], "shutdown": [], "autoSelect": true,
                "scope": "fixture", "source": "fixture",
            ]
        ],
    ])
    #expect(throws: (any Error).self) { try ControllerProfileCatalogue.decode(data) }
}

@Test @MainActor func controllerCatalogueMC7000HeldShiftFollowsThePhysicalSideAcrossBanks() {
    withMC7000 { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in
            if [.loadA, .playA, .loopInA].contains(target.action) { events.append(target) }
        }
        mc7000Packet(
            [
                0x90, 50, 127, 0x92, 8, 127, 0x9F, 4, 127, 0x8F, 4, 0,
                0x96, 56, 127, 0x82, 50, 0, 0x90, 8, 127, 0, 127,
            ], to: input)
        #expect(events == [.init(.loopInA, deck: .c), .init(.playA, deck: .a)])
    }
}

@Test @MainActor func controllerCatalogueMC7000BankResetsOnlyItsSidesCueAndPickup() {
    withMC7000 { input in
        input.currentTargetValue = { [.tempoA, .tempoB].contains($0.action) ? 0.5 : nil }
        var releases: [DeckID?] = []
        var tempos: [ControllerAction] = []
        input.onTargetAction = { target, value in
            if [.cuePreviewA, .cuePreviewB].contains(target.action), value == 0 { releases.append(target.deck) }
            if [.tempoA, .tempoB].contains(target.action) { tempos.append(target.action) }
        }
        mc7000Packet([0xB0, 9, 64, 119, 0, 0xB1, 9, 64, 119, 0, 0x90, 1, 127, 0x91, 1, 127], to: input)
        input.flushPendingActions()
        tempos.removeAll()
        mc7000Packet([0x92, 8, 127, 0xB0, 9, 0, 119, 0, 0xB1, 9, 0, 119, 0], to: input)
        input.flushPendingActions()
        #expect(releases == [.a])
        #expect(tempos == [.tempoB])
    }
}
