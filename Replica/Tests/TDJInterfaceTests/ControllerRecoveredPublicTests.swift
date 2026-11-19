import Foundation
import TDJCore
import Testing

@testable import TDJInterface

private let recoveredModels = ["Numark NVII", "Denon DJ PRIME GO+", "American Audio DP2"]
@MainActor private func withRecovered(_ name: String, _ body: (ControllerMIDIConnection) throws -> Void) throws {
    let suite = "recovered-\(UUID().uuidString)"; let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    var writes = 0
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { _, _ in
            writes += 1; return true
        }, deckAvailability: { DeckID.allCases }, factoryInputConnector: { _ in true })
    input.sources = [10, 11].map { id in
        .init(id: id, reference: UInt32(id), name: name, identity: .init(id: id, device: UInt32(id), names: [name]))
    }
    input.reconcileFactoryProfiles()
    if name != recoveredModels[2] {
        #expect(!input.isInputActive(10) && !input.isInputActive(11))
        let p = try #require(ControllerFactoryProfile.matching([name]));
        for source: Int32 in [10, 11] { input.select(source); input.applyFactoryProfile(p) }
        #expect(input.bindingCount == p.bindings(source: 10).count * 2)
    }
    #expect(input.isInputActive(10) && input.isInputActive(11) && writes == 0)
    try body(input)
}
@MainActor private func recoveredPacket(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source); input.flushPendingActions()
}

@Test(arguments: recoveredModels) @MainActor func controllerCatalogueRecoveredPublicIdentityAndCapacity(_ name: String)
    throws
{
    let p = try #require(ControllerFactoryProfile.matching([name])); let d = try #require(p.definition)
    #expect(d.inputs.count == (name == recoveredModels[0] ? 77 : name == recoveredModels[1] ? 45 : 108))
    #expect(p.selectsAutomatically == (name == recoveredModels[2]))
    #expect(d.startup.isEmpty && d.shutdown.isEmpty && d.audioOutput == nil && d.inputProtocol == nil)
    for other in ["Numark NV", "Denon DJ PRIME GO", "Synq PCM-1", "DMC2"] {
        #expect(ControllerFactoryProfile.matching([other]) != p)
    }
    try withRecovered(name) { _ in }
}

@Test(arguments: recoveredModels) @MainActor func controllerCatalogueRecoveredPublicCueBothReleasesKeepSourceOwnership(
    _ name: String
) throws {
    try withRecovered(name) { input in
        let ch: UInt8 = name == recoveredModels[0] ? 1 : name == recoveredModels[1] ? 2 : 0
        let cue: UInt8 = name == recoveredModels[0] ? 32 : name == recoveredModels[1] ? 9 : 25
        var values: [Double] = [];
        input.onTargetAction = { target, value in
            if target.action == .cuePreviewA && target.deck == .a { values.append(value) }
        }
        for off: UInt8 in [0x80 + ch, 0x90 + ch] {
            values.removeAll(); recoveredPacket([0x90 + ch, cue, 127, cue, 127], input);
            recoveredPacket([0x90 + ch, cue, 127], input, source: 11)
            recoveredPacket([off, cue, off < 0x90 ? 127 : 0], input); #expect(values == [1])
            recoveredPacket([off, cue, off < 0x90 ? 127 : 0], input, source: 11); #expect(values == [1, 0])
        }
        recoveredPacket([0x90 + ch, cue, 127], input); input.stop(); #expect(values == [1, 0, 1, 0])
    }
}

