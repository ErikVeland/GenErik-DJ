import Foundation
import TDJCore
import Testing

@testable import TDJInterface

/**
 * Builds synthetic XL data with independent wires for every physical record group.
 */
func launchControlXLTemplateFixture(_ template: UInt8 = 0) -> [UInt8] {
    var data: [UInt8] = []
    for index: UInt8 in 0..<24 { data += [index, 0, 0, 127, 2, 0] }
    for index: UInt8 in 0..<8 { data += [40 + index, 0, 0, 127, 3, 0] }
    for index: UInt8 in 0..<16 { data += [0, 60 + index, 0, 127, 0, 4] }
    for index: UInt8 in 0..<4 { data += [0, 80 + index, 0, 127, 0, 5] }
    for index: UInt8 in 0..<4 { data += [1, 100 + index, 0, 127, 0, 6] }
    data += [UInt8](repeating: 0, count: 72)
    return [240, 0, 32, 41, 2, 17, 119, template] + data + [247]
}
@MainActor private func xlTemplatePacket(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source); input.flushPendingActions()
}
@MainActor private func withXLTemplate(
    decks: [DeckID] = DeckID.allCases, _ body: (ControllerMIDIConnection) throws -> Void
) throws {
    let suite = "lcxl-template-\(UUID().uuidString)"; let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let name = "Novation Launch Control XL"
    let input = ControllerMIDIConnection(
        preferences: preferences, factoryPacketSender: { _, _ in true }, deckAvailability: { decks },
        factoryInputConnector: { _ in true })
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id), name: name,
            identity: .init(id: id, device: UInt32(id), names: [name], portNames: ["Launch Control XL"]))
    }
    input.destinations = [20, 21].map { id in
        .init(
            id: id, reference: UInt32(id), name: name,
            identity: .init(id: id, device: UInt32(id - 10), names: [name], portNames: ["Launch Control XL"]))
    }
    input.reconcileFactoryProfiles(); #expect(!input.isInputActive(10) && !input.isInputActive(11))
    for source: Int32 in [10, 11] { input.receiveBytes(launchControlXLTemplateFixture(), source: source) }
    #expect(input.isInputActive(10) && input.isInputActive(11)); try body(input)
}

@Test @MainActor func controllerCatalogueLaunchControlXLTemplateHasDistinctIdentityPortsAndReadContract() throws {
    let p = try #require(ControllerFactoryProfile.matching(["Launch Control XL"], automaticOnly: true));
    let d = try #require(p.definition)
    #expect(
        d.inputs.count == 60 && d.outputs.isEmpty && d.shutdown.isEmpty && d.requiresPairedSetup
            && d.inputProtocol?.preservesRawMappings == true)
    #expect(d.startup == [[240, 0, 32, 41, 2, 17, 119, 0, 247], [240, 0, 32, 41, 2, 17, 121, 0, 247]])
    for name in ["Launch Control XL MK1", "Launch Control XL MK2", "Launch Control XL MKII"] {
        #expect(ControllerFactoryProfile.matching([name], automaticOnly: true) == p)
    }
    for name in [
        "Launch Control", "Launch Control 3", "Launch Control XL3", "Launch Control XL MK3", "Launch Control XL clone",
    ] { #expect(ControllerFactoryProfile.matching([name], automaticOnly: true) != p) }
    for port in ["Launch Control XL", "Launch Control XL HUI", "MIDI 2", "Launch Control XL 8"] {
        let source = ControllerFactoryEndpoint(id: 10, device: 1, names: [p.rawValue], portNames: [port]);
        let output = ControllerFactoryEndpoint(id: 20, device: 1, names: [p.rawValue], portNames: [port])
        #expect(
            ControllerFactorySession.discover(sources: [source], destinations: [output], disabled: []).count
                == (port.contains("HUI") || port == "MIDI 2" ? 0 : 1))
        #expect(ControllerFactorySession.discover(sources: [source], destinations: [], disabled: []).isEmpty)
    }
}

@Test @MainActor func controllerCatalogueLaunchControlXLTemplateAllStripButtonsAndShiftMenusUseFourDeckPairs() throws {
    try withXLTemplate() { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        for (side, deck) in DeckID.allCases.enumerated() {
            for (number, action): (UInt8, ControllerAction) in [
                (UInt8(60 + 2 * side), .playA), (UInt8(68 + 2 * side), .syncA), (UInt8(69 + 2 * side), .loadA),
            ] {
                events.removeAll(); xlTemplatePacket([0x94, number, 127, number, 127, number, 0], input)
                #expect(events.count == 1 && events.first?.0 == .init(action.assigned(to: deck), deck: deck))
            }
            let cue = UInt8(61 + 2 * side)
            for off: UInt8 in [0x84, 0x94] {
                events.removeAll();
                xlTemplatePacket([0x94, cue, 127, cue, 127, off, cue, off == 0x84 ? 64 : 0], input);
                #expect(events.map(\.1) == [1, 0] && events.allSatisfy { $0.0.deck == deck })
            }
            let menu = UInt8(80 + side)
            events.removeAll(); xlTemplatePacket([0x95, menu, 127, menu, 0], input);
            #expect(events.map(\.0) == [.init(ControllerAction.cueA.assigned(to: deck), deck: deck)])
            xlTemplatePacket([0xB6, 103, 127], input); events.removeAll();
            xlTemplatePacket([0x95, menu, 127, menu, 0], input)
            #expect(events.map(\.0) == [.init(ControllerAction.keylockA.assigned(to: deck), deck: deck)])
            xlTemplatePacket([0xB6, 103, 0], input)
        }
    }
}

