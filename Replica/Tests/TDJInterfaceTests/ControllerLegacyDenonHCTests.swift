import Foundation
import TDJCore
import Testing

@testable import TDJInterface

private let legacyHCModels = ["Denon DJ HC1000S", "Denon DJ HC4500"]
@MainActor private func withLegacyHC(_ name: String, _ body: (ControllerMIDIConnection) throws -> Void) throws {
    let suite = "legacy-hc-\(UUID().uuidString)"; let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    var writes = 0
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { _, _ in
            writes += 1; return true
        }, factoryInputConnector: { _ in true })
    input.sources = [10, 11].map { id in
        .init(id: id, reference: UInt32(id), name: name, identity: .init(id: id, device: UInt32(id), names: [name]))
    }
    input.reconcileFactoryProfiles(); #expect(input.isInputActive(10) && input.isInputActive(11) && writes == 0);
    try body(input)
}
@MainActor private func hcPacket(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source); input.flushPendingActions()
}

@Test(arguments: legacyHCModels) @MainActor
func controllerCatalogueLegacyHCKeepsOwnAutomaticMIDIIdentityAndNoSettingsOrAudioWrites(_ name: String) throws {
    let p = try #require(ControllerFactoryProfile.matching([name], automaticOnly: true));
    let d = try #require(p.definition)
    #expect(
        d.inputs.count == (name == legacyHCModels[0] ? 244 : 96)
            && d.outputs.count == (name == legacyHCModels[0] ? 48 : 42))
    #expect(d.startup.isEmpty && d.shutdown.isEmpty && d.audioOutput == nil && d.inputProtocol == nil)
    #expect(ControllerFactoryProfile.matching(["DN-HC5000"]) != p)
    #expect(ControllerFactoryProfile.matching(["Numark DMC2"]) != p)
}

@Test @MainActor func controllerCatalogueHC4500AllPresetPairsKeepPhysicalABAndPressure64CueReleases() throws {
    try withLegacyHC("Denon DJ HC4500") { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        for channel: UInt8 in 0..<6 {
            let deck: DeckID = channel % 2 == 0 ? .a : .b
            for off: UInt8 in [0x80 + channel, 0x90 + channel] {
                events.removeAll(); hcPacket([0x90 + channel, 66, 64, 66, 64, off, 66, off < 0x90 ? 64 : 0], input)
                #expect(
                    events.map(\.1) == [64.0 / 127, 0]
                        && events.allSatisfy {
                            $0.0 == .init(ControllerAction.cuePreviewA.assigned(to: deck), deck: deck)
                        })
            }
            for (number, action): (UInt8, ControllerAction) in [
                (67, .playA), (23, .hotcue1A), (24, .hotcue2A), (25, .hotcue3A), (32, .hotcue4A), (33, .hotcue5A),
                (55, .loopInA), (57, .loopOutA), (64, .reloopA), (40, .loadA),
            ] {
                events.removeAll(); hcPacket([0x90 + channel, number, 64, number, 64, number, 0], input)
                #expect(events.count == 1 && events.first?.0 == .init(action.assigned(to: deck), deck: deck))
            }
        }
    }
}

@Test @MainActor func controllerCatalogueHC4500SourceAndPresetChangesRetireOnlyOwnedContacts() throws {
    try withLegacyHC("Denon DJ HC4500") { input in
        var values: [Double] = [];
        input.onTargetAction = { target, value in if target.action == .cuePreviewA { values.append(value) } }
        hcPacket([0x90, 66, 64], input); hcPacket([0x90, 66, 64], input, source: 11)
        hcPacket([0x90, 49, 64], input); #expect(values == [64.0 / 127])
        hcPacket([0x92, 82, 64], input, source: 11); #expect(values == [64.0 / 127, 0])
        hcPacket([0x90, 66, 64], input); hcPacket([0x91, 49, 64], input);
        #expect(values == [64.0 / 127, 0, 64.0 / 127])
        input.stop(); #expect(values == [64.0 / 127, 0, 64.0 / 127, 0])
    }
}

