import Foundation
import TDJCore
import Testing

@testable import TDJInterface
private let legacyStandaloneModels = ["Denon DJ HD2500", "Stanton SCS.4DJ", "Gemini FirstMix I/O"]

@MainActor private func withStandalone(_ name: String, _ body: (ControllerMIDIConnection) throws -> Void) throws {
    let suite = "standalone-\(UUID().uuidString)"; let preferences = UserDefaults(suiteName: suite)!
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
    if name == legacyStandaloneModels[0] {
        #expect(!input.isInputActive(10) && !input.isInputActive(11))
        let p = try #require(ControllerFactoryProfile.matching([name]))
        for source: Int32 in [10, 11] { input.select(source); input.applyFactoryProfile(p) }
        #expect(input.bindingCount == 48)
    }
    #expect(input.isInputActive(10) && input.isInputActive(11) && writes == 0); try body(input)
}
@MainActor private func standalonePacket(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source); input.flushPendingActions()
}

@Test func controllerCatalogueLegacyStandaloneDefinitionsAndUnsignedCountSchemaStayBounded() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent()
    let data = try Data(
        contentsOf: root.appendingPathComponent("Sources/TDJInterface/Resources/factory-controller-profiles.json"))
    let raw = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any]);
    let records = try #require(raw["profiles"] as? [[String: Any]])
    for record in records where legacyStandaloneModels.contains(record["id"] as? String ?? "") {
        let p = try JSONDecoder().decode(
            ControllerProfileData.self, from: JSONSerialization.data(withJSONObject: record));
        #expect(p.isValid, "Invalid standalone: \(p.id)")
    }
    let source = try #require(records.first { $0["id"] as? String == legacyStandaloneModels[2] })
    let rows = try #require(source["inputs"] as? [[String: Any]]);
    let jog = try #require(rows.first { $0["encoding"] as? String == "unsignedCount" })
    for fields in [["kind": "note"], ["requiresTouch": false], ["action": "tempoA"], ["argument": 0]] as [[String: Any]]
    {
        var record = source; record["inputs"] = [jog.merging(fields) { _, value in value }]
        let p = try JSONDecoder().decode(
            ControllerProfileData.self, from: JSONSerialization.data(withJSONObject: record));
        #expect(!p.isValid)
    }
}

@Test(arguments: legacyStandaloneModels) @MainActor
func controllerCatalogueLegacyStandaloneIdentityAndCuePressureOwnership(_ name: String) throws {
    let index = try #require(legacyStandaloneModels.firstIndex(of: name));
    let p = try #require(ControllerFactoryProfile.matching([name])); let d = try #require(p.definition)
    #expect(
        p.selectsAutomatically == (index != 0) && d.inputs.count == [24, 44, 31][index]
            && d.outputs.count == [4, 6, 8][index])
    #expect(d.startup.isEmpty && d.shutdown.isEmpty && d.audioOutput == nil)
    if index == 2 {
        #expect(
            ControllerFactoryProfile.matching(["Gemini FirstMix"]) != p
                && ControllerFactoryProfile.matching(["FirstMix Pro"]) != p)
    }
    try withStandalone(name) { input in
        let cue: UInt8 = [66, 38, 6][index]; let pressure: UInt8 = index == 0 ? 64 : 127
        var values: [Double] = [];
        input.onTargetAction = { target, value in if target.action == .cuePreviewA { values.append(value) } }
        for off: UInt8 in [0x80, 0x90] {
            values.removeAll(); standalonePacket([0x90, cue, pressure, cue, pressure], input)
            standalonePacket([0x90, cue, pressure], input, source: 11)
            standalonePacket([off, cue, off == 0x80 ? pressure : 0], input); #expect(values == [Double(pressure) / 127])
            standalonePacket([off, cue, off == 0x80 ? pressure : 0], input, source: 11);
            #expect(values == [Double(pressure) / 127, 0])
        }
        values.removeAll(); standalonePacket([0x90, cue, pressure], input)
        if index == 0 { standalonePacket([0x91, 49, 64], input) } else { input.stop() }
        #expect(values == [Double(pressure) / 127, 0])
    }
}

