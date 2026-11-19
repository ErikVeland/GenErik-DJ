import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@Test @MainActor func controllerCatalogueProgrammerGridRestoresLiveAfterPartialStartupFailure() throws {
    for (name, port, model): (String, String, UInt8) in [
        ("Launchpad X", "LPX MIDI", 12), ("Launchpad Pro MK3", "LPProMK3 MIDI", 14),
    ] {
        let profile = try #require(ControllerFactoryProfile.matching([name]))
        let data = try #require(profile.definition)
        for failure in 0..<3 {
            let suite = "programmer-abort-\(UUID().uuidString)"
            let preferences = UserDefaults(suiteName: suite)!
            defer { preferences.removePersistentDomain(forName: suite) }
            var packets: [[UInt8]] = []
            let input = ControllerMIDIConnection(
                preferences: preferences,
                factoryPacketSender: { bytes, id in
                    #expect(id == 20)
                    let index = packets.count
                    packets.append(bytes)
                    return index != failure
                }, factoryInputConnector: { _ in true })
            input.sources = [
                .init(
                    id: 10, reference: 100, name: name,
                    identity: .init(id: 10, device: 1, names: [name], portNames: [port]))
            ]
            input.destinations = [
                .init(
                    id: 20, reference: 200, name: name,
                    identity: .init(id: 20, device: 1, names: [name], portNames: [port]))
            ]
            input.reconcileFactoryProfiles()
            #expect(!input.isInputActive(10))
            #expect(packets == Array(data.startup.prefix(failure + 1)) + [[240, 0, 32, 41, 2, model, 14, 0, 247]])
        }
    }
}

private let programmerGridModels = ["Novation Launchpad X", "Novation Launchpad Pro MK3", "Novation Launchpad Pro"]

@MainActor private func withProgrammerGrid(
    _ name: String, decks: [DeckID] = DeckID.allCases,
    _ body: (ControllerMIDIConnection) throws -> Void
) throws {
    let suite = "programmer-grid-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let profile = try #require(ControllerFactoryProfile.matching([name]))
    let port = profile.definition?.portAliases?.first ?? name
    let input = ControllerMIDIConnection(
        preferences: preferences, factoryPacketSender: { _, _ in true }, deckAvailability: { decks },
        factoryInputConnector: { _ in true })
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id + 100), name: name,
            identity: .init(id: id, device: UInt32(id), names: [name], portNames: [port]))
    }
    input.destinations = [20, 21].map { id in
        .init(
            id: id, reference: UInt32(id + 100), name: name,
            identity: .init(id: id, device: UInt32(id - 10), names: [name], portNames: [port]))
    }
    input.reconcileFactoryProfiles()
    if !profile.selectsAutomatically {
        #expect(!input.isInputActive(10) && !input.isInputActive(11))
        for source: Int32 in [10, 11] { input.select(source); input.applyFactoryProfile(profile) }
    }
    #expect(input.isInputActive(10) && input.isInputActive(11))
    try body(input)
}

@MainActor private func programmerGridPacket(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source); input.flushPendingActions()
}

@Test func controllerCatalogueProgrammerGridBoundsAbortToAutomaticPairedProfiles() throws {
    let base: [String: Any] = [
        "id": "abort fixture", "aliases": ["abort fixture"], "autoSelect": true, "source": "fixture",
        "scope": "fixture",
        "startup": [[0x90, 11, 0]], "shutdown": [[0x90, 11, 0]], "startupAbort": [[0x90, 11, 0]], "outputs": [],
        "inputs": [
            ["action": "playA", "kind": "note", "channel": 0, "number": 11, "encoding": "absolute", "inverted": false]
        ],
    ]
    func decode(_ p: [String: Any]) throws -> ControllerProfileCatalogue {
        try ControllerProfileCatalogue.decode(
            JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "profiles": [p]]))
    }
    #expect(try decode(base).profiles.first?.requiresPairedSetup == true)
    for (field, value): (String, Any) in [
        ("autoSelect", false), ("startup", []), ("shutdown", []), ("startupAbort", []),
        ("startupAbort", Array(repeating: [0x90, 11, 0], count: 5)), ("startupAbort", [[0x90, 11, 128]]),
        ("inputProtocol", "cdj101"),
    ] {
        var invalid = base; invalid[field] = value
        #expect(throws: (any Error).self) { try decode(invalid) }
    }
}

