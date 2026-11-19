import Foundation
import TDJCore
import Testing

@testable import TDJInterface

private let apc40Models = ["Akai APC40 MKII", "Akai APC40"]

@MainActor private func withAPC40(
    _ name: String, decks: [DeckID] = DeckID.allCases, _ body: (ControllerMIDIConnection) throws -> Void
) throws {
    let suite = "apc40-\(UUID().uuidString)"; let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences, factoryPacketSender: { _, _ in true }, deckAvailability: { decks },
        factoryInputConnector: { _ in true })
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id + 100), name: name, identity: .init(id: id, device: UInt32(id), names: [name]))
    }
    input.destinations = [20, 21].map { id in
        .init(
            id: id, reference: UInt32(id + 100), name: name,
            identity: .init(id: id, device: UInt32(id - 10), names: [name]))
    }
    input.reconcileFactoryProfiles()
    #expect(input.isInputActive(10) && input.isInputActive(11))
    try body(input)
}

@MainActor private func apc40Packet(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source); input.flushPendingActions()
}

@Test(arguments: apc40Models) @MainActor func controllerCatalogueAPC40KeepsGenerationIdentityAndBoundedModeSetup(
    _ name: String
) throws {
    let profile = try #require(ControllerFactoryProfile.matching([name], automaticOnly: true));
    let data = try #require(profile.definition)
    let mk2 = name == apc40Models[0]; let product: UInt8 = mk2 ? 41 : 115
    #expect(
        data.inputs.count == (mk2 ? 114 : 113) && data.outputs.count == 68 && data.audioOutput == nil
            && data.requiresPairedSetup)
    #expect(data.startup == [[240, 71, 127, product, 96, 0, 4, 65, 0, 1, 0, 247]])
    #expect(data.shutdown.count == 53 && data.startupAbort == [[240, 71, 127, product, 96, 0, 4, 64, 0, 1, 0, 247]])
    for other in [mk2 ? "APC40" : "APC40 MKII", "APC mini MK2", "APC20", "APC64", name + " clone"] {
        #expect(ControllerFactoryProfile.matching([other], automaticOnly: true) != profile)
    }
}

@Test(arguments: apc40Models) @MainActor func controllerCatalogueAPC40NativePadTargetsUseIndependentGridWires(
    _ name: String
) throws {
    try withAPC40(name) { input in
        let mk2 = name == apc40Models[0]
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        for (side, deck) in DeckID.allCases.enumerated() {
            for slot in 0..<8 {
                let column = 2 * side + slot % 2; let row = slot / 2
                let channel: UInt8 = mk2 ? 11 : UInt8(column)
                let number: UInt8 = mk2 ? UInt8(8 * row + column) : UInt8(53 + row)
                events.removeAll(); apc40Packet([0x90 + channel, number, 127, number, 127, number, 0], input)
                #expect(events.count == 1 && events.first?.0.action.hotcueSlot == slot && events.first?.0.deck == deck)
            }
            let playChannel: UInt8 = mk2 ? 15 : UInt8(2 * side)
            let play: UInt8 = mk2 ? UInt8(32 + 2 * side) : 57
            events.removeAll(); apc40Packet([0x90 + playChannel, play, 127, play, 127, play, 0], input)
            #expect(events.map(\.0) == [.init(ControllerAction.playA.assigned(to: deck), deck: deck)])
            let cueChannel: UInt8 = mk2 ? 12 : UInt8(2 * side + 1)
            let cue: UInt8 = mk2 ? UInt8(33 + 2 * side) : 57
            for off: UInt8 in [0x80 + cueChannel, 0x90 + cueChannel] {
                events.removeAll();
                apc40Packet([0x90 + cueChannel, cue, 127, cue, 127, off, cue, off < 0x90 ? 127 : 0], input)
                #expect(events.map(\.1) == [1, 0] && events.allSatisfy { $0.0.deck == deck })
            }
        }
    }
}

@Test(arguments: apc40Models) @MainActor func controllerCatalogueAPC40TrackButtonsAndLibraryKeepTheirOwnChannels(
    _ name: String
) throws {
    try withAPC40(name) { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        for (side, deck) in DeckID.allCases.enumerated() {
            for (right, actions): (Bool, [(UInt8, ControllerAction)]) in [
                (false, [(48, .syncA), (49, .cueA), (50, .loopInA), (51, .loopDownA), (52, .reloopA)]),
                (true, [(48, .loadA), (49, .keylockA), (50, .loopOutA), (51, .loopUpA), (52, .loopA)]),
            ] {
                let channel = UInt8(2 * side + (right ? 1 : 0))
                for (number, action) in actions {
                    events.removeAll(); apc40Packet([0x90 + channel, number, 127, number, 127, number, 0], input)
                    #expect(events == [.init(action.assigned(to: deck), deck: deck)])
                }
            }
        }
        events.removeAll();
        apc40Packet([0x9F, 82, 127, 82, 0, 83, 127, 83, 0, 84, 127, 84, 0, 85, 127, 85, 0, 86, 127, 86, 0], input)
        #expect(
            events.map(\.action) == [.browsePreviousGroup, .browseNextGroup, .openGroup, .browsePrevious, .browseNext])
        events.removeAll(); apc40Packet([0x98, 48, 127, 48, 0, 49, 127, 49, 0, 50, 127, 50, 0], input)
        #expect(events.isEmpty)
    }
}

