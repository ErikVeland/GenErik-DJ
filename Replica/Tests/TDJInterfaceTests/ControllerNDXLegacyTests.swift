import Foundation
import TDJCore
import Testing

@testable import TDJInterface
private let ndxLegacyModels = ["Numark NDX800", "Numark NDX900"]

@MainActor private func withNDXLegacy(_ name: String, _ body: (ControllerMIDIConnection) throws -> Void) throws {
    let suite = "ndx-legacy-\(UUID().uuidString)"; let preferences = UserDefaults(suiteName: suite)!
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
    input.reconcileFactoryProfiles(); #expect(input.isInputActive(10) && input.isInputActive(11) && writes == 0)
    try body(input)
}
@MainActor private func ndxLegacyPacket(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source); input.flushPendingActions()
}

@Test(arguments: ndxLegacyModels) @MainActor func controllerCatalogueNDXLegacyIndependentPlayerIdentityAndNoSetup(
    _ name: String
) throws {
    let p = try #require(ControllerFactoryProfile.matching([name])); let d = try #require(p.definition)
    #expect(d.isValid && p.selectsAutomatically && d.role == "player" && d.inputs.count == 10)
    #expect(
        d.outputs.isEmpty && d.startup.isEmpty && d.shutdown.isEmpty && d.audioOutput == nil && d.inputProtocol == nil)
    #expect(ControllerFactoryProfile.matching(["Numark NDX500"]) != p)
    for other in ndxLegacyModels where other != name { #expect(ControllerFactoryProfile.matching([other]) != p) }
    try withNDXLegacy(name) { _ in }
}

@Test(arguments: ndxLegacyModels) @MainActor
func controllerCatalogueNDXLegacyAllChannelsKeepTheirSourcePlayerAndBothCueReleases(_ name: String) throws {
    try withNDXLegacy(name) { input in
        var events: [(DeckID?, Double)] = []
        input.onTargetAction = { target, value in
            if target.action == .cuePreviewA || target.action == .cuePreviewB { events.append((target.deck, value)) }
        }
        for ch: UInt8 in 0...15 {
            for off: UInt8 in [0x80 + ch, 0x90 + ch] {
                events.removeAll(); ndxLegacyPacket([0x90 + ch, 56, 127, 56, 127], input)
                ndxLegacyPacket([0x90 + ch, 56, 127], input, source: 11)
                ndxLegacyPacket([off, 56, off < 0x90 ? 127 : 0], input)
                #expect(events.map(\.1) == [1, 1, 0] && events[0].0 == .a && events[1].0 == .b && events.last?.0 == .a)
                ndxLegacyPacket([off, 56, off < 0x90 ? 127 : 0], input, source: 11)
                #expect(events.map(\.1) == [1, 1, 0, 0] && events.last?.0 == .b)
            }
        }
    }
}

@Test(arguments: ndxLegacyModels) @MainActor
func controllerCatalogueNDXLegacyModeReportsRetireOnlyOwnedPlayerAndPreserveFreshCue(_ name: String) throws {
    try withNDXLegacy(name) { input in
        var events: [(DeckID?, Double)] = []
        input.onTargetAction = { target, value in
            if target.action == .cuePreviewA || target.action == .cuePreviewB { events.append((target.deck, value)) }
        }
        ndxLegacyPacket([0x94, 56, 127], input); ndxLegacyPacket([0x9B, 56, 127], input, source: 11)
        if name == ndxLegacyModels[0] {
            ndxLegacyPacket([0x9C, 69, 127, 0x8C, 69, 127], input); #expect(events.map(\.1) == [1, 1])
            ndxLegacyPacket([0x84, 56, 127], input); ndxLegacyPacket([0x8B, 56, 127], input, source: 11)
            #expect(events.map(\.1) == [1, 1, 0, 0])
            events.removeAll(); ndxLegacyPacket([0x90, 56, 127], input); input.stop();
            #expect(events.map(\.1) == [1, 0])
            return
        }
        ndxLegacyPacket([0x9C, 69, 1], input); #expect(events.count == 3 && events.last?.0 == .a && events.last?.1 == 0)
        ndxLegacyPacket([0x92, 56, 127, 0x8C, 69, 127], input);
        #expect(events.count == 4 && events.last?.0 == .a && events.last?.1 == 1)
        ndxLegacyPacket([0x82, 56, 127], input); ndxLegacyPacket([0x8B, 56, 127], input, source: 11)
        #expect(events.map(\.1) == [1, 1, 0, 1, 0, 0])
        events.removeAll(); ndxLegacyPacket([0x90, 56, 127], input); input.stop(); #expect(events.map(\.1) == [1, 0])
    }
}

@Test(arguments: ndxLegacyModels) @MainActor func controllerCatalogueNDXLegacyConfirmedButtonsRejectUnqualifiedRoles(
    _ name: String
) throws {
    try withNDXLegacy(name) { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        for (n, action): (UInt8, ControllerAction) in [
            (58, .playA), (60, .pitchBendDownA), (61, .pitchBendUpA), (70, .loadA), (48, .loopInA), (49, .loopOutA),
            (50, .reloopA),
        ] {
            events.removeAll(); ndxLegacyPacket([0x9E, n, 127, n, 127, 0x8E, n, 127], input)
            #expect(events.first?.0 == .init(action, deck: .a))
            #expect(events.map(\.1) == (action.isMomentary ? [1, 0] : [1]))
        }
        events.removeAll();
        ndxLegacyPacket(
            [
                0x90, 0, 127, 51, 127, 52, 127, 53, 127, 57, 127, 59, 127, 81, 127, 89, 127, 0xB0, 34, 65, 36, 64, 37,
                64,
            ], input)
        #expect(events.isEmpty)
    }
}

@Test(arguments: ndxLegacyModels) @MainActor
func controllerCatalogueNDXLegacyFullPitchAndStrictBrowseKeepPlayerOwnership(_ name: String) throws {
    try withNDXLegacy(name) { input in
        input.currentTargetValue = { _ in 0.5 }; var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        ndxLegacyPacket([0xEF, 127, 127], input); #expect(events.isEmpty)
        ndxLegacyPacket([0xEF, 0, 64], input); ndxLegacyPacket([0xEF, 0, 0], input)
        #expect(events.map(\.1) == [0.5, 1] && events.allSatisfy { $0.0 == .init(.tempoA, deck: .a) })
        events.removeAll(); ndxLegacyPacket([0xE5, 0, 64], input, source: 11)
        #expect(events.count == 1 && events.first?.0 == .init(.tempoB, deck: .b))
        events.removeAll(); for v: UInt8 in [0, 2, 63, 64, 65, 126] { ndxLegacyPacket([0xBE, 33, v], input) };
        #expect(events.isEmpty)
        ndxLegacyPacket([0xBE, 33, 1], input); ndxLegacyPacket([0xBE, 33, 127], input)
        #expect(events.map(\.1) == [0.5 + 1.0 / 126, 0.5 - 1.0 / 126] && events.allSatisfy { $0.0.action == .browse })
    }
}