@Test(arguments: programmerGridModels) @MainActor
func controllerCatalogueProgrammerGridRoutesAllNativeQuadrantsAndPadSlots(_ name: String) throws {
    try withProgrammerGrid(name) { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        for (side, deck) in DeckID.allCases.enumerated() {
            let base = UInt8(11 + 4 * (side % 2) + 40 * (side / 2))
            for (offset, action): (UInt8, ControllerAction) in [
                (0, .playA), (2, .syncA), (3, .loadA), (10, .cueA), (11, .loopInA), (12, .loopOutA), (13, .reloopA),
            ] {
                events.removeAll();
                programmerGridPacket([0x90, base + offset, 127, base + offset, 127, base + offset, 0], input)
                #expect(events == [.init(action.assigned(to: deck), deck: deck)])
            }
            for slot in 0..<8 {
                let number = base + 20 + UInt8(10 * (slot / 4) + slot % 4)
                events.removeAll(); programmerGridPacket([0x90, number, 64, number, 127, number, 0], input)
                #expect(events.count == 1 && events.first?.action.hotcueSlot == slot && events.first?.deck == deck)
            }
        }
        events.removeAll()
        programmerGridPacket([0xB0, 11, 127, 0x91, 11, 127, 0x90, 9, 127, 90, 127, 99, 127], input)
        #expect(events.isEmpty)
    }
}

@Test(arguments: programmerGridModels) @MainActor
func controllerCatalogueProgrammerGridCueVelocityAndOwnershipRetainBothReleaseForms(_ name: String) throws {
    try withProgrammerGrid(name) { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in
            if target.action == .cuePreviewA || target.action == .cuePreviewB { events.append((target, value)) }
        }
        for (side, deck) in DeckID.allCases.enumerated() {
            let number = UInt8(12 + 4 * (side % 2) + 40 * (side / 2))
            for off: UInt8 in [0x80, 0x90] {
                events.removeAll()
                programmerGridPacket([0x90, number, 1, number, 127, 0xA0, number, 127], input)
                programmerGridPacket([0x90, number, 64], input, source: 11)
                programmerGridPacket([off, number, off == 0x80 ? 127 : 0], input)
                #expect(events.count == 1 && events.first?.1 == 1.0 / 127)
                programmerGridPacket([off, number, off == 0x80 ? 127 : 0], input, source: 11)
                #expect(events.map(\.1) == [1.0 / 127, 0] && events.allSatisfy { $0.0.deck == deck })
            }
        }
        programmerGridPacket([0x90, 12, 1], input)
        input.stop()
        #expect(events.suffix(2).map(\.1) == [1.0 / 127, 0])
    }
}

