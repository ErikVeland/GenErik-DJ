import Foundation
import TDJCore
import Testing

@testable import TDJInterface
private let cmdModels = ["Behringer CMD PL-1", "Behringer CMD DC-1", "Behringer CMD LC-1", "Behringer CMD DV-1"]

@Test func controllerCatalogueCMDSourceDefinitionsKeepPositiveSelectorSchemaBounded() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent()
    let data = try Data(
        contentsOf: root.appendingPathComponent("Sources/TDJInterface/Resources/factory-controller-profiles.json"))
    let raw = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any]);
    let records = try #require(raw["profiles"] as? [[String: Any]])
    for record in records where cmdModels.contains(record["id"] as? String ?? "") {
        let p = try JSONDecoder().decode(
            ControllerProfileData.self, from: JSONSerialization.data(withJSONObject: record));
        #expect(p.isValid, "Invalid CMD profile: \(p.id)")
    }
    let source = try #require(records.first { $0["id"] as? String == cmdModels[0] });
    let changes = try #require(source["bankChanges"] as? [[String: Any]]); let selector = try #require(changes.first)
    for fields in [["onValue": 127], ["kind": "control"], ["anyPositive": false]] as [[String: Any]] {
        var record = source; record["bankChanges"] = [selector.merging(fields) { _, value in value }]
        let p = try JSONDecoder().decode(
            ControllerProfileData.self, from: JSONSerialization.data(withJSONObject: record));
        #expect(!p.isValid)
    }
}

@MainActor private func withCMD(_ name: String, _ body: (ControllerMIDIConnection) throws -> Void) throws {
    let suite = "cmd-\(UUID().uuidString)"; let preferences = UserDefaults(suiteName: suite)!
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
    if name == cmdModels[3] {
        #expect(!input.isInputActive(10) && !input.isInputActive(11))
        let p = try #require(ControllerFactoryProfile.matching([name]));
        for source: Int32 in [10, 11] { input.select(source); input.applyFactoryProfile(p) }
        #expect(input.bindingCount == 72)
    }
    #expect(input.isInputActive(10) && input.isInputActive(11) && writes == 0); try body(input)
}
@MainActor private func cmdPacket(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source); input.flushPendingActions()
}

@Test(arguments: cmdModels) @MainActor func controllerCatalogueCMDIndependentIdentityChannelsAndNoSetup(_ name: String)
    throws
{
    let p = try #require(ControllerFactoryProfile.matching([name])); let d = try #require(p.definition)
    let index = try #require(cmdModels.firstIndex(of: name))
    #expect(d.inputs.count == [104, 34, 40, 36][index] && d.outputs.count == [48, 16, 20, 0][index])
    #expect(
        p.selectsAutomatically == (index != 3) && d.startup.isEmpty && d.shutdown.isEmpty && d.audioOutput == nil
            && d.inputProtocol == nil)
    #expect(
        ControllerFactoryProfile.matching(["CMD MM-1"]) != p && ControllerFactoryProfile.matching(["CMD Studio4a"]) != p
    )
    try withCMD(name) { _ in }
}

@Test @MainActor func controllerCatalogueCMDPL1BothCueReleasesKeepPressureAndSourceOwnership() throws {
    try withCMD("Behringer CMD PL-1") { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        for (ch, deck) in zip(UInt8(0)...3, DeckID.allCases) {
            for velocity: UInt8 in [1, 64, 127] {
                for off: UInt8 in [0x80 + ch, 0x90 + ch] {
                    events.removeAll(); cmdPacket([0x90 + ch, 34, velocity, 34, velocity], input);
                    cmdPacket([0x90 + ch, 34, velocity], input, source: 11)
                    cmdPacket([off, 34, off < 0x90 ? 64 : 0], input);
                    #expect(events.map(\.1) == [Double(velocity) / 127])
                    cmdPacket([off, 34, off < 0x90 ? 64 : 0], input, source: 11)
                    #expect(
                        events.map(\.1) == [Double(velocity) / 127, 0]
                            && events.allSatisfy {
                                $0.0 == .init(ControllerAction.cuePreviewA.assigned(to: deck), deck: deck)
                            })
                }
            }
        }
    }
}

