import Foundation
import TDJCore
import Testing

@testable import TDJInterface

private let denonLegacyPlayerNames = ["Denon DJ SC2900", "Denon DJ S3900", "Denon DJ S3700", "Denon DJ S1200"]

@Test func controllerCatalogueDenonLegacyPlayerSchemaScopesAnyChannelContextToSinglePlayer() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent()
    let data = try Data(
        contentsOf: root.appendingPathComponent("Sources/TDJInterface/Resources/factory-controller-profiles.json"))
    let raw = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any]);
    let records = try #require(raw["profiles"] as? [[String: Any]])
    for record in records where denonLegacyPlayerNames.contains(record["id"] as? String ?? "") {
        let p = try JSONDecoder().decode(
            ControllerProfileData.self, from: JSONSerialization.data(withJSONObject: record));
        #expect(p.isValid, "Invalid player: \(p.id)")
    }
    let source = try #require(records.first { $0["id"] as? String == denonLegacyPlayerNames[0] });
    let changes = try #require(source["bankChanges"] as? [[String: Any]]); let context = try #require(changes.first)
    var exact = context; exact["anyChannel"] = false; exact["channel"] = 1
    for (role, contexts): (String, [[String: Any]]) in [
        ("accessory", [context]), ("player", [context, exact]),
        ("player", [context.merging(["decks": ["a", "b"]]) { _, new in new }]),
    ] {
        var record = source; record["role"] = role; record["bankChanges"] = contexts
        let p = try JSONDecoder().decode(
            ControllerProfileData.self, from: JSONSerialization.data(withJSONObject: record));
        #expect(!p.isValid)
    }
}

@MainActor private func withDenonLegacyPlayers(_ name: String, _ body: (ControllerMIDIConnection) throws -> Void) throws
{
    let suite = "denon-players-\(UUID().uuidString)"; let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    var writes = 0
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { _, _ in
            writes += 1; return true
        }, deckAvailability: { DeckID.allCases }, factoryInputConnector: { _ in true })
    input.sources = (10...13).map { id in
        .init(
            id: Int32(id), reference: UInt32(id), name: name,
            identity: .init(id: Int32(id), device: UInt32(id), names: [name]))
    }
    input.destinations = (10...13).map { id -> ControllerMIDIConnection.Source in
        let endpointID = Int32(id + 10)
        let identity = ControllerFactoryEndpoint(id: endpointID, device: UInt32(id), names: [name])
        return .init(id: endpointID, reference: UInt32(id + 10), name: name, identity: identity)
    }
    input.reconcileFactoryProfiles()
    for (source, deck) in zip(Int32(10)...13, DeckID.allCases) {
        #expect(input.isInputActive(source) && input.playerDeck(source: source) == deck)
    }
    #expect(writes == 0); try body(input); #expect(writes == 0)
}
@MainActor private func denonPlayerPacket(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source); input.flushPendingActions()
}

@Test(arguments: denonLegacyPlayerNames) @MainActor
func controllerCatalogueDenonLegacyPlayerKeepsOwnAutomaticIdentityAndNoHardwareWrites(_ name: String) throws {
    let p = try #require(ControllerFactoryProfile.matching([name], automaticOnly: true));
    let d = try #require(p.definition)
    #expect(
        p.isPlayer
            && d.inputs.count == (name == denonLegacyPlayerNames[3] ? 10 : name == denonLegacyPlayerNames[2] ? 16 : 21))
    #expect(
        d.outputs.isEmpty && d.startup.isEmpty && d.shutdown.isEmpty && d.audioOutput == nil && d.inputProtocol == nil)
    for other in ["DN-HC4500", "DN-HC5000", "SC5000", "SC6000"] {
        #expect(ControllerFactoryProfile.matching([other]) != p)
    }
    try withDenonLegacyPlayers(name) { _ in }
}

@Test(arguments: denonLegacyPlayerNames) @MainActor
func controllerCatalogueDenonLegacyPlayerAllChannelsAndBothPressure64ReleasesFollowAssignedDeck(_ name: String) throws {
    try withDenonLegacyPlayers(name) { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        for (source, deck) in zip(Int32(10)...13, DeckID.allCases) {
            for ch: UInt8 in 0..<16 {
                for off: UInt8 in [0x80 + ch, 0x90 + ch] {
                    events.removeAll();
                    denonPlayerPacket([0x90 + ch, 66, 64, 66, 64, off, 66, off < 0x90 ? 64 : 0], input, source: source)
                    #expect(
                        events.map(\.1) == [64.0 / 127, 0]
                            && events.allSatisfy {
                                $0.0 == .init(ControllerAction.cuePreviewA.assigned(to: deck), deck: deck)
                            })
                }
            }
        }
    }
}

