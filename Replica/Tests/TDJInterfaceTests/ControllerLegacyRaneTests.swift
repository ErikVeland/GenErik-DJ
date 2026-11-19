import Foundation
import TDJCore
import Testing

@testable import TDJInterface
private let legacyRaneModels = ["Rane SIXTY TWO", "Rane SIXTY FOUR", "Rane TTM57 MKII"]

@Test func controllerCatalogueLegacyRaneDefinitionsKeepQualifiedEncoderSchema() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent()
    let data = try Data(
        contentsOf: root.appendingPathComponent("Sources/TDJInterface/Resources/factory-controller-profiles.json"))
    let raw = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any]);
    let records = try #require(raw["profiles"] as? [[String: Any]])
    for record in records where legacyRaneModels.contains(record["id"] as? String ?? "") {
        let p = try JSONDecoder().decode(
            ControllerProfileData.self, from: JSONSerialization.data(withJSONObject: record));
        #expect(p.isValid, "Invalid profile: \(p.id)")
    }
    let source = try #require(records.first { $0["id"] as? String == legacyRaneModels[0] });
    let inputs = try #require(source["inputs"] as? [[String: Any]])
    let encoder = try #require(inputs.first { ($0["action"] as? String)?.hasPrefix("loopSize") == true })
    var record = source; record["bankChanges"] = []; record["outputs"] = []
    for change in [["kind": "note"], ["argument": 1.0]] as [[String: Any]] {
        record["inputs"] = [encoder.merging(change) { _, value in value }]
        let p = try JSONDecoder().decode(
            ControllerProfileData.self, from: JSONSerialization.data(withJSONObject: record));
        #expect(!p.isValid)
    }
}

@MainActor private func withLegacyRane(_ name: String, _ body: (ControllerMIDIConnection) throws -> Void) throws {
    let suite = "legacy-rane-\(UUID().uuidString)"; let preferences = UserDefaults(suiteName: suite)!
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
    input.reconcileFactoryProfiles(); #expect(!input.isInputActive(10) && !input.isInputActive(11))
    let p = try #require(ControllerFactoryProfile.matching([name]));
    for source: Int32 in [10, 11] { input.select(source); input.applyFactoryProfile(p) }
    #expect(
        input.isInputActive(10) && input.isInputActive(11) && writes == 0
            && input.bindingCount == p.bindings(source: 10).count * 2)
    try body(input)
}
@MainActor private func raneLegacyPacket(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source); input.flushPendingActions()
}

@Test(arguments: legacyRaneModels) @MainActor func controllerCatalogueLegacyRaneOwnManualIdentityCapacityAndNoSetup(
    _ name: String
) throws {
    let p = try #require(ControllerFactoryProfile.matching([name])); let d = try #require(p.definition)
    #expect(
        !p.selectsAutomatically
            && d.inputs.count == (name == legacyRaneModels[0] ? 44 : name == legacyRaneModels[1] ? 83 : 24))
    #expect(d.outputs.count == (name == legacyRaneModels[0] ? 14 : name == legacyRaneModels[1] ? 39 : 0))
    #expect(d.startup.isEmpty && d.shutdown.isEmpty && d.audioOutput == nil && d.inputProtocol == nil)
    for other in ["Rane Seventy", "Rane Seventy-Two", "Rane Seventy-Two MKII", "TTM57SL"] {
        #expect(ControllerFactoryProfile.matching([other]) != p)
    }
    try withLegacyRane(name) { _ in }
}

