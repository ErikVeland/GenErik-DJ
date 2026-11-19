import Foundation
import TDJCore
import Testing

@testable import TDJInterface

/**
 * Builds synthetic original-editor data with independent channels for knobs, pads and navigation buttons.
 */
func launchControlTemplateFixture(_ template: UInt8 = 0) -> [UInt8] {
    var data: [UInt8] = []
    for index: UInt8 in 0..<16 { data += [16 + index, 0, 0, 127, 2, 0] }
    for index: UInt8 in 0..<8 { data += [0, 60 + index, 0, 127, 0, 3] }
    for index: UInt8 in 0..<4 { data += [1, 100 + index, 0, 127, 0, 4] }
    return [240, 0, 32, 41, 2, 10, 119, template] + data + [247]
}

@MainActor private func withLaunchControlTemplate(
    decks: [DeckID] = DeckID.allCases, _ body: (ControllerMIDIConnection) throws -> Void
) throws {
    let suite = "lc-template-\(UUID().uuidString)"; let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let name = "Novation Launch Control"
    let input = ControllerMIDIConnection(
        preferences: preferences, factoryPacketSender: { _, _ in true }, deckAvailability: { decks },
        factoryInputConnector: { _ in true })
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id), name: name,
            identity: .init(id: id, device: UInt32(id), names: [name], portNames: ["Launch Control"]))
    }
    input.destinations = [20, 21].map { id in
        .init(
            id: id, reference: UInt32(id), name: name,
            identity: .init(id: id, device: UInt32(id - 10), names: [name], portNames: ["Launch Control"]))
    }
    input.reconcileFactoryProfiles(); #expect(!input.isInputActive(10) && !input.isInputActive(11))
    for source: Int32 in [10, 11] { input.receiveBytes(launchControlTemplateFixture(), source: source) }
    #expect(input.isInputActive(10) && input.isInputActive(11)); try body(input)
}
@MainActor private func originalLCPacket(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source); input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueLaunchControlTemplateHasIndependentReadOnlyContractAndStrictIdentity() throws {
    let p = try #require(ControllerFactoryProfile.matching(["Novation Launch Control"], automaticOnly: true));
    let d = try #require(p.definition)
    #expect(
        d.inputs.count == 40 && d.outputs.isEmpty && d.shutdown.isEmpty && d.requiresPairedSetup
            && d.inputProtocol?.preservesRawMappings == true)
    #expect(d.startup == [[240, 0, 32, 41, 2, 10, 119, 0, 247], [240, 0, 32, 41, 2, 10, 121, 0, 247]])
    for other in ["Launch Control XL", "Launch Control XL3", "Launch Control 3", "Launch Control clone"] {
        #expect(ControllerFactoryProfile.matching([other], automaticOnly: true) != p)
    }
    for port in d.portAliases! {
        let source = ControllerFactoryEndpoint(id: 10, device: 1, names: [p.rawValue], portNames: [port])
        let output = ControllerFactoryEndpoint(id: 20, device: 1, names: [p.rawValue], portNames: [port])
        #expect(ControllerFactorySession.discover(sources: [source], destinations: [output], disabled: []).count == 1)
        #expect(ControllerFactorySession.discover(sources: [source], destinations: [], disabled: []).isEmpty)
    }
}

@Test @MainActor func controllerCatalogueLaunchControlTemplatePadsAndShiftedFunctionsUsePhysicalPosition() throws {
    try withLaunchControlTemplate() { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        for (side, deck) in DeckID.allCases.enumerated() {
            let play = UInt8(60 + side * 2), cue = play + 1
            events.removeAll(); originalLCPacket([0x93, play, 127, play, 127, play, 0], input)
            #expect(
                events.count == 1 && events.first?.0 == .init(ControllerAction.playA.assigned(to: deck), deck: deck))
            for off: UInt8 in [0x83, 0x93] {
                events.removeAll();
                originalLCPacket([0x93, cue, 127, cue, 127, off, cue, off == 0x83 ? 100 : 0], input)
                #expect(events.map(\.1) == [1, 0] && events.allSatisfy { $0.0.deck == deck })
            }
            originalLCPacket([0xB4, 103, 127], input); events.removeAll()
            originalLCPacket([0x93, play, 127, play, 0, cue, 127, cue, 0], input)
            #expect(
                events.map(\.0) == [
                    .init(ControllerAction.loadA.assigned(to: deck), deck: deck),
                    .init(ControllerAction.cueA.assigned(to: deck), deck: deck),
                ])
            originalLCPacket([0xB4, 103, 0], input)
        }
    }
}

