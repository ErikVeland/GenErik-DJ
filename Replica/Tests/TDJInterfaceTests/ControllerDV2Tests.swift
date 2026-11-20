import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@Test func controllerCatalogueDV2ManualMixerAllowsOnlyTwoQualifiedPFLButtons() throws {
    let control: [String: Any] = [
        "action": "gainA", "kind": "control", "channel": 0, "number": 47, "encoding": "absolute", "inverted": false,
        "targetDeck": "a", "anyChannel": true,
    ]
    let cue: [String: Any] = [
        "action": "cueA", "kind": "note", "channel": 0, "number": 9, "encoding": "absolute", "inverted": false,
        "targetDeck": "a", "anyChannel": true,
    ]
    let fixture: [String: Any] = [
        "id": "mixer PFL fixture", "aliases": ["mixer PFL fixture"], "role": "accessory", "autoSelect": false,
        "source": "fixture", "scope": "fixture", "startup": [], "shutdown": [], "outputs": [],
        "inputs": [control, cue],
    ]
    func decode(_ row: [String: Any]) throws -> ControllerProfileCatalogue {
        try ControllerProfileCatalogue.decode(
            JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "profiles": [row]]))
    }
    #expect(try decode(fixture).profiles.count == 1)
    for (key, value): (String, Any) in [
        ("action", "cuePreviewA"), ("action", "jogTouchA"), ("action", "playA"), ("kind", "control"),
        ("targetDeck", "c"), ("channel", 1), ("shifted", false), ("releaseOnly", true), ("pulse", true),
    ] {
        var invalid = cue; invalid[key] = value; var row = fixture; row["inputs"] = [control, invalid]
        #expect(throws: (any Error).self) { try decode(row) }
    }
    var duplicate = cue; duplicate["number"] = 10; var row = fixture; row["inputs"] = [control, cue, duplicate]
    #expect(throws: (any Error).self) { try decode(row) }
    row["inputs"] = [cue]; #expect(throws: (any Error).self) { try decode(row) }
    row = fixture; row["autoSelect"] = true; #expect(throws: (any Error).self) { try decode(row) }
    row = fixture; row["startup"] = [[0x90, 9, 0]]; #expect(throws: (any Error).self) { try decode(row) }
    row = fixture;
    row["outputs"] = [
        [
            "action": "cueA", "kind": "note", "channel": 0, "number": 9, "onValue": 127, "offValue": 0,
            "offUsesNoteOn": true, "targetDeck": "a",
        ]
    ]
    #expect(throws: (any Error).self) { try decode(row) }
}

@MainActor private func withDV2(_ body: (ControllerMIDIConnection) throws -> Void) throws {
    let suite = "dv2-\(UUID().uuidString)"; let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { _, _ in
            Issue.record("Manual DV2 input must not configure hardware."); return false
        }, factoryInputConnector: { _ in true })
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id), name: "DV2 USB WDM(MIDI) Device",
            identity: .init(id: id, device: UInt32(id), names: ["DV2 USB WDM(MIDI) Device"]))
    }
    input.reconcileFactoryProfiles(); #expect(!input.isInputActive(10) && !input.isInputActive(11))
    let p = try #require(ControllerFactoryProfile.matching(["DV2 USB"]))
    for source: Int32 in [10, 11] { input.select(source); input.applyFactoryProfile(p) }
    #expect(input.bindingCount == 32 && input.isInputActive(10) && input.isInputActive(11))
    try body(input)
}

@MainActor private func dv2Packet(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source); input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueDV2OwnManualIdentityHasNoSetupOutputsOrAutomaticAudio() throws {
    let p = try #require(ControllerFactoryProfile.matching(["DV2 USB WDM(MIDI) Device"]));
    let d = try #require(p.definition)
    #expect(d.isValid && !p.selectsAutomatically && d.inputs.count == 16 && d.outputs.isEmpty)
    #expect(d.startup.isEmpty && d.shutdown.isEmpty && d.audioOutput == nil)
    #expect(ControllerFactoryProfile.matching(["DV2 USB"], automaticOnly: true) == nil)
    #expect(ControllerFactoryProfile.matching(["DP2"]) != p)
    try withDV2 { _ in }
}