@Test @MainActor func controllerCatalogueLaunchControlXLTemplatePotsAndFadersKeepIndependentPickup() throws {
    try withXLTemplate() { input in
        input.currentTargetValue = { _ in 0.5 }; var events: [(ControllerActionTarget, Double)] = [];
        input.onTargetAction = { events.append(($0, $1)) }
        for (side, deck) in DeckID.allCases.enumerated() {
            for (channel, number, action): (UInt8, UInt8, ControllerAction) in [
                (2, UInt8(2 * side), .highA), (2, UInt8(1 + 2 * side), .midA), (2, UInt8(8 + 2 * side), .lowA),
                (2, UInt8(9 + 2 * side), .filterKnobA), (2, UInt8(16 + 2 * side), .gainA),
                (2, UInt8(17 + 2 * side), .levelA), (3, UInt8(40 + 2 * side), .levelA),
                (3, UInt8(41 + 2 * side), .gainA),
            ] {
                events.removeAll(); xlTemplatePacket([0xB0 + channel, number, 0], input); #expect(events.isEmpty)
                xlTemplatePacket([0xB0 + channel, number, 64], input);
                xlTemplatePacket([0xB0 + channel, number, 127], input)
                #expect(
                    events.count == 2 && events.last?.1 == 1
                        && events.allSatisfy { $0.0 == .init(action.assigned(to: deck), deck: deck) })
            }
        }
        events.removeAll(); xlTemplatePacket([0xB0, 0, 127, 0x90, 61, 127, 0xB4, 100, 127], input);
        #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueLaunchControlXLTemplateShiftAndTemplateChangesRetireOnlyOwnedHolds() throws {
    try withXLTemplate() { input in
        var values: [Double] = [];
        input.onTargetAction = { target, value in
            if target.action == .cuePreviewA && target.deck == .a { values.append(value) }
        }
        for change: [UInt8] in [[240, 0, 32, 41, 2, 17, 119, 8, 247], [0xB6, 103, 127]] {
            values.removeAll(); xlTemplatePacket([0x94, 61, 127], input);
            xlTemplatePacket([0x94, 61, 127], input, source: 11)
            xlTemplatePacket(change, input); #expect(values == [1]); xlTemplatePacket(change, input, source: 11);
            #expect(values == [1, 0])
            if change.first == 240 {
                #expect(!input.isInputActive(10)); xlTemplatePacket([0x94, 61, 127], input); #expect(values == [1, 0])
                for source: Int32 in [10, 11] {
                    xlTemplatePacket([240, 0, 32, 41, 2, 17, 119, 0, 247], input, source: source);
                    xlTemplatePacket(launchControlXLTemplateFixture(), input, source: source)
                }
            } else {
                xlTemplatePacket([0xB6, 103, 0], input); xlTemplatePacket([0xB6, 103, 0], input, source: 11)
            }
        }
        values.removeAll(); xlTemplatePacket([0x94, 61, 127], input); input.stop(); #expect(values == [1, 0])
    }
}

@Test @MainActor func controllerCatalogueLaunchControlXLTemplateKeepsFourDeckOptInAndNavigation() throws {
    try withXLTemplate(decks: DeckID.primary) { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        xlTemplatePacket([0x94, 64, 127, 64, 0, 66, 127, 66, 0, 60, 127, 60, 0], input);
        #expect(events == [.init(.playA, deck: .a)])
        events.removeAll(); xlTemplatePacket([0xB6, 100, 127, 100, 0, 101, 127, 101, 0, 102, 127, 102, 0], input);
        #expect(events.map(\.action) == [.browsePrevious, .browseNext, .openGroup])
    }
}

@Test @MainActor func controllerCatalogueLaunchControlXLTemplateBlocksEverySetupAndLaterReadFailure() throws {
    for failure in 0..<3 {
        let suite = "lcxl-failure-\(UUID().uuidString)"; let preferences = UserDefaults(suiteName: suite)!
        defer { preferences.removePersistentDomain(forName: suite) }
        var packets: [[UInt8]] = []; let name = "Novation Launch Control XL"
        let input = ControllerMIDIConnection(
            preferences: preferences,
            factoryPacketSender: { bytes, _ in
                let index = packets.count; packets.append(bytes); return index != failure
            }, factoryInputConnector: { _ in true })
        input.sources = [
            .init(
                id: 10, reference: 10, name: name,
                identity: .init(id: 10, device: 1, names: [name], portNames: ["Launch Control XL"]))
        ]
        input.destinations = [
            .init(
                id: 20, reference: 20, name: name,
                identity: .init(id: 20, device: 1, names: [name], portNames: ["Launch Control XL"]))
        ]
        input.reconcileFactoryProfiles(); #expect(!input.isInputActive(10))
        input.receiveBytes(launchControlXLTemplateFixture(), source: 10)
        if failure == 2 {
            #expect(input.isInputActive(10)); input.receiveBytes([240, 0, 32, 41, 2, 17, 119, 1, 247], source: 10)
        }
        #expect(!input.isInputActive(10) && packets.count == failure + 1)
    }
}