@Test @MainActor func controllerCatalogueHC4500PitchUsesExactCentreReversePositionAndFreshPickup() throws {
    try withLegacyHC("Denon DJ HC4500") { input in
        input.currentTargetValue = { _ in 0.5 }; var events: [(ControllerActionTarget, Double)] = [];
        input.onTargetAction = { events.append(($0, $1)) }
        for channel: UInt8 in 0..<6 {
            let deck: DeckID = channel % 2 == 0 ? .a : .b
            events.removeAll(); hcPacket([0xE0 + channel, 0, 0], input); #expect(events.isEmpty)
            hcPacket([0xE0 + channel, 0, 64], input); hcPacket([0xE0 + channel, 127, 127], input)
            #expect(
                events.map(\.1) == [0.5, 0]
                    && events.allSatisfy { $0.0 == .init(ControllerAction.tempoA.assigned(to: deck), deck: deck) })
            events.removeAll(); hcPacket([0x90 + channel, 49, 64, 0xE0 + channel, 127, 127], input);
            #expect(events.isEmpty)
        }
    }
}

@Test @MainActor func controllerCatalogueHC1000AllChannelsKeepNativeShiftTransportAndFiveNormalHotCues() throws {
    try withLegacyHC("Denon DJ HC1000S") { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        for channel: UInt8 in 0..<4 {
            for (deck, numbers): (DeckID, [UInt8]) in [(.a, [23, 24, 25, 32, 33]), (.b, [117, 118, 119, 120, 121])] {
                for (number, action) in zip(
                    numbers, [ControllerAction.hotcue1A, .hotcue2A, .hotcue3A, .hotcue4A, .hotcue5A])
                {
                    events.removeAll(); hcPacket([0x90 + channel, number, 64, number, 64, number, 0], input)
                    #expect(events.count == 1 && events.first?.0 == .init(action.assigned(to: deck), deck: deck))
                }
                hcPacket([0x90 + channel, 96, 64], input)
                for (index, action) in [(1, ControllerAction.playA), (2, .syncA), (3, .loadA), (4, .cueA)] {
                    events.removeAll(); let number = numbers[index];
                    hcPacket([0x90 + channel, number, 64, number, 0], input)
                    #expect(events.count == 1 && events.first?.0 == .init(action.assigned(to: deck), deck: deck))
                }
                for off: UInt8 in [0x80 + channel, 0x90 + channel] {
                    events.removeAll();
                    hcPacket([0x90 + channel, numbers[0], 64, off, numbers[0], off < 0x90 ? 64 : 0], input)
                    #expect(
                        events.map(\.1) == [64.0 / 127, 0]
                            && events.allSatisfy {
                                $0.0 == .init(ControllerAction.cuePreviewA.assigned(to: deck), deck: deck)
                            })
                }
                hcPacket([0x80 + channel, 96, 64], input)
            }
        }
    }
}

@Test @MainActor func controllerCatalogueHC1000CrossChannelShiftReleaseClearsOnlyItsOwnHeldCue() throws {
    try withLegacyHC("Denon DJ HC1000S") { input in
        var values: [Double] = [];
        input.onTargetAction = { target, value in if target.action == .cuePreviewA { values.append(value) } }
        for source: Int32 in [10, 11] { hcPacket([0x90, 96, 64, 23, 64], input, source: source) }
        hcPacket([0x81, 96, 64], input); #expect(values == [64.0 / 127])
        hcPacket([0x83, 96, 64], input, source: 11); #expect(values == [64.0 / 127, 0])
        var actions: [ControllerAction] = []; input.onTargetAction = { target, _ in actions.append(target.action) }
        hcPacket([0x91, 24, 64, 24, 0], input); #expect(actions == [.hotcue2A])
    }
}

