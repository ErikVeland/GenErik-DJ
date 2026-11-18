import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withN4(_ body: (ControllerMIDIConnection, [[UInt8]]) throws -> Void) rethrows {
    let suite = "n4-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    var packets: [[UInt8]] = []
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { bytes, _ in
            packets.append(bytes); return true
        },
        deckAvailability: { DeckID.allCases })
    input.sources = [
        .init(id: 10, reference: 100, name: "N4 MIDI 1", identity: .init(id: 10, device: 1, names: ["N4 MIDI 1"]))
    ]
    input.destinations = [
        .init(id: 20, reference: 200, name: "N4 MIDI 1", identity: .init(id: 20, device: 1, names: ["N4 MIDI 1"]))
    ]
    input.reconcileFactoryProfiles()
    try body(input, packets)
}

@MainActor private func n4Packet(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueN4KeepsEndpointAliasesAndItsOwnSetup() throws {
    try withN4 { input, packets in
        #expect(input.isInputActive(10))
        let profile = try #require(ControllerFactoryProfile.matching(["N4 MIDI 1"], automaticOnly: true))
        let data = try #require(profile.definition)
        #expect(data.inputs.count == 99 && data.outputs.count == 36)
        #expect(data.bankChanges?.count == 2)
        #expect(packets.count == 5)
        #expect(packets.first == [0xB1, 18, 127])
        #expect(packets.last == [0xF0, 0, 1, 63, 127, 71, 96, 0, 1, 84, 1, 0, 0, 0, 0, 0xF7])
        #expect(ControllerFactoryProfile.matching(["Numark N4 MK2"]) == nil)
        #expect(!data.inputs.contains { [.master, .monitor, .cueMix, .filterKnobA, .filterKnobB].contains($0.action) })
        #expect(!data.outputs.contains { [.cueA, .cueB].contains($0.action) || $0.action.isCueState })
    }
}

@Test @MainActor func controllerCatalogueN4HeadphoneStateAppliesBothStatesWithoutPickupOrToggleEdges() {
    withN4 { input, _ in
        var events: [(ControllerActionTarget, Double)] = []
        input.currentTargetValue = { _ in 0.5 }
        input.onTargetAction = { events.append(($0, $1)) }
        n4Packet([0x90, 49, 127, 49, 127, 49, 0, 51, 127, 0x80, 51, 0], to: input)
        #expect(
            events.map(\.0) == [
                .init(.cueStateA, deck: .a), .init(.cueStateA, deck: .a), .init(.cueStateA, deck: .a),
                .init(.cueStateA, deck: .c), .init(.cueStateA, deck: .c),
            ])
        #expect(events.map(\.1) == [1, 1, 0, 1, 0])
    }
}

@Test @MainActor func controllerCatalogueN4ControlBankReportsReleaseOnlyTheirSidesHeldContacts() {
    for bankValue in [UInt8(0), 1, 64, 127] {
        withN4 { input, _ in
            var events: [(ControllerActionTarget, Double)] = []
            input.onTargetAction = { if !$0.action.isJog { events.append(($0, $1)) } }
            n4Packet([0x91, 16, 127, 44, 127, 0x92, 16, 127], to: input)
            events.removeAll()
            n4Packet([0xB0, 80, bankValue], to: input)
            #expect(Set(events.map(\.0)) == [.init(.cuePreviewA, deck: .a), .init(.jogTouchA, deck: .a)])
            #expect(events.allSatisfy { $0.1 == 0 })
            events.removeAll()
            n4Packet([0xB0, 81, bankValue], to: input)
            #expect(events.map(\.0) == [.init(.cuePreviewB, deck: .b)])
        }
    }
}

@Test @MainActor func controllerCatalogueN4BankReportsDiscardIncompletePitchAndRearmOnlyTheirSide() {
    withN4 { input, _ in
        var targets: [ControllerActionTarget] = []
        input.currentTargetValue = { [.tempoA, .tempoB].contains($0.action) ? 0.5 : nil }
        input.onTargetAction = { target, _ in if !target.action.isJog { targets.append(target) } }
        n4Packet([0xB1, 1, 64, 33, 0, 0xB2, 1, 64, 33, 0], to: input)
        targets.removeAll()
        n4Packet([0xB1, 1, 100, 0xB2, 1, 100, 0xB0, 80, 0], to: input)
        targets.removeAll()
        n4Packet([0xB1, 33, 127, 0xB2, 33, 127], to: input)
        #expect(targets == [.init(.tempoB, deck: .b)])
        n4Packet([0xB1, 1, 127, 33, 127], to: input)
        #expect(targets.count == 1)
        n4Packet([0xB1, 1, 64, 33, 0], to: input)
        #expect(targets.last == .init(.tempoA, deck: .a))
    }
}

