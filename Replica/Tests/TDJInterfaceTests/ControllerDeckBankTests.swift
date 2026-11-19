import Foundation
import TDJCore
import Testing

@testable import TDJInterface

private func deckBankFixture(
    inputBank: Int = 0, selectorBank: Int = 0,
    decks: [String] = ["a", "c"], includeSelector: Bool = true
) throws -> Data {
    try JSONSerialization.data(withJSONObject: [
        "schemaVersion": 1,
        "profiles": [
            [
                "id": "bank fixture", "aliases": ["bank fixture"], "autoSelect": false,
                "source": "fixture", "scope": "fixture", "startup": [], "shutdown": [], "outputs": [],
                "inputs": [
                    [
                        "action": "cuePreviewA", "kind": "note", "channel": 0, "number": 13,
                        "encoding": "absolute", "inverted": false, "targetDeck": "a", "deckBank": inputBank,
                    ]
                ],
                "bankChanges": includeSelector
                    ? [
                        [
                            "channel": 0, "number": 14, "onValue": 127,
                            "decks": decks, "deckBank": selectorBank,
                        ]
                    ] : [],
            ]
        ],
    ])
}

@Test func controllerDeckBankSchemaRejectsUnboundedOrUnmatchedSideSelectors() throws {
    _ = try ControllerProfileCatalogue.decode(deckBankFixture())
    for data in [
        try deckBankFixture(inputBank: 2), try deckBankFixture(selectorBank: 2),
        try deckBankFixture(decks: ["a", "b"]), try deckBankFixture(decks: ["c", "a"]),
        try deckBankFixture(includeSelector: false),
    ] {
        #expect(throws: (any Error).self) { try ControllerProfileCatalogue.decode(data) }
    }
}

@Test func controllerDeckBankAutomaticRoutingRequiresPairedSetupAndOnlyLoadTargets() throws {
    let base = try #require(try JSONSerialization.jsonObject(with: deckBankFixture()) as? [String: Any])
    var fixture = try #require((base["profiles"] as? [[String: Any]])?.first)
    fixture["autoSelect"] = true
    fixture["startup"] = [[0xB7, 0, 0]]
    fixture["shutdown"] = [[0xB7, 0, 0]]
    var inputs = try #require(fixture["inputs"] as? [[String: Any]])
    inputs[0]["action"] = "loadA"
    fixture["inputs"] = inputs
    func decode(_ profile: [String: Any]) throws -> ControllerProfileCatalogue {
        try ControllerProfileCatalogue.decode(
            JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "profiles": [profile]]))
    }
    let valid = try decode(fixture)
    #expect(valid.profiles.first?.requiresPairedSetup == true)
    for field in ["startup", "shutdown"] {
        var invalid = fixture
        invalid[field] = []
        #expect(throws: (any Error).self) { try decode(invalid) }
    }
    var invalidAction = fixture
    inputs[0]["action"] = "playA"
    invalidAction["inputs"] = inputs
    #expect(throws: (any Error).self) { try decode(invalidAction) }
    var invalidFeedback = fixture
    invalidFeedback["outputs"] = [
        [
            "action": "loadA", "kind": "note", "channel": 7, "number": 13,
            "offValue": 0, "onValue": 127, "offUsesNoteOn": true, "targetDeck": "a",
        ]
    ]
    #expect(throws: (any Error).self) { try decode(invalidFeedback) }
    var invalidRole = fixture
    invalidRole["role"] = "accessory"
    #expect(throws: (any Error).self) { try decode(invalidRole) }
}

@MainActor private func withVMS5(
    decks: [DeckID] = DeckID.allCases,
    _ body: (ControllerMIDIConnection) throws -> Void
) throws {
    let suite = "vms5-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { _, _ in
            Issue.record("The manual VMS5 profile must not write hardware state.")
            return false
        }, deckAvailability: { decks })
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id + 100), name: "VMS5",
            identity: .init(id: id, device: UInt32(id), names: ["VMS5"]))
    }
    input.reconcileFactoryProfiles()
    #expect(!input.isInputActive(10) && !input.isInputActive(11))
    let profile = try #require(ControllerFactoryProfile.matching(["VMS5"]))
    for source: Int32 in [10, 11] { input.select(source); input.applyFactoryProfile(profile) }
    #expect(input.bindingCount == 80)
    try body(input)
}

@MainActor private func vms5Packet(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source)
    input.flushPendingActions()
}

@Test @MainActor func controllerDeckBankVMS5KeepsIndependentSidesSourcesAndOneTogglePerPress() throws {
    try withVMS5 { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, value in
            if target.action == .playA || target.action == .playB { events.append(target) }
        }
        vms5Packet([0x90, 14, 127, 14, 127, 12, 127, 12, 0, 46, 127, 46, 0], input)
        #expect(events.map(\.deck) == [.c, .b])
        vms5Packet([0x90, 12, 127, 12, 0], input, source: 11)
        vms5Packet([0x90, 48, 127, 48, 0, 46, 127, 46, 0], input)
        #expect(events.map(\.deck) == [.c, .b, .a, .d])
        vms5Packet([0x80, 14, 127, 0x90, 14, 127, 14, 0, 12, 127, 12, 0], input)
        #expect(events.last?.deck == .a)
        vms5Packet([0x90, 14, 64, 12, 127, 12, 0], input)
        #expect(events.last?.deck == .a)
        input.select(10)
        input.applyFactoryProfile(try #require(ControllerFactoryProfile.matching(["VMS5"])))
        vms5Packet([0x90, 46, 127, 46, 0], input)
        #expect(events.last?.deck == .b)
    }
}