@Test @MainActor func controllerCatalogueRecoveredNVIISideSelectorsAndPhysicalShiftAliasesRetireOwnedHolds() throws {
    try withRecovered("Numark NVII") { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        for ch: UInt8 in 1...4 {
            let deck = DeckID.allCases[Int(ch) - 1]
            for (n, action): (UInt8, ControllerAction) in [
                (33, .playA), (32, .cuePreviewA), (31, .syncA), (5, .loadA), (16, .pitchBendDownA), (17, .pitchBendUpA),
            ] {
                events.removeAll(); recoveredPacket([0x90 + ch, n, 127, n, 127, 0x80 + ch, n, 127], input)
                #expect(events.first?.0 == .init(action.assigned(to: deck), deck: deck))
                #expect(events.map(\.1) == (action.isMomentary ? [1, 0] : [1]))
            }
        }
        events.removeAll(); recoveredPacket([0x91, 32, 127, 0x92, 32, 127], input)
        recoveredPacket([0xB0, 29, 2], input); #expect(events.count == 2)
        recoveredPacket([0xB0, 29, 1], input);
        #expect(events.count == 3 && events.last?.0.deck == .a && events.last?.1 == 0)
        recoveredPacket([0xB0, 30, 0], input);
        #expect(events.count == 4 && events.last?.0.deck == .b && events.last?.1 == 0)
        events.removeAll(); recoveredPacket([0x91, 13, 127, 0x92, 13, 127, 0x83, 13, 127, 0x91, 33, 127, 33, 0], input)
        #expect(events.isEmpty)
        recoveredPacket([0x84, 13, 127, 0x91, 33, 127, 33, 0], input);
        #expect(events.count == 1 && events.first?.0.action == .playA)
    }
}

@Test @MainActor func controllerCatalogueRecoveredGOPlusStrictEncodersAndShiftSuppressUnsupportedTransport() throws {
    try withRecovered("Denon DJ PRIME GO+") { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        for (status, number, action, deck): (UInt8, UInt8, ControllerAction, DeckID?) in [
            (0xBF, 5, .browse, nil), (0xB2, 32, .loopSizeA, .a), (0xB3, 32, .loopSizeB, .b),
        ] {
            events.removeAll();
            for v: UInt8 in [0, 2, 63, 64, 65, 126] { recoveredPacket([status, number, v], input) };
            #expect(events.isEmpty)
            recoveredPacket([status, number, 1], input); recoveredPacket([status, number, 127], input)
            #expect(
                events.map(\.1) == [0.5 + 1.0 / 126, 0.5 - 1.0 / 126]
                    && events.allSatisfy { $0.0.action == action && $0.0.deck == deck })
        }
        events.removeAll(); recoveredPacket([0x92, 9, 127, 0x9F, 8, 127], input); #expect(events.map(\.1) == [1, 0])
        events.removeAll();
        recoveredPacket([0x92, 10, 127, 10, 0, 0xBF, 12, 127, 13, 127, 0xB2, 31, 127, 75, 127, 0xB2, 32, 1], input);
        #expect(events.isEmpty)
        recoveredPacket([0x8F, 8, 127, 0x92, 10, 127, 10, 0], input);
        #expect(events.count == 1 && events.first?.0.action == .playA)
    }
}

@Test @MainActor func controllerCatalogueRecoveredDP2HardwareShiftFamiliesGuardPositiveCommandsAndRetireCue() throws {
    try withRecovered("American Audio DP2") { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        for ch: UInt8 in 0...1 {
            let deck: DeckID = ch == 0 ? .a : .b
            for n: UInt8 in [26, 25, 56, 57, 53, 61, 22, 23, 24, 59, 60, 9, 10, 11, 12] {
                events.removeAll(); recoveredPacket([0x90 + ch, n, 127, 0x80 + ch + 3, n, 127], input)
                #expect(!events.isEmpty && events.first?.0.deck == deck)
                events.removeAll(); recoveredPacket([0x90 + ch + 3, n, 127, n, 0], input); #expect(events.isEmpty)
            }
            events.removeAll(); recoveredPacket([0x90 + ch, 25, 127, 55, 127], input);
            #expect(events.map(\.1) == [1, 0])
            events.removeAll(); recoveredPacket([0x90 + ch, 26, 127, 26, 0], input); #expect(events.isEmpty)
            recoveredPacket([0x80 + ch + 3, 55, 127, 0x90 + ch, 26, 127, 26, 0], input); #expect(events.count == 1)
        }
    }
}

