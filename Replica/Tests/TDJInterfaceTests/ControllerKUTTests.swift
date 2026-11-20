import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@Test func controllerCatalogueKUTManualUnbankedMixerWildcardHasNarrowSchemaBoundary() throws {
    let input: [String: Any] = [
        "action": "gainA", "kind": "control", "channel": 0, "number": 1,
        "encoding": "absolute", "inverted": false, "targetDeck": "a", "anyChannel": true,
    ]
    let fixture: [String: Any] = [
        "id": "manual mixer", "aliases": ["manual mixer"], "role": "accessory",
        "inputs": [input], "outputs": [], "startup": [], "shutdown": [], "autoSelect": false,
        "scope": "fixture", "source": "fixture",
    ]
    func decode(_ row: [String: Any]) throws -> ControllerProfileCatalogue {
        try ControllerProfileCatalogue.decode(
            JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "profiles": [row]]))
    }
    #expect(try decode(fixture).profiles.count == 1)
    for (key, value): (String, Any) in [
        ("autoSelect", true), ("role", "mixer"),
        ("startup", [[0x90, 1, 0]]), ("shutdown", [[0x80, 1, 0]]),
        ("inputModes", [["channel": 0, "initial": 1, "numbers": [1]]]),
        ("bankChanges", [["channel": 0, "number": 1, "anyPositive": true, "decks": ["a"]]]),
    ] {
        var row = fixture; row[key] = value
        #expect(throws: (any Error).self) { try decode(row) }
    }
    for (key, value): (String, Any) in [
        ("action", "playA"), ("action", "jogA"), ("kind", "note"),
        ("action", "filterKnobA"), ("encoding", "binaryOffset"), ("channel", 1), ("shifted", false),
        ("inverted", true), ("deckBank", 0),
    ] {
        var invalid = input; invalid[key] = value; var row = fixture; row["inputs"] = [invalid]
        #expect(throws: (any Error).self) { try decode(row) }
    }
    var duplicate = fixture; duplicate["inputs"] = [input, input]
    #expect(throws: (any Error).self) { try decode(duplicate) }
    var ordinary = input; ordinary["number"] = 2; ordinary["anyChannel"] = false
    duplicate["inputs"] = [input, ordinary]
    #expect(throws: (any Error).self) { try decode(duplicate) }
    var tooMany = fixture;
    tooMany["inputs"] = (0..<33).map { n in
        var r = input; r["number"] = n; return r
    }
    #expect(throws: (any Error).self) { try decode(tooMany) }
    var output = fixture;
    output["outputs"] = [
        [
            "action": "gainA", "kind": "control", "channel": 0, "number": 1,
            "onValue": 127, "offValue": 0, "offUsesNoteOn": true,
        ]
    ]
    #expect(throws: (any Error).self) { try decode(output) }
}

@MainActor private func withKUT(_ body: (ControllerMIDIConnection) throws -> Void) throws {
    let suite = "kut-\(UUID().uuidString)"; let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { _, _ in
            Issue.record("The KUT continuous subset must not send packets."); return false
        }, factoryInputConnector: { _ in true })
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id), name: "Reloop KUT",
            identity: .init(id: id, device: UInt32(id), names: ["Reloop KUT"]))
    }
    input.reconcileFactoryProfiles(); #expect(!input.isInputActive(10) && !input.isInputActive(11))
    let p = try #require(ControllerFactoryProfile.matching(["Reloop KUT"]))
    for source: Int32 in [10, 11] { input.select(source); input.applyFactoryProfile(p) }
    #expect(input.bindingCount == 28 && input.isInputActive(10) && input.isInputActive(11))
    try body(input)
}

@MainActor private func kutPacket(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source); input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueKUTOwnManualIdentityAndNoHardwareWrites() throws {
    let p = try #require(ControllerFactoryProfile.matching(["Reloop KUT"])); let d = try #require(p.definition)
    #expect(d.isValid && !p.selectsAutomatically && d.role == "accessory" && d.inputs.count == 14)
    #expect(d.outputs.isEmpty && d.startup.isEmpty && d.shutdown.isEmpty && d.audioOutput == nil)
    #expect(ControllerFactoryProfile.matching(["Reloop KUT"], automaticOnly: true) == nil)
    for other in ["Reloop RMX-90 DVS", "Reloop RMX-95", "Reloop ELITE"] {
        #expect(ControllerFactoryProfile.matching([other]) != p)
    }
    try withKUT { _ in }
}

@Test @MainActor func controllerCatalogueKUTAllFourteenControlsAcceptDocumentedBnOnEveryChannel() throws {
    for ch: UInt8 in 0..<16 {
        try withKUT { input in
            input.currentTargetValue = { _ in 0.5 }
            var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
            let p = try #require(ControllerFactoryProfile.matching(["Reloop KUT"]))
            for binding in p.bindings(source: 10) {
                events.removeAll(); kutPacket([0xB0 + ch, binding.number, 0], input); #expect(events.isEmpty)
                kutPacket([0xB0 + ch, binding.number, 64], input); kutPacket([0xB0 + ch, binding.number, 127], input)
                #expect(events.count == 2 && events.allSatisfy { $0.0 == binding.target } && events.last?.1 == 1)
            }
        }
    }
}

@Test @MainActor func controllerCatalogueKUTChannelChangesKeepSameControlButSourcesKeepSeparatePickup() throws {
    try withKUT { input in
        input.currentTargetValue = { _ in 0.5 }
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        kutPacket([0xB0, 1, 64], input); kutPacket([0xBF, 1, 127], input)
        #expect(events.count == 2 && events.allSatisfy { $0.0 == .init(.gainA, deck: .a) } && events.last?.1 == 1)
        events.removeAll(); kutPacket([0xBF, 1, 0], input, source: 11); #expect(events.isEmpty)
        kutPacket([0xB5, 1, 0], input); #expect(events.count == 1 && events.last?.1 == 0)
        events.removeAll();
        input.receive(.init(kind: .control, group: 1, channel: 0, number: 1, value: 127), source: 10)
        input.flushPendingActions(); #expect(events.isEmpty)
        kutPacket([0xB0, 1, 127], input, source: 99); #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueKUTPFLFaderStartFXAndOtherHardwareControlsStayInactive() throws {
    try withKUT { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        for ch: UInt8 in 0..<16 {
            for n: UInt8 in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 15, 16, 17] {
                kutPacket([0x90 + ch, n, 127, n, 0], input)
            }
            for n: UInt8 in [0, 6, 12, 14, 15, 17, 20, 21, 22, 23, 127] { kutPacket([0xB0 + ch, n, 127], input) }
        }
        #expect(events.isEmpty)
    }
}