@Test(arguments: programmerGridModels) @MainActor func controllerCatalogueProgrammerGridCDBelongsToFourDeckOptIn(
    _ name: String
) throws {
    try withProgrammerGrid(name, decks: DeckID.primary) { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        programmerGridPacket([0x90, 51, 127, 51, 0, 55, 127, 55, 0, 71, 127, 71, 0, 75, 127, 75, 0], input)
        #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueProgrammerGridRejectsForeignPortsMissingOutputsAndAmbiguousPairs() throws {
    for (name, port): (String, String) in [("Launchpad X", "LPX MIDI"), ("Launchpad Pro MK3", "LPProMK3 MIDI")] {
        func endpoint(_ id: Int32, _ p: String) -> ControllerFactoryEndpoint {
            .init(id: id, device: 1, names: [name], portNames: [p])
        }
        for bad in [
            port.replacingOccurrences(of: "MIDI", with: "DAW"), port.replacingOccurrences(of: "MIDI", with: "DIN"),
            "MIDI 1",
        ] {
            #expect(
                ControllerFactorySession.discover(
                    sources: [endpoint(10, bad)], destinations: [endpoint(20, port)], disabled: []
                ).isEmpty)
        }
        #expect(
            ControllerFactorySession.discover(
                sources: [endpoint(10, port), endpoint(11, port)], destinations: [endpoint(20, port)], disabled: []
            ).isEmpty)
        let suite = "programmer-no-output-\(UUID().uuidString)"
        let preferences = UserDefaults(suiteName: suite)!
        defer { preferences.removePersistentDomain(forName: suite) }
        var writes = 0
        let input = ControllerMIDIConnection(
            preferences: preferences,
            factoryPacketSender: { _, _ in
                writes += 1; return true
            }, factoryInputConnector: { _ in true })
        input.sources = [.init(id: 10, reference: 100, name: name, identity: endpoint(10, port))]
        input.reconcileFactoryProfiles()
        #expect(!input.isInputActive(10) && writes == 0)
        var actions = 0; input.onAction = { _, _ in actions += 1 }
        programmerGridPacket([0x90, 11, 127, 11, 0], input)
        #expect(actions == 0)
    }
}

@Test(arguments: programmerGridModels) @MainActor
func controllerCatalogueProgrammerGridFeedbackIsStaticAndGenerationsStayDistinct(_ name: String) throws {
    let profile = try #require(ControllerFactoryProfile.matching([name]))
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 64 && data.outputs.count == 52 && data.audioOutput == nil)
    #expect(profile.selectsAutomatically == (name != "Novation Launchpad Pro"))
    for lamp in profile.feedback(destination: 20) {
        let on: UInt8 =
            lamp.action == .cuePreviewA || lamp.action == .cuePreviewB
            ? 5
            : lamp.action == .syncA || lamp.action == .syncB || lamp.action.hotcueSlot != nil ? 45 : 19
        #expect(lamp.message(value: 1) == [0x90, lamp.number, on])
        #expect(lamp.message(value: 0) == [0x90, lamp.number, 0])
    }
    for other in programmerGridModels where other != name {
        #expect(ControllerFactoryProfile.matching([other]) != profile)
    }
    #expect(ControllerFactoryProfile.matching([name + " clone"]) != profile)
}

@Test @MainActor func controllerCatalogueProgrammerGridClearsOnlyGridPadsAndExitsLiveOnStop() throws {
    for (name, port, model): (String, String, UInt8) in [
        ("Launchpad X", "LPX MIDI", 12), ("Launchpad Pro MK3", "LPProMK3 MIDI", 14),
    ] {
        let suite = "programmer-stop-\(UUID().uuidString)"
        let preferences = UserDefaults(suiteName: suite)!
        defer { preferences.removePersistentDomain(forName: suite) }
        var packets: [[UInt8]] = []
        let input = ControllerMIDIConnection(
            preferences: preferences,
            factoryPacketSender: { bytes, id in
                #expect(id == 20); packets.append(bytes); return true
            }, factoryInputConnector: { _ in true })
        input.sources = [
            .init(
                id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name], portNames: [port])
            )
        ]
        input.destinations = [
            .init(
                id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name], portNames: [port])
            )
        ]
        input.reconcileFactoryProfiles()
        let data = try #require(ControllerFactoryProfile.matching([name])?.definition)
        #expect(packets == data.startup && packets.first == [240, 0, 32, 41, 2, model, 14, 1, 247])
        let clears = Array(packets.dropFirst())
        let notes = clears.flatMap { packet in stride(from: 8, to: packet.count - 1, by: 3).map { packet[$0] } }
        var expected: Set<UInt8> = []
        for row in 0..<8 { for column in 0..<8 { expected.insert(UInt8(11 + 10 * row + column)) } }
        #expect(Set(notes) == expected)
        #expect(clears.allSatisfy { $0.count == 104 && ControllerMIDISetupStep.validMessage($0) })
        packets.removeAll(); input.stop()
        #expect(packets == data.shutdown && packets.last == [240, 0, 32, 41, 2, model, 14, 0, 247])
    }
}