@Test @MainActor func controllerCatalogueLaunchControlTemplateChangesAndShiftReleaseOnlySourceOwnedCue() throws {
    try withLaunchControlTemplate() { input in
        var values: [Double] = [];
        input.onTargetAction = { target, value in
            if target.action == .cuePreviewA && target.deck == .a { values.append(value) }
        }
        for change: [UInt8] in [[240, 0, 32, 41, 2, 10, 119, 8, 247], [0xB4, 103, 127]] {
            values.removeAll(); originalLCPacket([0x93, 61, 127], input);
            originalLCPacket([0x93, 61, 127], input, source: 11)
            originalLCPacket(change, input); #expect(values == [1]); originalLCPacket(change, input, source: 11);
            #expect(values == [1, 0])
            if change.first == 240 {
                #expect(!input.isInputActive(10)); originalLCPacket([0x93, 61, 127], input); #expect(values == [1, 0])
                for source: Int32 in [10, 11] {
                    originalLCPacket([240, 0, 32, 41, 2, 10, 119, 0, 247], input, source: source);
                    originalLCPacket(launchControlTemplateFixture(), input, source: source)
                }
            } else {
                originalLCPacket([0xB4, 103, 0], input); originalLCPacket([0xB4, 103, 0], input, source: 11)
            }
        }
        values.removeAll(); originalLCPacket([0x93, 61, 127], input); input.stop(); #expect(values == [1, 0])
    }
}

@Test @MainActor func controllerCatalogueLaunchControlTemplateMixerAndShiftGainKeepPickupAndChannelIsolation() throws {
    try withLaunchControlTemplate() { input in
        input.currentTargetValue = { _ in 0.5 }; var events: [(ControllerActionTarget, Double)] = [];
        input.onTargetAction = { events.append(($0, $1)) }
        for (side, deck) in DeckID.allCases.enumerated() {
            for (number, action): (UInt8, ControllerAction) in [
                (UInt8(16 + 2 * side), .highA), (UInt8(17 + 2 * side), .midA), (UInt8(24 + 2 * side), .lowA),
                (UInt8(25 + 2 * side), .gainA),
            ] {
                events.removeAll(); originalLCPacket([0xB2, number, 0], input); #expect(events.isEmpty)
                originalLCPacket([0xB2, number, 64], input); originalLCPacket([0xB2, number, 127], input)
                #expect(
                    events.count == 2 && events.last?.1 == 1
                        && events.allSatisfy { $0.0 == .init(action.assigned(to: deck), deck: deck) })
            }
            originalLCPacket([0xB4, 103, 127], input); events.removeAll(); let gain = UInt8(25 + 2 * side)
            originalLCPacket([0xB2, gain, 0], input); #expect(events.isEmpty);
            originalLCPacket([0xB2, gain, 64], input)
            #expect(
                events.count == 1 && events.first?.0 == .init(ControllerAction.levelA.assigned(to: deck), deck: deck))
            originalLCPacket([0xB4, 103, 0], input)
        }
        events.removeAll(); originalLCPacket([0xB0, 16, 127, 0x90, 61, 127, 0xB3, 100, 127], input);
        #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueLaunchControlTemplateRetainsFourDeckOptInAndNativeNavigation() throws {
    try withLaunchControlTemplate(decks: DeckID.primary) { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        originalLCPacket([0x93, 64, 127, 64, 0, 66, 127, 66, 0, 60, 127, 60, 0], input)
        #expect(events == [.init(.playA, deck: .a)])
        events.removeAll(); originalLCPacket([0xB4, 100, 127, 100, 0, 101, 127, 101, 0, 102, 127, 102, 0], input)
        #expect(events.map(\.action) == [.browsePrevious, .browseNext, .openGroup])
    }
}