@Test @MainActor func controllerCatalogueLegacyStandaloneFirstMixIODirectionalCountsRetainSignAndOwnedContact() throws {
    try withStandalone("Gemini FirstMix I/O") { input in
        var jogs: [ControllerMIDIValue] = [];
        input.onJogAction = { target, value in
            #expect(target.argument == 350 && target.deck == .a); jogs.append(value)
        }
        standalonePacket([0xB0, 1, 5, 20, 7], input); #expect(jogs.isEmpty)
        standalonePacket([0x90, 23, 127], input)
        for (number, count): (UInt8, UInt8) in [
            (1, 1), (20, 1), (1, 127), (20, 127), (1, 64), (20, 64), (1, 0), (20, 0),
        ] { standalonePacket([0xB0, number, count], input) }
        #expect(jogs == [.relative(-1), .relative(1), .relative(-127), .relative(127), .relative(-64), .relative(64)])
        standalonePacket([0x80, 23, 127, 0xB0, 20, 5], input); #expect(jogs.count == 6)
    }
}

@Test(arguments: ["Denon DJ HD2500", "Stanton SCS.4DJ"]) @MainActor
func controllerCatalogueLegacyStandaloneManufacturerContactAndRelativeWheels(_ name: String) throws {
    try withStandalone(name) { input in
        let hd = name == legacyStandaloneModels[0]; let contact: UInt8 = hd ? 81 : 44; let wheel: UInt8 = hd ? 81 : 13
        var jogs: [ControllerMIDIValue] = [];
        input.onJogAction = { target, value in
            #expect(target.argument == (hd ? 1480 : 256)); jogs.append(value)
        }
        standalonePacket([0xB0, wheel, 69], input); #expect(jogs.isEmpty)
        standalonePacket([0x90, contact, hd ? 64 : 127, 0xB0, wheel, 69], input); #expect(jogs == [.relative(5)])
        standalonePacket([0x80, contact, 127, 0xB0, wheel, 69], input); #expect(jogs.count == 1)
    }
}

@Test(arguments: legacyStandaloneModels) @MainActor
func controllerCatalogueLegacyStandaloneIndependentControlsAndExactLampPackets(_ name: String) throws {
    let p = try #require(ControllerFactoryProfile.matching([name]))
    for lamp in p.feedback(destination: 20) {
        if name == legacyStandaloneModels[0] {
            #expect(lamp.message(value: 1) == [0xB0 + lamp.channel, 74, lamp.onValue])
            #expect(lamp.message(value: 0) == [0xB0 + lamp.channel, 75, lamp.onValue])
        } else {
            #expect(
                lamp.message(value: 1) == [0x90, lamp.number, 127] && lamp.message(value: 0) == [0x90, lamp.number, 0])
        }
    }
    try withStandalone(name) { input in
        input.currentTargetValue = { _ in 0.5 }; var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        if name == legacyStandaloneModels[0] {
            for value: UInt8 in [1, 63, 64, 65, 126] { standalonePacket([0xB0, 84, value], input) };
            #expect(events.isEmpty)
            standalonePacket([0xB0, 84, 0], input); standalonePacket([0xB0, 84, 127], input);
            #expect(events.map(\.1) == [0.5 + 1.0 / 126, 0.5 - 1.0 / 126])
        } else if name == legacyStandaloneModels[2] {
            standalonePacket([0xB0, 10, 64], input); #expect(events.count == 1 && events.first?.0.action == .gainA)
            events.removeAll(); standalonePacket([0xB0, 18, 64], input);
            #expect(events.count == 1 && events.first?.0.action == .master)
            events.removeAll(); standalonePacket([0x90, 3, 127, 3, 0, 2, 127, 2, 0], input);
            #expect(events.map { $0.0.action } == [.browsePrevious, .browseNext])
        } else {
            standalonePacket([0x90, 5, 127, 7, 127, 6, 127, 8, 127], input); #expect(events.isEmpty)
            standalonePacket([0xB0, 17, 64], input); #expect(events.count == 1 && events.first?.0.action == .levelA)
        }
    }
}