@Test @MainActor func controllerCatalogueCMDPL1PositiveBankEdgesRetireOwnedContactsAndReleaseKeepsFreshBank() throws {
    try withCMD("Behringer CMD PL-1") { input in
        var events: [(ControllerActionTarget, Double)] = [];
        input.onTargetAction = { target, value in
            if [.cuePreviewA, .cuePreviewB, .jogTouchA, .jogTouchB].contains(target.action) {
                events.append((target, value))
            }
        }
        for velocity: UInt8 in [1, 64, 127] {
            events.removeAll(); cmdPacket([0x90, 34, 127, 31, 127], input);
            cmdPacket([0x90, 34, 64, 31, 64], input, source: 11)
            cmdPacket([0x91, 26, velocity], input); #expect(events.count == 2)
            cmdPacket([0x91, 34, 127, 31, 127, 0x81, 26, 64, 0x80, 34, 64, 31, 64], input)
            #expect(events.count == 4 && events.allSatisfy { $0.1 > 0 })
            cmdPacket([0x80, 34, 64, 31, 64], input, source: 11)
            #expect(events.count == 6 && events.suffix(2).allSatisfy { $0.0.deck == .a && $0.1 == 0 })
            cmdPacket([0x92, 26, velocity], input)
            #expect(events.count == 8 && events.suffix(2).allSatisfy { $0.0.deck == .b && $0.1 == 0 })
        }
    }
}

@Test @MainActor func controllerCatalogueCMDPL1ContactGatePreservesRawCountsAndIgnoresFreeSpin() throws {
    try withCMD("Behringer CMD PL-1") { input in
        var jogs: [(ControllerActionTarget, ControllerMIDIValue)] = []; input.onJogAction = { jogs.append(($0, $1)) }
        for (ch, deck) in zip(UInt8(0)...3, DeckID.allCases) {
            jogs.removeAll(); cmdPacket([0xB0 + ch, 31, 65], input); #expect(jogs.isEmpty)
            cmdPacket([0x90 + ch, 31, 127], input)
            for v: UInt8 in [65, 69, 63] { cmdPacket([0xB0 + ch, 31, v], input) }
            #expect(
                jogs.map(\.1) == [.relative(1), .relative(5), .relative(-1)]
                    && jogs.allSatisfy { $0.0.deck == deck && $0.0.argument == 400 })
            jogs.removeAll(); cmdPacket([0x80 + ch, 31, 127, 0xB0 + ch, 31, 65], input); #expect(jogs.isEmpty)
        }
    }
}

@Test(arguments: cmdModels) @MainActor func controllerCatalogueCMDNativePadsKeepIndependentColumnTargets(_ name: String)
    throws
{
    try withCMD(name) { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        let pads: [(UInt8, DeckID, [UInt8])]
        if name == cmdModels[0] {
            pads = zip(UInt8(0)...3, DeckID.allCases).map { ($0.0, $0.1, Array(UInt8(16)...23)) }
        } else if name == cmdModels[1] {
            pads = [
                (5, .a, [48, 44, 40, 36]), (5, .b, [49, 45, 41, 37]), (5, .c, [50, 46, 42, 38]),
                (5, .d, [51, 47, 43, 39]),
            ]
        } else if name == cmdModels[2] {
            pads = [
                (7, .a, [32, 36, 40, 44, 48]), (7, .b, [33, 37, 41, 45, 49]), (7, .c, [34, 38, 42, 46, 50]),
                (7, .d, [35, 39, 43, 47, 51]),
            ]
        } else {
            pads = [(6, .a, [92, 93, 94, 95]), (6, .b, [88, 89, 90, 91])]
        }
        for (ch, deck, numbers) in pads {
            for (i, n) in numbers.enumerated() {
                events.removeAll(); cmdPacket([0x90 + ch, n, 127, n, 127, n, 0], input)
                let action = [
                    ControllerAction.hotcue1A, .hotcue2A, .hotcue3A, .hotcue4A, .hotcue5A, .hotcue6A, .hotcue7A,
                    .hotcue8A,
                ][i].assigned(to: deck)
                #expect(events.count == 1 && events.first?.0 == .init(action, deck: deck))
            }
        }
    }
}