@Test(arguments: legacyHCModels) @MainActor
func controllerCatalogueLegacyHCStrictZeroForwardEncodersAndRejectedUnqualifiedWires(_ name: String) throws {
    try withLegacyHC(name) { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        let maximum: UInt8 = name == legacyHCModels[0] ? 4 : 6
        for channel: UInt8 in 0..<maximum {
            events.removeAll(); hcPacket([0xB0 + channel, 84, 1, 84, 63, 84, 64, 84, 65, 84, 126], input);
            #expect(events.isEmpty)
            hcPacket([0xB0 + channel, 84, 0], input); hcPacket([0xB0 + channel, 84, 127], input)
            #expect(
                events.map(\.1) == [0.5 + 1.0 / 126, 0.5 - 1.0 / 126] && events.allSatisfy { $0.0.action == .browse })
            if name == legacyHCModels[0] {
                for (number, deck): (UInt8, DeckID) in [(85, .a), (90, .b)] {
                    events.removeAll(); hcPacket([0xB0 + channel, number, 64], input); #expect(events.isEmpty)
                    hcPacket([0xB0 + channel, number, 0], input); hcPacket([0xB0 + channel, number, 127], input)
                    #expect(
                        events.map(\.1) == [0.5 + 1.0 / 126, 0.5 - 1.0 / 126]
                            && events.allSatisfy {
                                $0.0 == .init(ControllerAction.loopSizeA.assigned(to: deck), deck: deck)
                            })
                }
            }
        }
        events.removeAll()
        if name == legacyHCModels[0] {
            hcPacket([0x94, 23, 64, 24, 64, 0xB4, 84, 0, 0x90, 6, 64, 7, 64, 69, 64, 97, 64, 0xE0, 0, 64], input)
        } else {
            hcPacket(
                [0x96, 66, 64, 67, 64, 0xB6, 84, 0, 0x90, 4, 64, 5, 64, 7, 64, 56, 64, 81, 64, 0xB0, 81, 65, 83, 127],
                input)
        }
        #expect(events.isEmpty)
    }
}

@Test(arguments: legacyHCModels) @MainActor
func controllerCatalogueLegacyHCFeedbackKeepsOwnTriggerValuesAndSeparateOffController(_ name: String) throws {
    let p = try #require(ControllerFactoryProfile.matching([name])); let lamps = p.feedback(destination: 20)
    #expect(lamps.count == (name == legacyHCModels[0] ? 48 : 42))
    for lamp in lamps {
        #expect(lamp.kind == .control && lamp.number == 74 && lamp.offNumber == 75 && lamp.onValue == lamp.offValue)
        #expect(lamp.message(value: 1) == [0xB0 + lamp.channel, 74, lamp.onValue])
        #expect(lamp.message(value: 0) == [0xB0 + lamp.channel, 75, lamp.onValue])
    }
}

@Test @MainActor func controllerCatalogueLegacyHCSourceDefinitionsKeepEveryWireSchemaValid() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent()
    let data = try Data(
        contentsOf: root.appendingPathComponent("Sources/TDJInterface/Resources/factory-controller-profiles.json"))
    let raw = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any]);
    let profiles = try #require(raw["profiles"] as? [[String: Any]])
    for record in profiles where legacyHCModels.contains(record["id"] as? String ?? "") {
        let name = record["id"] as? String ?? "";
        let p = try JSONDecoder().decode(
            ControllerProfileData.self, from: JSONSerialization.data(withJSONObject: record))
        #expect(p.isValid, "Invalid full profile: \(name)")
        let rows = try #require(record["inputs"] as? [[String: Any]])
        for row in rows {
            var mini = record; mini["inputs"] = [row]; mini["outputs"] = []; mini["bankChanges"] = []
            let input = try JSONDecoder().decode(
                ControllerProfileData.self, from: JSONSerialization.data(withJSONObject: mini))
            #expect(input.isValid, "Invalid input: \(name) \(row["action"] ?? "") \(row["number"] ?? "")")
        }
        for row in try #require(record["outputs"] as? [[String: Any]]) {
            var mini = record; mini["inputs"] = [rows[0]]; mini["outputs"] = [row]; mini["bankChanges"] = []
            let output = try JSONDecoder().decode(
                ControllerProfileData.self, from: JSONSerialization.data(withJSONObject: mini))
            #expect(output.isValid, "Invalid output: \(name) \(row["action"] ?? "") \(row["number"] ?? "")")
        }
    }
}