@Test @MainActor func controllerCatalogueDV2FourteenMixerControlsKeepPickupOnEveryDocumentedChannel() throws {
    let p = try #require(ControllerFactoryProfile.matching(["DV2 USB"]))
    let controls = p.bindings(source: 10).filter { $0.kind == .control }; #expect(controls.count == 14)
    for ch: UInt8 in 0..<16 {
        try withDV2 { input in
            input.currentTargetValue = { _ in 0.5 }
            var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
            for b in controls {
                events.removeAll(); dv2Packet([0xB0 + ch, b.number, 0], input); #expect(events.isEmpty)
                dv2Packet([0xB0 + ch, b.number, 64], input); dv2Packet([0xB0 + ch, b.number, 127], input)
                #expect(events.count == 2 && events.allSatisfy { $0.0 == b.target } && events.last?.1 == 1)
            }
        }
    }
}

@Test @MainActor func controllerCatalogueDV2PFLKeepsBothReleaseFormsAndRepeatedPressesAcrossChannels() throws {
    for ch: UInt8 in 0..<16 {
        try withDV2 { input in
            var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
            for (n, action, deck): (UInt8, ControllerAction, DeckID) in [(9, .cueA, .a), (10, .cueB, .b)] {
                for velocity: UInt8 in [1, 64, 127] {
                    for off: UInt8 in [0x80, 0x90] {
                        events.removeAll();
                        dv2Packet(
                            [
                                0x90 + ch, n, velocity, n, 127, off + ch, n, off == 0x80 ? 127 : 0, 0x90 + ch, n, 1, n,
                                0,
                            ], input)
                        #expect(
                            events.count == 2 && events.allSatisfy { $0.0 == .init(action, deck: deck) && $0.1 > 0 })
                    }
                }
            }
        }
    }
}

@Test @MainActor func controllerCatalogueDV2PickupAndButtonRearmingStaySourceOwned() throws {
    try withDV2 { input in
        input.currentTargetValue = { _ in 0.5 }
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        dv2Packet([0xBF, 58, 64], input); dv2Packet([0xBF, 58, 127], input); events.removeAll()
        dv2Packet([0xB5, 58, 0], input, source: 11); #expect(events.isEmpty)
        dv2Packet([0xB5, 58, 64], input, source: 11);
        #expect(events.count == 1 && events[0].0 == .init(.levelA, deck: .a))
        events.removeAll(); dv2Packet([0x90, 9, 127], input); dv2Packet([0x90, 9, 0], input, source: 11)
        dv2Packet([0x90, 9, 127], input); #expect(events.count == 1)
        dv2Packet([0x80, 9, 127, 0x90, 9, 1, 9, 0], input); #expect(events.count == 2)
    }
}

@Test @MainActor func controllerCatalogueDV2MicKillsCurvesReverseAndQStartRemainInactive() throws {
    try withDV2 { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        for ch: UInt8 in 0..<16 {
            for n: UInt8 in [0, 1, 2, 3, 4, 5, 6, 7, 8, 11, 12, 13, 14, 15, 16, 32, 33, 127] {
                dv2Packet([0x90 + ch, n, 127, n, 0], input)
            }
            for n: UInt8 in [0, 1, 9, 10, 43, 44, 45, 46, 61, 62, 63, 127] { dv2Packet([0xB0 + ch, n, 127], input) }
            dv2Packet([0xE0 + ch, 0, 64], input)
        }
        dv2Packet([0x90, 9, 127, 0xB0, 58, 64], input, source: 999)
        input.receive(.init(kind: .note, group: 1, channel: 0, number: 9, value: 127), source: 10)
        input.receive(.init(kind: .control, group: 1, channel: 0, number: 58, value: 64), source: 10);
        input.flushPendingActions()
        #expect(events.isEmpty)
    }
}