@Test(arguments: legacyRaneModels) @MainActor
func controllerCatalogueLegacyRaneOwnMixerStripsKeepPhysicalTargetsAndPickup(_ name: String) throws {
    try withLegacyRane(name) { input in
        input.currentTargetValue = { _ in 0.5 }; var events: [(ControllerActionTarget, Double)] = [];
        input.onTargetAction = { events.append(($0, $1)) }
        let ttm = name == legacyRaneModels[2]
        let strips: [(DeckID, UInt8, [UInt8])] =
            ttm
            ? [(.a, 0, [22, 23, 24, 25, 26, 28]), (.b, 1, [22, 23, 24, 25, 26, 28])]
            : name == legacyRaneModels[0]
                ? [(.a, 0, [89, 101, 77, 71, 65, 83]), (.b, 0, [90, 102, 78, 72, 66, 84])]
                : [
                    (.c, 0, [89, 101, 77, 71, 65, 83]), (.a, 0, [90, 102, 78, 72, 66, 84]),
                    (.b, 0, [91, 103, 79, 73, 67, 85]), (.d, 0, [92, 104, 80, 74, 68, 86]),
                ]
        for (deck, ch, numbers) in strips {
            for (n, action) in zip(numbers, [ControllerAction.gainA, .highA, .midA, .lowA, .filterKnobA, .levelA]) {
                events.removeAll(); raneLegacyPacket([0xB0 + ch, n, 0], input); #expect(events.isEmpty);
                raneLegacyPacket([0xB0 + ch, n, 64], input)
                #expect(events.count == 1 && events.first?.0 == .init(action.assigned(to: deck), deck: deck))
            }
        }
        let globals: [(UInt8, UInt8, ControllerAction)] =
            ttm
            ? [(15, 8, .crossfader), (14, 35, .master), (14, 47, .monitor), (14, 39, .cueMix)]
            : [(0, 0, .crossfader), (0, 93, .master), (0, 99, .monitor), (0, 105, .cueMix)]
        for (ch, n, action) in globals {
            events.removeAll(); raneLegacyPacket([0xB0 + ch, n, 0], input); #expect(events.isEmpty);
            raneLegacyPacket([0xB0 + ch, n, 64], input); #expect(events.count == 1 && events.first?.0.action == action)
        }
    }
}

@Test(arguments: legacyRaneModels) @MainActor func controllerCatalogueLegacyRaneSourceReportsResetOnlyOwnedPickup(
    _ name: String
) throws {
    try withLegacyRane(name) { input in
        input.currentTargetValue = { _ in 0.5 }; var events: [(ControllerActionTarget, Double)] = [];
        input.onTargetAction = { events.append(($0, $1)) }
        let ttm = name == legacyRaneModels[2]
        let highA: UInt8 = ttm ? 23 : name == legacyRaneModels[0] ? 101 : 102
        let highB: UInt8 = ttm ? 23 : name == legacyRaneModels[0] ? 102 : 103
        let bStatus: UInt8 = ttm ? 0xB1 : 0xB0
        raneLegacyPacket([0xB0, highA, 64, bStatus, highB, 64], input);
        raneLegacyPacket([0xB0, highA, 64], input, source: 11)
        events.removeAll()
        if ttm {
            raneLegacyPacket([0xBE, 32, 4], input)
        } else {
            raneLegacyPacket([0xB0, name == legacyRaneModels[0] ? 116 : 117, 2], input)
        }
        raneLegacyPacket([0xB0, highA, 127], input); #expect(events.isEmpty)
        raneLegacyPacket([0xB0, highA, 127], input, source: 11);
        #expect(events.count == 1 && events.first?.0.action == .highA)
        events.removeAll(); raneLegacyPacket([bStatus, highB, 127], input)
        #expect(events.count == (ttm ? 0 : 1))
    }
}

@Test(arguments: legacyRaneModels) @MainActor func controllerCatalogueLegacyRaneLoopEncodersPreserveDocumentedCounts(
    _ name: String
) throws {
    try withLegacyRane(name) { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        let ttm = name == legacyRaneModels[2]
        let loops: [(UInt8, UInt8, DeckID)] =
            ttm
            ? [(4, 52, .a), (5, 52, .b)]
            : name == legacyRaneModels[0]
                ? [(0, 17, .a), (0, 44, .a), (0, 19, .b), (0, 45, .b)]
                : [(0, 44, .a), (0, 19, .b), (0, 17, .c), (0, 45, .d)]
        for (ch, n, deck) in loops {
            events.removeAll(); raneLegacyPacket([0xB0 + ch, n, 65], input);
            raneLegacyPacket([0xB0 + ch, n, 63], input)
            #expect(
                events.map(\.1) == [0.5 + 1.0 / 126, 0.5 - 1.0 / 126]
                    && events.allSatisfy { $0.0 == .init(ControllerAction.loopSizeA.assigned(to: deck), deck: deck) })
            events.removeAll(); raneLegacyPacket([0xB0 + ch, n, 69], input);
            raneLegacyPacket([0xB0 + ch, n, 59], input)
            #expect(events.map(\.1) == (ttm ? [] : [0.5 + 5.0 / 126, 0.5 - 5.0 / 126]))
        }
    }
}