@Test @MainActor func controllerDeckBankVMS5RetiresOwnedHoldsAndRearmsBothReleaseForms() throws {
    try withVMS5 { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in
            if target.action == .cuePreviewA || target.action == .cuePreviewB { events.append((target, value)) }
        }
        vms5Packet([0x90, 13, 127], input)
        vms5Packet([0x90, 13, 127], input, source: 11)
        vms5Packet([0x90, 47, 127, 14, 127, 14, 0], input)
        #expect(events.map(\.1) == [1, 1])
        vms5Packet([0x80, 13, 127], input, source: 11)
        #expect(events.last?.0.deck == .a && events.last?.1 == 0)
        for off: UInt8 in [0x80, 0x90] {
            vms5Packet([0x90, 13, 127, 13, 127, off, 13, off == 0x80 ? 127 : 0], input)
            #expect(events.suffix(2).map(\.1) == [1, 0] && events.suffix(2).allSatisfy { $0.0.deck == .c })
        }
        vms5Packet([0x90, 48, 127, 48, 0], input)
        #expect(events.last?.0.deck == .b && events.last?.1 == 0)
        vms5Packet([0x90, 13, 127], input)
        input.stop()
        #expect(events.last?.0.deck == .c && events.last?.1 == 0)
    }
}

@Test @MainActor func controllerDeckBankVMS5ResetsJogCountersAndTempoPickupWithoutMovingMixerStrips() throws {
    try withVMS5 { input in
        var jogs: [(ControllerActionTarget, Double)] = []
        input.onJogAction = { target, value in if case .relative(let count) = value { jogs.append((target, count)) } }
        vms5Packet([0xB0, 49, 0, 48, 10, 49, 0, 48, 11], input)
        #expect(jogs.map(\.1) == [1] && jogs.first?.0.deck == .a)
        vms5Packet([0x90, 14, 127, 14, 0, 0xB0, 49, 1, 48, 90], input)
        #expect(jogs.count == 1)
        vms5Packet([0xB0, 49, 1, 48, 91], input)
        #expect(jogs.last?.0.deck == .c && jogs.last?.1 == 1)
        vms5Packet([0x90, 14, 127, 14, 0, 0xB0, 49, 4, 48, 90], input)
        #expect(jogs.count == 2)
        input.currentTargetValue = { _ in 0.5 }
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in
            if target.action == .tempoA || target.action == .levelA { events.append((target, value)) }
        }
        for packet: [UInt8] in [[0xE0, 0, 64], [0xE0, 0, 127], [0xB0, 9, 64], [0xB0, 9, 127]] {
            vms5Packet(packet, input)
        }
        #expect(events.count == 4)
        events.removeAll()
        vms5Packet([0x90, 14, 127, 14, 0, 0xE0, 0, 127, 0xB0, 9, 0], input)
        #expect(events.count == 1 && events.first?.0 == .init(.levelA, deck: .a) && events.first?.1 == 0)
        vms5Packet([0xE0, 0, 64], input)
        vms5Packet([0xE0, 0, 0], input)
        #expect(events.suffix(2).allSatisfy { $0.0.deck == .c } && events.last?.1 == 1)
    }
}

@Test @MainActor func controllerDeckBankVMS5KeepsFourDeckOptInAndManualModeBoundaries() throws {
    try withVMS5(decks: DeckID.primary) { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, value in if !(target.action.isJog && value == 0.5) { events.append(target) } }
        vms5Packet([0x90, 14, 127, 14, 0, 48, 127, 48, 0, 12, 127, 12, 0, 46, 127, 46, 0], input)
        #expect(events.isEmpty)
        vms5Packet([0x90, 21, 127, 55, 127, 39, 127, 73, 127, 42, 127, 0xB0, 52, 1], input)
        #expect(events.isEmpty)
        input.stop()
        vms5Packet([0x90, 12, 127, 12, 0], input)
        #expect(events.last?.deck == .a)
    }
    let profile = try #require(ControllerFactoryProfile.matching(["VMS5.0 AUDIO MIDI Device"]))
    let data = try #require(profile.definition)
    #expect(!profile.selectsAutomatically && data.inputs.count == 40 && data.outputs.isEmpty)
    #expect(data.startup.isEmpty && data.shutdown.isEmpty && data.audioOutput == nil)
    for name in ["VMS2", "VMS4", "VMS4.1 Traktor", "VMS5 clone"] {
        #expect(ControllerFactoryProfile.matching([name]) != profile)
    }
}

@Test @MainActor func controllerDeckBankVMS5StopsOldJogBeforeRetargetingAndReconnectsOnAB() throws {
    try withVMS5 { input in
        var neutral: [DeckID?] = []
        input.onTargetAction = { target, value in if target.action.isJog && value == 0.5 { neutral.append(target.deck) }
        }
        vms5Packet([0x90, 14, 127, 14, 0], input)
        #expect(neutral == [.a])
        neutral.removeAll()
        vms5Packet([0x90, 14, 127, 14, 0], input)
        #expect(neutral == [.c])
        vms5Packet([0x90, 14, 127, 14, 0, 48, 127, 48, 0], input)
        input.setInputActive(10, active: false)
        input.setInputActive(10, active: true)
        var events: [DeckID?] = []
        input.onTargetAction = { target, _ in
            if target.action == .playA || target.action == .playB { events.append(target.deck) }
        }
        vms5Packet([0x90, 12, 127, 12, 0, 46, 127, 46, 0], input)
        #expect(events == [.a, .b])
    }
}