@Test @MainActor func controllerCatalogueN4StablePhysicalShiftReleasesUnderTheOtherBankAndPreservesOtherSide() {
    withN4 { input, _ in
        var targets: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in if !target.action.isJog { targets.append(target) } }
        n4Packet([0x91, 18, 127, 0xB0, 80, 127, 0x93, 17, 127, 0x92, 17, 127, 18, 127], to: input)
        #expect(targets == [.init(.playB, deck: .b)])
        targets.removeAll()
        n4Packet([0x83, 18, 0, 0x93, 17, 0, 17, 127, 0xB0, 68, 1], to: input)
        #expect(targets == [.init(.playA, deck: .c)])
        n4Packet([0x84, 18, 0, 0xB0, 68, 1], to: input)
        #expect(targets.last == .init(.browse))
    }
}

@Test @MainActor func controllerCatalogueN4RoutesMixerPairsCuesAndNativeLoopLayout() {
    withN4 { input, _ in
        var targets: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in if !target.action.isJog { targets.append(target) } }
        n4Packet([0xB0, 28, 127, 60, 127], to: input)
        n4Packet([0x94, 6, 127, 21, 127, 22, 127, 39, 127], to: input)
        #expect(
            targets == [
                .init(.gainB, deck: .d), .init(.loadB, deck: .d), .init(.loopEnableB, deck: .d),
                .init(.reloopB, deck: .d), .init(.hotcue1B, deck: .d),
            ])
        targets.removeAll()
        n4Packet([0x94, 18, 127, 0xB0, 28, 0, 60, 0, 0x94, 6, 0, 6, 127, 21, 0, 21, 127, 39, 0, 39, 127], to: input)
        #expect(targets.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueN4JogsRetainXMLDispatchDirectionAnd600CountScale() {
    withN4 { input, _ in
        var jogs: [(ControllerActionTarget, ControllerMIDIValue)] = []
        input.onJogAction = { jogs.append(($0, $1)) }
        n4Packet([0xB1, 32, 1], to: input)
        n4Packet([0xB3, 32, 127], to: input)
        n4Packet([0xB1, 44, 1], to: input)
        #expect(jogs.map(\.0) == [.init(.jogA, deck: .a, argument: 600), .init(.jogA, deck: .c, argument: 600)])
        #expect(jogs.map(\.1) == [.relative(1), .relative(-1)])
    }
}

@Test func controllerCatalogueControlBankSchemaRequiresExplicitKindAndRejectsReleaseMetadata() throws {
    func decode(_ bank: [String: Any]) throws -> ControllerProfileCatalogue {
        let profile: [String: Any] = [
            "id": "bank fixture", "aliases": ["bank fixture"],
            "inputs": [
                [
                    "action": "playA", "kind": "note", "channel": 0, "number": 1, "encoding": "absolute",
                    "inverted": false,
                ]
            ],
            "outputs": [], "startup": [], "shutdown": [], "autoSelect": false, "scope": "fixture", "source": "fixture",
            "bankChanges": [bank],
        ]
        return try ControllerProfileCatalogue.decode(
            JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "profiles": [profile]]))
    }
    let valid: [String: Any] = ["kind": "control", "channel": 0, "number": 80, "decks": ["a", "c"]]
    #expect(try decode(valid).profiles.count == 1)
    for (key, value) in [("kind", "pitch" as Any), ("onValue", 128 as Any), ("releaseShiftChannels", [] as [Int])] {
        var invalid = valid
        invalid[key] = value
        #expect(throws: (any Error).self) { try decode(invalid) }
    }
    var note = valid
    note["kind"] = "note"
    #expect(throws: (any Error).self) { try decode(note) }
}