@Test(arguments: legacyRaneModels) @MainActor func controllerCatalogueLegacyRaneOwnLibraryChannelsAndLoadTargets(
    _ name: String
) throws {
    try withLegacyRane(name) { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        let ttm = name == legacyRaneModels[2]
        let loads: [(UInt8, UInt8, DeckID)] =
            ttm
            ? [(15, 2, .a), (15, 3, .b)]
            : name == legacyRaneModels[0]
                ? [(0, 44, .a), (0, 55, .b)] : [(0, 123, .a), (0, 55, .b), (0, 44, .c), (0, 124, .d)]
        for (ch, n, deck) in loads {
            events.removeAll(); raneLegacyPacket([0x90 + ch, n, 127, n, 127, n, 0], input)
            #expect(
                events.count == 1 && events.first?.0 == .init(ControllerAction.loadA.assigned(to: deck), deck: deck))
        }
        let browses: [UInt8] = ttm ? [0] : name == legacyRaneModels[0] ? [16, 18] : [10, 18, 16, 11]
        for n in browses {
            events.removeAll(); raneLegacyPacket([ttm ? 0xBF : 0xB0, n, 65], input);
            raneLegacyPacket([ttm ? 0xBF : 0xB0, n, 63], input)
            #expect(
                events.map(\.1) == [0.5 + 1.0 / 126, 0.5 - 1.0 / 126] && events.allSatisfy { $0.0.action == .browse })
        }
    }
}

@Test(arguments: legacyRaneModels) @MainActor
func controllerCatalogueLegacyRaneOnlyQualifiedPadsAndSoftwareLampsAreUsed(_ name: String) throws {
    let p = try #require(ControllerFactoryProfile.matching([name])); let lamps = p.feedback(destination: 20)
    #expect(lamps.count == (name == legacyRaneModels[0] ? 14 : name == legacyRaneModels[1] ? 39 : 0))
    for lamp in lamps {
        #expect(
            lamp.kind == .note && lamp.channel == 0 && lamp.message(value: 1) == [0x90, lamp.number, 64]
                && lamp.message(value: 0) == [0x90, lamp.number, 0])
        #expect(lamp.action.rawValue.hasPrefix("hotcue") || [.syncA, .syncB, .loopA, .loopB].contains(lamp.action))
    }
    try withLegacyRane(name) { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        let pads: [(DeckID, [UInt8?])] =
            name == legacyRaneModels[0]
            ? [(.a, [18, 23, 22, 21, 20]), (.b, [78, 73, 74, 75, 76])]
            : name == legacyRaneModels[1]
                ? [
                    (.a, [104, 105, 98, 99, 100, 32, 38, 48]), (.b, [78, 73, 74, 75, 76, 53, 84, 86]),
                    (.c, [18, 23, 22, 21, 20, nil, 33, 39]), (.d, [101, 102, 103, 106, 107, 54, 85, 87]),
                ] : []
        for (deck, numbers) in pads {
            for (index, n) in numbers.enumerated() {
                guard let n else { continue }; events.removeAll(); raneLegacyPacket([0x90, n, 127, n, 0], input)
                let action = [
                    ControllerAction.hotcue1A, .hotcue2A, .hotcue3A, .hotcue4A, .hotcue5A, .hotcue6A, .hotcue7A,
                    .hotcue8A,
                ][index].assigned(to: deck)
                #expect(events.count == 1 && events.first?.0 == .init(action, deck: deck))
            }
        }
        events.removeAll()
        if name == legacyRaneModels[2] {
            raneLegacyPacket([0x94, 20, 127, 21, 127, 0x95, 20, 127, 21, 127, 0xBE, 58, 2], input)
        } else if name == legacyRaneModels[1] {
            raneLegacyPacket([0x90, 16, 127, 16, 0, 0xB0, 122, 3, 123, 3, 21, 127], input)
        } else {
            raneLegacyPacket([0x90, 19, 127, 79, 127, 0xB0, 21, 127, 22, 127, 40, 127], input)
        }
        #expect(events.isEmpty)
    }
}