@Test(arguments: apc40Models) @MainActor func controllerCatalogueAPC40ShiftCleansSourceOwnedCueOnEveryGlobalChannel(
    _ name: String
) throws {
    try withAPC40(name) { input in
        let mk2 = name == apc40Models[0]
        let cueChannel: UInt8 = mk2 ? 0 : 1; let cue: UInt8 = mk2 ? 33 : 57
        var values: [Double] = [];
        input.onTargetAction = { target, value in
            if target.action == .cuePreviewA && target.deck == .a { values.append(value) }
        }
        for channel: UInt8 in 0..<16 {
            values.removeAll(); apc40Packet([0x90 + cueChannel, cue, 127], input)
            apc40Packet([0x90 + cueChannel, cue, 127], input, source: 11)
            apc40Packet([0x90 + channel, 98, 127], input)
            #expect(values == [1])
            apc40Packet([0x90 + channel, 98, 127], input, source: 11)
            #expect(values == [1, 0])
            apc40Packet([0x80 + channel, 98, 127], input)
            apc40Packet([0x90 + channel, 98, 0], input, source: 11)
        }
        apc40Packet([0x90 + cueChannel, cue, 127], input); input.stop()
        #expect(values.suffix(2) == [1, 0])
    }
}

@Test(arguments: apc40Models) @MainActor func controllerCatalogueAPC40MixerPositionsAndSignedCueLevelRetainPickup(
    _ name: String
) throws {
    try withAPC40(name) { input in
        input.currentTargetValue = { _ in 0.5 }
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        for (side, deck) in DeckID.allCases.enumerated() {
            var controls: [(UInt8, UInt8, ControllerAction)] = [
                (UInt8(2 * side), 7, .levelA), (UInt8(2 * side + 1), 7, .gainA),
            ]
            let base = side < 2 ? 16 + 4 * side : 48 + 4 * (side - 2)
            controls += [
                (15, UInt8(base), .highA), (15, UInt8(base + 1), .midA), (15, UInt8(base + 2), .lowA),
                (15, UInt8(base + 3), .filterKnobA),
            ]
            for (channel, number, action) in controls {
                events.removeAll(); apc40Packet([0xB0 + channel, number, 0], input)
                #expect(events.isEmpty)
                apc40Packet([0xB0 + channel, number, 64], input); apc40Packet([0xB0 + channel, number, 127], input)
                #expect(
                    events.count == 2 && events.allSatisfy { $0.0 == .init(action.assigned(to: deck), deck: deck) }
                        && events.last?.1 == 1)
            }
        }
        for number: UInt8 in [14, 15] {
            events.removeAll(); apc40Packet([0xBF, number, 0], input); #expect(events.isEmpty)
            apc40Packet([0xBF, number, 64], input); apc40Packet([0xBF, number, 127], input)
            #expect(events.count == 2 && events.last?.1 == 1)
        }
        events.removeAll()
        for value: UInt8 in [0, 1, 127, 64] { apc40Packet([0xBF, 47, value], input) }
        #expect(events.map(\.1) == [0.5 + 1.0 / 127, 0.5 - 1.0 / 127, 0])
        #expect(events.allSatisfy { $0.0.action == .monitor })
        events.removeAll(); apc40Packet([0xBF, 13, 1], input); apc40Packet([0xBF, 13, 127], input)
        #expect(events.map(\.0.action) == (name == apc40Models[0] ? [.browse, .browse] : []))
        events.removeAll(); apc40Packet([0xBF, 24, 127, 31, 127, 56, 127, 63, 127, 64, 127, 67, 127], input)
        #expect(events.isEmpty)
    }
}

@Test(arguments: apc40Models) @MainActor
func controllerCatalogueAPC40FeedbackKeepsIndependentPadColoursAndKnobPositions(_ name: String) throws {
    let profile = try #require(ControllerFactoryProfile.matching([name])); let mk2 = name == apc40Models[0]
    for lamp in profile.feedback(destination: 20) {
        if lamp.kind == .control {
            #expect(lamp.message(value: 0) == [0xB0, lamp.number, 0])
            #expect(lamp.message(value: 0.5) == [0xB0, lamp.number, 64])
            #expect(lamp.message(value: 1) == [0xB0, lamp.number, 127])
        } else {
            let grid = mk2 ? lamp.number < 40 : (53...57).contains(lamp.number)
            let on: UInt8 =
                !grid
                ? 1
                : lamp.action == .playA || lamp.action == .playB
                    ? (mk2 ? 19 : 1)
                    : lamp.action == .cuePreviewA || lamp.action == .cuePreviewB ? (mk2 ? 5 : 3) : (mk2 ? 45 : 5)
            #expect(lamp.message(value: 1) == [0x90 + lamp.channel, lamp.number, on])
            #expect(lamp.message(value: 0) == [0x80 + lamp.channel, lamp.number, 0])
        }
    }
}

