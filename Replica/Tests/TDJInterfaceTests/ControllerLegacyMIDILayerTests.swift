import Foundation
import TDJCore
import Testing

@testable import TDJInterface

private let legacyLayerModels = ["Denon DJ X1600", "Synq PCM-1"]
@MainActor private func withLegacyLayers(_ name: String, _ body: (ControllerMIDIConnection) throws -> Void) throws {
    let suite = "legacy-layers-\(UUID().uuidString)"; let preferences = UserDefaults(suiteName: suite)!
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
        input.isInputActive(10) && input.isInputActive(11) && input.bindingCount == p.bindings(source: 10).count * 2
            && writes == 0)
    try body(input)
}
@MainActor private func layerPacket(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source); input.flushPendingActions()
}

@Test(arguments: legacyLayerModels) @MainActor func controllerCatalogueLegacyLayerIdentityAndManualCapacity(
    _ name: String
) throws {
    let p = try #require(ControllerFactoryProfile.matching([name])); let d = try #require(p.definition)
    #expect(!p.selectsAutomatically && d.inputs.count == (name == legacyLayerModels[0] ? 54 : 50))
    #expect(d.outputs.isEmpty && d.startup.isEmpty && d.shutdown.isEmpty && d.audioOutput == nil)
    for other in ["X1800", "X1850", "American Audio DP2", "DMC-2000"] {
        #expect(ControllerFactoryProfile.matching([other]) != p)
    }
    try withLegacyLayers(name) { _ in }
}

@Test(arguments: legacyLayerModels) @MainActor
func controllerCatalogueLegacyLayerCueBothReleaseFormsPreserveSourceAndStopOwnership(_ name: String) throws {
    try withLegacyLayers(name) { input in
        let cues: [(UInt8, UInt8, DeckID)] =
            name == legacyLayerModels[0]
            ? [(0, 69, .a), (0, 77, .b), (0, 85, .c), (0, 93, .d)] : [(0, 25, .a), (1, 25, .b)]
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        for (ch, number, deck) in cues {
            for off: UInt8 in [0x80 + ch, 0x90 + ch] {
                events.removeAll(); layerPacket([0x90 + ch, number, 64, number, 64], input);
                layerPacket([0x90 + ch, number, 64], input, source: 11)
                layerPacket([off, number, off < 0x90 ? 64 : 0], input); #expect(events.map(\.1) == [64.0 / 127])
                layerPacket([off, number, off < 0x90 ? 64 : 0], input, source: 11)
                #expect(events.map(\.1) == [64.0 / 127, 0] && events.allSatisfy { $0.0.deck == deck })
            }
        }
        events.removeAll(); layerPacket([0x90, name == legacyLayerModels[0] ? 69 : 25, 64], input); input.stop();
        let cueEvents = events.filter { $0.0.action == .cuePreviewA || $0.0.action == .cuePreviewB }
        #expect(cueEvents.map(\.1) == [64.0 / 127, 0])
    }
}

@Test @MainActor func controllerCatalogueX1600NativePagesKeepSeparateTransportTargets() throws {
    try withLegacyLayers("Denon DJ X1600") { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        for (i, deck) in DeckID.allCases.enumerated() {
            for (j, action) in [ControllerAction.playA, .cuePreviewA, .syncA, .loadA].enumerated() {
                events.removeAll(); let n = UInt8(68 + 8 * i + j); layerPacket([0x90, n, 64, n, 64, n, 0], input)
                #expect(
                    events.first?.0 == .init(action.assigned(to: deck), deck: deck)
                        && events.map(\.1) == (action.isMomentary ? [64.0 / 127, 0] : [64.0 / 127]))
            }
            events.removeAll(); let n = UInt8(65 + 8 * i); layerPacket([0x90, n, 64, n, 0], input)
            #expect(
                events.count == 1 && events.first?.0 == .init(ControllerAction.loopA.assigned(to: deck), deck: deck))
        }
    }
}

@Test @MainActor func controllerCatalogueX1600LayerAndPageReportsRetireOnlyOwnedContacts() throws {
    try withLegacyLayers("Denon DJ X1600") { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        layerPacket([0x90, 69, 64, 77, 64], input); layerPacket([0x90, 69, 64], input, source: 11)
        layerPacket([0xB0, 70, 0], input); #expect(events.map(\.1) == [64.0 / 127, 64.0 / 127])
        layerPacket([0xB0, 70, 127], input, source: 11); #expect(events.last?.0.deck == .a && events.last?.1 == 0)
        layerPacket([0xB0, 76, 4], input); #expect(events.count == 3)
        layerPacket([0xB0, 76, 2], input);
        #expect(events.count == 4 && events.last?.0.deck == .b && events.last?.1 == 0)
        for n: UInt8 in [69, 77, 85, 93] { layerPacket([0x90, n, 64], input) }
        events.removeAll(); layerPacket([0xB0, 74, 127], input);
        #expect(events.count == 4 && events.allSatisfy { $0.1 == 0 })
        events.removeAll(); layerPacket([0x90, 68, 64, 0xB0, 76, 3, 0x90, 68, 64, 68, 0], input);
        #expect(events.count == 2 && events.allSatisfy { $0.0.action == .playA })
    }
}