@Test @MainActor func controllerCatalogueRecoveredDP2ManufacturerMixerPitchAndBrowserKeepIndependentAddresses() throws {
    try withRecovered("American Audio DP2") { input in
        input.currentTargetValue = { _ in 0.5 }; var events: [(ControllerActionTarget, Double)] = [];
        input.onTargetAction = { events.append(($0, $1)) }
        recoveredPacket([0xB0, 19, 64], input); #expect(events.isEmpty)
        for (status, n, action): (UInt8, UInt8, ControllerAction) in [
            (0xB0, 20, .highA), (0xB1, 20, .highB), (0xB0, 21, .lowA), (0xB1, 21, .lowB), (0xB0, 22, .levelA),
            (0xB1, 22, .levelB), (0xB1, 19, .master), (0xB2, 2, .cueMix), (0xB2, 3, .monitor), (0xB2, 5, .crossfader),
        ] {
            events.removeAll(); recoveredPacket([status, n, 0], input); #expect(events.isEmpty);
            recoveredPacket([status, n, 64], input); #expect(events.count == 1 && events.first?.0.action == action)
        }
        for ch: UInt8 in 0...1 {
            events.removeAll(); recoveredPacket([0xB0 + ch, 18, 127], input); #expect(events.isEmpty)
            recoveredPacket([0xB0 + ch, 18, 64], input); recoveredPacket([0xB0 + ch, 18, 0], input)
            #expect(events.count == 2 && events.first?.1 == 63.0 / 127 && events.last?.1 == 1)
        }
        events.removeAll(); for v: UInt8 in [0, 1, 64, 127] { recoveredPacket([0xB2, 1, v], input) };
        #expect(events.isEmpty)
        recoveredPacket([0xB2, 1, 65], input); recoveredPacket([0xB2, 1, 63], input);
        #expect(events.map(\.1) == [0.5 + 1.0 / 126, 0.5 - 1.0 / 126])
    }
}

@Test @MainActor func controllerCatalogueRecoveredDP2ManufacturerLampsKeepOwnNoteAndSteadyValues() throws {
    let p = try #require(ControllerFactoryProfile.matching(["American Audio DP2"]));
    let lamps = p.feedback(destination: 20); #expect(lamps.count == 18)
    for lamp in lamps {
        #expect(lamp.kind == .note && lamp.channel < 2 && [9, 10, 11, 12, 25, 26, 53, 56, 57].contains(lamp.number))
        #expect(
            lamp.message(value: 1) == [0x90 + lamp.channel, lamp.number, 127]
                && lamp.message(value: 0) == [0x90 + lamp.channel, lamp.number, 0])
    }
}

@Test @MainActor func controllerCatalogueRecoveredSelectorSchemaAcceptsDisjointControlValuesOnly() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent()
    let data = try Data(
        contentsOf: root.appendingPathComponent("Sources/TDJInterface/Resources/factory-controller-profiles.json"))
    let raw = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any]);
    let records = try #require(raw["profiles"] as? [[String: Any]])
    for record in records where recoveredModels.contains(record["id"] as? String ?? "") {
        let p = try JSONDecoder().decode(
            ControllerProfileData.self, from: JSONSerialization.data(withJSONObject: record));
        #expect(p.isValid, "Invalid profile: \(p.id)")
    }
    let nv = try #require(records.first { $0["id"] as? String == "Numark NVII" });
    let changes = try #require(nv["bankChanges"] as? [[String: Any]])
    let control = try #require(changes.first { $0["kind"] as? String == "control" });
    let note = try #require(changes.first { $0["kind"] == nil })
    for bad in [[control, control], [note, note], [control, control.filter { $0.key != "onValue" }]] {
        var record = nv; record["bankChanges"] = bad
        let p = try JSONDecoder().decode(
            ControllerProfileData.self, from: JSONSerialization.data(withJSONObject: record));
        #expect(!p.isValid)
    }
}