@Test(arguments: apc40Models) @MainActor
func controllerCatalogueAPC40FailureAndShutdownRestoreOnlyTheDocumentedGenericMode(_ name: String) throws {
    let profile = try #require(ControllerFactoryProfile.matching([name])); let data = try #require(profile.definition)
    for fail in [false, true] {
        let suite = "apc40-lifecycle-\(UUID().uuidString)"; let preferences = UserDefaults(suiteName: suite)!
        defer { preferences.removePersistentDomain(forName: suite) }
        var packets: [[UInt8]] = []
        let input = ControllerMIDIConnection(
            preferences: preferences,
            factoryPacketSender: { bytes, id in
                #expect(id == 20); packets.append(bytes); return !(fail && packets.count == 1)
            }, factoryInputConnector: { _ in true })
        input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
        input.destinations = [
            .init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))
        ]
        input.reconcileFactoryProfiles()
        #expect(input.isInputActive(10) == !fail)
        if fail {
            #expect(packets == data.startup + (data.startupAbort ?? []))
        } else {
            #expect(packets == data.startup); packets.removeAll(); input.stop(); #expect(packets == data.shutdown)
        }
    }
}

@Test(arguments: apc40Models) @MainActor func controllerCatalogueAPC40KeepsFourDeckOptIn(_ name: String) throws {
    try withAPC40(name, decks: DeckID.primary) { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        if name == apc40Models[0] {
            apc40Packet([0x90, 36, 127, 36, 0, 38, 127, 38, 0, 20, 127, 20, 0], input)
        } else {
            apc40Packet([0x94, 57, 127, 57, 0, 0x96, 53, 127, 53, 0], input)
        }
        apc40Packet([0x94, 48, 127, 48, 0, 0x97, 49, 127, 49, 0, 0xB4, 7, 64, 7, 127], input)
        #expect(events.isEmpty)
    }
}

@Test func controllerCatalogueAPC40WildcardAccessoryNeedsExplicitPairedUnbankedContract() throws {
    let changes: [[String: Any]] = (0..<16).map {
        ["channel": $0, "number": 98, "onValue": 127, "decks": ["a", "b", "c", "d"]]
    }
    let base: [String: Any] = [
        "id": "unbanked fixture", "aliases": ["unbanked fixture"], "autoSelect": true, "role": "accessory",
        "unbankedGlobalInputs": true, "source": "fixture", "scope": "fixture", "startup": [[0x90, 0, 0]],
        "shutdown": [[0x90, 0, 0]], "startupAbort": [[0x90, 0, 0]], "outputs": [],
        "bankChanges": changes,
        "inputs": [
            [
                "action": "playA", "kind": "note", "channel": 0, "number": 0, "encoding": "absolute", "inverted": false,
                "anyChannel": true, "targetDeck": "a",
            ],
            [
                "action": "shift", "kind": "note", "channel": 0, "number": 98, "encoding": "absolute",
                "inverted": false, "anyChannel": true,
            ],
            [
                "action": "levelA", "kind": "control", "channel": 0, "number": 7, "encoding": "absolute",
                "inverted": false, "targetDeck": "a",
            ],
        ],
    ]
    func decode(_ p: [String: Any]) throws -> ControllerProfileCatalogue {
        try ControllerProfileCatalogue.decode(
            JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "profiles": [p]]))
    }
    #expect(try decode(base).profiles.first?.requiresPairedSetup == true)
    for (field, value): (String, Any) in [
        ("unbankedGlobalInputs", false), ("autoSelect", false), ("role", "player"),
        ("startup", []), ("shutdown", []), ("startupAbort", []), ("bankChanges", Array(changes.dropLast())),
    ] {
        var invalid = base; invalid[field] = value
        #expect(throws: (any Error).self) { try decode(invalid) }
    }
    var invalid = base
    var inputs = try #require(base["inputs"] as? [[String: Any]])
    inputs[0]["channel"] = 1; invalid["inputs"] = inputs
    #expect(throws: (any Error).self) { try decode(invalid) }
    var scoped = changes; scoped[0]["decks"] = ["a", "b"]
    invalid = base; invalid["bankChanges"] = scoped
    #expect(throws: (any Error).self) { try decode(invalid) }
}