@Test @MainActor func controllerCatalogueX1600StripPickupAndPFLKeepIndependentAddresses() throws {
    try withLegacyLayers("Denon DJ X1600") { input in
        input.currentTargetValue = { _ in 0.5 }; var events: [(ControllerActionTarget, Double)] = [];
        input.onTargetAction = { events.append(($0, $1)) }
        for (i, deck) in DeckID.allCases.enumerated() {
            for (n, action): (UInt8, ControllerAction) in [
                (UInt8([2, 8, 13, 18][i]), .highA), (UInt8([3, 9, 14, 19][i]), .midA),
                (UInt8([4, 10, 15, 20][i]), .lowA), (UInt8([5, 11, 16, 21][i]), .levelA),
            ] {
                events.removeAll(); layerPacket([0xB0, n, 0], input); #expect(events.isEmpty);
                layerPacket([0xB0, n, 64], input)
                #expect(events.count == 1 && events.first?.0 == .init(action.assigned(to: deck), deck: deck))
            }
            events.removeAll(); let cue = UInt8([3, 7, 11, 15][i]); layerPacket([0x90, cue, 64, cue, 0], input)
            #expect(events.count == 1 && events.first?.0 == .init(ControllerAction.cueA.assigned(to: deck), deck: deck))
        }
        layerPacket([0xB0, 5, 127, 11, 127], input); events.removeAll();
        layerPacket([0xB0, 70, 0, 5, 127, 11, 127], input)
        #expect(events.count == 1 && events.first?.0.action == .levelB)
        events.removeAll(); layerPacket([0xB1, 2, 64, 5, 64, 0xB0, 1, 64, 26, 64, 27, 64], input);
        #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCataloguePCM1OwnFactoryShiftAndAlternateCueReleasesDoNotInheritDP2() throws {
    try withLegacyLayers("Synq PCM-1") { input in
        var values: [Double] = [];
        input.onTargetAction = { target, value in if target.action == .cuePreviewA { values.append(value) } }
        layerPacket([0x90, 25, 127, 0x83, 25, 127], input); #expect(values == [1, 0])
        layerPacket([0x93, 25, 127, 25, 0], input); #expect(values == [1, 0])
        layerPacket([0x90, 25, 127, 55, 127], input); #expect(values == [1, 0, 1, 0])
        layerPacket([0x90, 25, 127, 25, 0], input); #expect(values == [1, 0, 1, 0])
        layerPacket([0x80, 55, 127, 0x90, 25, 127, 25, 0], input); #expect(values == [1, 0, 1, 0, 1, 0])
    }
}

@Test @MainActor func controllerCataloguePCM1OwnEQPitchAndUnqualifiedGlobalsStaySeparate() throws {
    try withLegacyLayers("Synq PCM-1") { input in
        input.currentTargetValue = { _ in 0.5 }; var events: [(ControllerActionTarget, Double)] = [];
        input.onTargetAction = { events.append(($0, $1)) }
        for (n, action): (UInt8, ControllerAction) in [(19, .highA), (20, .midA), (21, .lowA), (22, .levelA)] {
            events.removeAll(); layerPacket([0xB0, n, 0], input); #expect(events.isEmpty);
            layerPacket([0xB0, n, 64], input); #expect(events.count == 1 && events.first?.0.action == action)
        }
        events.removeAll(); layerPacket([0xB0, 18, 127], input); #expect(events.isEmpty);
        layerPacket([0xB0, 18, 64], input); layerPacket([0xB0, 18, 0], input);
        #expect(events.map(\.1) == [63.0 / 127, 1])
        events.removeAll();
        layerPacket(
            [0xB2, 4, 64, 5, 64, 0xB0, 23, 65, 25, 65, 0x90, 9, 127, 10, 127, 22, 127, 23, 127, 24, 127], input);
        #expect(events.isEmpty)
    }
}

@Test(arguments: legacyLayerModels) @MainActor
func controllerCatalogueLegacyLayerEncodersAcceptOnlyOwnQualifiedDirections(_ name: String) throws {
    try withLegacyLayers(name) { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        let status: UInt8 = name == legacyLayerModels[0] ? 0xB0 : 0xB2
        let numbers: [UInt8] = name == legacyLayerModels[0] ? [80, 81, 84, 85, 88, 89, 92, 93] : [1]
        for n in numbers {
            events.removeAll();
            for v: UInt8 in name == legacyLayerModels[0] ? [1, 63, 64, 65, 126] : [0, 1, 64, 127] {
                layerPacket([status, n, v], input)
            }; #expect(events.isEmpty)
            layerPacket([status, n, name == legacyLayerModels[0] ? 0 : 65], input);
            layerPacket([status, n, name == legacyLayerModels[0] ? 127 : 63], input)
            #expect(events.map(\.1) == [0.5 + 1.0 / 126, 0.5 - 1.0 / 126])
        }
    }
}