@Test(arguments: cmdModels) @MainActor func controllerCatalogueCMDRelativeControlsFollowCurrentNativeTargets(
    _ name: String
) throws {
    try withCMD(name) { input in
        var current: [ControllerActionTarget: Double] = [:]; var events: [(ControllerActionTarget, Double)] = []
        input.currentTargetValue = { current[$0, default: 0.5] };
        input.onTargetAction = { target, value in
            events.append((target, value)); current[target] = value
        }
        let controls: [(UInt8, UInt8, ControllerAction, DeckID)]
        if name == cmdModels[0] {
            controls = [
                (0, 0, .gainA, .a), (1, 1, .highB, .b), (2, 2, .midA, .c), (3, 3, .lowB, .d), (0, 4, .filterKnobA, .a),
            ]
        } else if name == cmdModels[3] {
            controls = [
                (6, 20, .gainA, .a), (6, 25, .highB, .b), (6, 30, .midA, .c), (6, 37, .levelA, .a),
                (6, 41, .levelB, .b), (6, 45, .levelA, .c),
            ]
        } else {
            let ch: UInt8 = name == cmdModels[1] ? 5 : 7;
            controls = [
                (ch, 16, .levelA, .a), (ch, 17, .levelB, .b), (ch, 18, .levelA, .c), (ch, 19, .levelB, .d),
                (ch, 20, .filterKnobA, .a), (ch, 23, .filterKnobB, .d),
            ]
        }
        for (ch, n, action, deck) in controls {
            events.removeAll(); cmdPacket([0xB0 + ch, n, 69], input); cmdPacket([0xB0 + ch, n, 59], input)
            #expect(
                events.map(\.1) == [0.5 + 5.0 / 127, 0.5] && events.allSatisfy { $0.0 == .init(action, deck: deck) })
        }
    }
}

@Test(arguments: cmdModels) @MainActor func controllerCatalogueCMDLibraryAndLoopEncodersRetainOwnStrictness(
    _ name: String
) throws {
    try withCMD(name) { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        let encoders: [(UInt8, UInt8, ControllerAction, DeckID?)] =
            name == cmdModels[0]
            ? [(0, 5, .loopSizeA, .a), (1, 5, .loopSizeB, .b), (0, 6, .browse, nil)]
            : name == cmdModels[1]
                ? [(5, 32, .browse, nil)]
                : name == cmdModels[3]
                    ? [
                        (6, 38, .loopSizeA, .a), (6, 42, .loopSizeB, .b), (6, 46, .loopSizeA, .c),
                        (6, 47, .browse, nil),
                    ] : []
        for (ch, n, action, deck) in encoders {
            events.removeAll(); cmdPacket([0xB0 + ch, n, 65], input); cmdPacket([0xB0 + ch, n, 63], input)
            #expect(
                events.map(\.1) == [0.5 + 1.0 / 126, 0.5 - 1.0 / 126]
                    && events.allSatisfy { $0.0.action == action && $0.0.deck == deck })
            if name == cmdModels[1] {
                events.removeAll(); for v: UInt8 in [0, 1, 64, 127] { cmdPacket([0xB0 + ch, n, v], input) };
                #expect(events.isEmpty)
            }
        }
    }
}

@Test(arguments: cmdModels) @MainActor func controllerCatalogueCMDQualifiedLampPacketsAndRejectedUnqualifiedWires(
    _ name: String
) throws {
    let p = try #require(ControllerFactoryProfile.matching([name])); let lamps = p.feedback(destination: 20)
    #expect(lamps.count == (name == cmdModels[0] ? 48 : name == cmdModels[1] ? 16 : name == cmdModels[2] ? 20 : 0))
    for lamp in lamps {
        let off: UInt8 = name == cmdModels[2] ? 127 : 0
        #expect(
            lamp.kind == .note && lamp.message(value: 1) == [0x90 + lamp.channel, lamp.number, 1]
                && lamp.message(value: 0) == [0x90 + lamp.channel, lamp.number, off])
    }
    try withCMD(name) { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        if name == cmdModels[0] {
            cmdPacket([0x94, 35, 127, 34, 127, 0xE0, 0, 64, 0x90, 27, 127, 0xB0, 10, 127], input)
        } else if name == cmdModels[1] {
            cmdPacket([0x90, 36, 127, 0x95, 52, 127, 64, 127, 0xB5, 0, 65], input)
        } else if name == cmdModels[2] {
            cmdPacket([0x90, 32, 127, 0x97, 60, 127, 63, 127, 64, 127, 0xB7, 0, 65], input)
        } else {
            cmdPacket([0x90, 92, 127, 0xB6, 32, 65, 48, 65, 0x96, 68, 127, 72, 127], input)
        }
        #expect(events.isEmpty)
    }
}