@Test(arguments: denonLegacyPlayerNames) @MainActor
func controllerCatalogueDenonLegacyPlayerModeChangesRetireOnlyOwnedAssignedContactsAndRearmButtons(_ name: String)
    throws
{
    try withDenonLegacyPlayers(name) { input in
        let p = try #require(ControllerFactoryProfile.matching([name]));
        let changes = try #require(p.definition?.bankChanges)
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        for change in changes {
            events.removeAll()
            for source: Int32 in 10...13 { denonPlayerPacket([0x97, 66, 64], input, source: source) }
            #expect(events.count == 4)
            denonPlayerPacket([0x9F, change.number, 127], input, source: 11); #expect(events.count == 4)
            denonPlayerPacket([0x9F, change.number, 64], input, source: 11)
            #expect(events.count == 5 && events.last?.0 == .init(.cuePreviewB, deck: .b) && events.last?.1 == 0)
            for source: Int32 in [10, 12, 13] { denonPlayerPacket([0x87, 66, 64], input, source: source) }
            #expect(events.count == 8)
            events.removeAll();
            denonPlayerPacket([0x95, 67, 64, change.number, 64, 67, 64, 0x85, 67, 64], input, source: 11)
            #expect(events.map(\.0) == [.init(.playB, deck: .b), .init(.playB, deck: .b)])
        }
        events.removeAll(); denonPlayerPacket([0x93, 66, 64], input, source: 11)
        input.setPlayerDeck(.d, source: 11)
        #expect(
            events.map(\.0) == [.init(.cuePreviewB, deck: .b), .init(.cuePreviewB, deck: .b)]
                && events.map(\.1) == [64.0 / 127, 0])
        denonPlayerPacket([0x94, 66, 64, 0x90, changes[0].number, 64], input, source: 11)
        #expect(
            events.suffix(2).map(\.0) == [.init(.cuePreviewB, deck: .d), .init(.cuePreviewB, deck: .d)]
                && events.suffix(2).map(\.1) == [64.0 / 127, 0])
    }
}

@Test(arguments: denonLegacyPlayerNames) @MainActor
func controllerCatalogueDenonLegacyPlayerNativeButtonsAndStrictLibraryRejectUnqualifiedMotion(_ name: String) throws {
    try withDenonLegacyPlayers(name) { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        var controls: [(UInt8, ControllerAction)] = [
            (67, .playB), (9, .pitchBendDownB), (8, .pitchBendUpB), (55, .loopInB), (57, .loopOutB), (64, .reloopB),
            (40, .loadB),
        ]
        if name != denonLegacyPlayerNames[3] {
            controls += [(6, .keylockB), (29, .loopB), (23, .hotcue1B), (24, .hotcue2B), (25, .hotcue3B)]
        }
        if name == denonLegacyPlayerNames[2] { controls.append((30, .loopDisableB)) }
        if name == denonLegacyPlayerNames[0] || name == denonLegacyPlayerNames[1] {
            controls += [
                (32, .hotcue4B), (115, .hotcue5B), (116, .hotcue6B), (117, .hotcue7B), (118, .hotcue8B), (107, .syncB),
            ]
        }
        for (number, action) in controls {
            events.removeAll(); denonPlayerPacket([0x9A, number, 64, number, 64, 0x8A, number, 64], input, source: 11)
            #expect(
                events.first?.0 == .init(action, deck: .b)
                    && events.map(\.1) == (action.isMomentary ? [64.0 / 127, 0] : [64.0 / 127]))
        }
        events.removeAll();
        for v: UInt8 in [1, 2, 63, 64, 65, 126] { denonPlayerPacket([0xBA, 84, v], input, source: 11) };
        #expect(events.isEmpty)
        denonPlayerPacket([0xBA, 84, 0], input, source: 11); denonPlayerPacket([0xBA, 84, 127], input, source: 11)
        #expect(events.map(\.1) == [0.5 + 1.0 / 126, 0.5 - 1.0 / 126] && events.allSatisfy { $0.0.action == .browse })
        events.removeAll();
        denonPlayerPacket([0xBA, 81, 65, 86, 65, 80, 65, 87, 65, 122, 127, 123, 127, 0xEA, 0, 64], input, source: 11);
        #expect(events.isEmpty)
    }
}