@Test @MainActor func controllerCatalogueLaunchControlTemplateReadFailureKeepsInputBlocked() throws {
    let name = "Novation Launch Control"
    for fail in 0..<2 {
        let suite = "lc-template-fail-\(UUID().uuidString)"; let preferences = UserDefaults(suiteName: suite)!
        defer { preferences.removePersistentDomain(forName: suite) }
        var packets: [[UInt8]] = []
        let input = ControllerMIDIConnection(
            preferences: preferences,
            factoryPacketSender: { bytes, _ in
                let index = packets.count; packets.append(bytes); return index != fail
            }, factoryInputConnector: { _ in true })
        input.sources = [
            .init(
                id: 10, reference: 10, name: name,
                identity: .init(id: 10, device: 1, names: [name], portNames: ["Launch Control"]))
        ]
        input.destinations = [
            .init(
                id: 20, reference: 20, name: name,
                identity: .init(id: 20, device: 1, names: [name], portNames: ["Launch Control"]))
        ]
        input.reconcileFactoryProfiles(); #expect(!input.isInputActive(10) && packets.count == fail + 1)
        input.receiveBytes(launchControlTemplateFixture(), source: 10); #expect(!input.isInputActive(10))
    }
}

@Test @MainActor func controllerCatalogueLaunchControlTemplateKeepsSavedRawMappingsUntilExplicitReplacement() throws {
    for overCapacity in [false, true] {
        let suite = "lc-template-raw-\(UUID().uuidString)"; let preferences = UserDefaults(suiteName: suite)!
        defer { preferences.removePersistentDomain(forName: suite) }
        var bindings = [
            ControllerBinding(
                source: 10, group: nil, channel: 0, kind: .control, number: 99, parameter: nil, noteNumber: nil,
                action: .crossfader, encoding: nil, inverted: nil, shifted: nil)
        ]
        if overCapacity {
            bindings += (0..<217).map {
                ControllerBinding(
                    source: 11, group: nil, channel: UInt8($0 / 128), kind: .control, number: UInt8($0 % 128),
                    parameter: nil, noteNumber: nil, action: .levelB, encoding: nil, inverted: nil, shifted: nil)
            }
        }
        let saved = try JSONEncoder().encode(bindings)
        preferences.set(saved, forKey: "controllers.midiBindings.v1");
        preferences.set(try JSONEncoder().encode([Int32(10)]), forKey: "controllers.midiActiveInputs.v1")
        var packets: [[UInt8]] = []
        let input = ControllerMIDIConnection(
            preferences: preferences,
            factoryPacketSender: { bytes, _ in
                packets.append(bytes); return true
            }, factoryInputConnector: { _ in true })
        let name = "Novation Launch Control"
        input.sources = [
            .init(
                id: 10, reference: 10, name: name,
                identity: .init(id: 10, device: 1, names: [name], portNames: ["Launch Control"]))
        ]
        input.destinations = [
            .init(
                id: 20, reference: 20, name: name,
                identity: .init(id: 20, device: 1, names: [name], portNames: ["Launch Control"]))
        ]
        input.reconcileFactoryProfiles(); #expect(input.isInputActive(10) && packets.isEmpty)
        #expect(preferences.data(forKey: "controllers.midiBindings.v1") == saved)
        input.currentTargetValue = { _ in 0.5 }; var values: [Double] = [];
        input.onAction = { action, value in if action == .crossfader { values.append(value) } }
        originalLCPacket([0xB0, 99, 64], input); originalLCPacket([0xB0, 99, 127], input);
        #expect(values == [64.0 / 127, 1])
        input.select(10); input.applyFactoryProfile(try #require(ControllerFactoryProfile.matching([name])))
        if overCapacity {
            #expect(
                preferences.data(forKey: "controllers.midiBindings.v1") == saved && packets.isEmpty
                    && input.isInputActive(10))
        } else {
            #expect(input.bindingCount == 40 && !input.isInputActive(10) && packets.count == 2)
            originalLCPacket(launchControlTemplateFixture(), input); #expect(input.isInputActive(10))
        }
    }
}
