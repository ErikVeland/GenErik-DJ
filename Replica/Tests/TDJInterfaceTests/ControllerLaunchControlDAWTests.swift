import Foundation
import TDJCore
import Testing

@testable import TDJInterface

private let launchControlDAWModels = ["Novation Launch Control 3", "Novation LaunchControl XL3"]

@MainActor private func withLaunchControlDAW(
    _ name: String, decks: [DeckID] = DeckID.allCases, _ body: (ControllerMIDIConnection) throws -> Void
) throws {
    let suite = "launch-control-daw-\(UUID().uuidString)"; let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let profile = try #require(ControllerFactoryProfile.matching([name]));
    let port = try #require(profile.definition?.portAliases?.first)
    let input = ControllerMIDIConnection(
        preferences: preferences, factoryPacketSender: { _, _ in true }, deckAvailability: { decks },
        factoryInputConnector: { _ in true })
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id), name: name,
            identity: .init(id: id, device: UInt32(id), names: [name], portNames: [port]))
    }
    input.destinations = [20, 21].map { id in
        .init(
            id: id, reference: UInt32(id), name: name,
            identity: .init(id: id, device: UInt32(id - 10), names: [name], portNames: [port]))
    }
    input.reconcileFactoryProfiles(); #expect(input.isInputActive(10) && input.isInputActive(11)); try body(input)
}

@MainActor private func launchControlDAWPacket(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10)
{
    input.receiveBytes(bytes, source: source); input.flushPendingActions()
}

@Test(arguments: launchControlDAWModels) @MainActor
func controllerCatalogueLaunchControlDAWUsesIndependentProductsAndOnlyPairedDAWPorts(_ name: String) throws {
    let p = try #require(ControllerFactoryProfile.matching([name], automaticOnly: true));
    let d = try #require(p.definition)
    let xl = name == launchControlDAWModels[1]; let product: UInt8 = xl ? 21 : 22
    #expect(
        d.inputs.count == (xl ? 54 : 25) && d.outputs.count == (xl ? 36 : 24) && d.requiresPairedSetup
            && d.audioOutput == nil)
    #expect(d.startup.first == [240, 0, 32, 41, 2, product, 2, 127, 247] && d.startup[1] == [182, 30, 2])
    #expect(d.shutdown.last == [240, 0, 32, 41, 2, product, 2, 0, 247] && d.startupAbort == [d.shutdown.last!])
    for other in [
        "Launch Control", "Launch Control XL", "Launch Control XL MK2", xl ? "Launch Control 3" : "Launch Control XL 3",
        name + " clone",
    ] {
        #expect(ControllerFactoryProfile.matching([other], automaticOnly: true) != p)
    }
    for port in ["MIDI", "MIDI In", "DIN", "To DIN Out", d.portAliases!.first!] {
        let source = ControllerFactoryEndpoint(id: 10, device: 1, names: [name], portNames: [port])
        let output = ControllerFactoryEndpoint(id: 20, device: 1, names: [name], portNames: [port])
        let sessions = ControllerFactorySession.discover(sources: [source], destinations: [output], disabled: [])
        #expect(sessions.count == (port == d.portAliases!.first! ? 1 : 0))
        #expect(ControllerFactorySession.discover(sources: [source], destinations: [], disabled: []).isEmpty)
        #expect(
            ControllerFactorySession.discover(
                sources: [source], destinations: [output, .init(id: 21, device: 1, names: [name], portNames: [port])],
                disabled: []
            ).isEmpty)
    }
}

@Test(arguments: launchControlDAWModels) @MainActor
func controllerCatalogueLaunchControlDAWButtonsUseCCReleasesAndExactDeckPairs(_ name: String) throws {
    try withLaunchControlDAW(name) { input in
        let xl = name == launchControlDAWModels[1]
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        for (side, deck) in DeckID.allCases.enumerated() {
            let play = UInt8(37 + 2 * side), cue = play + 1
            events.removeAll(); launchControlDAWPacket([0xB0, play, 127, play, 127, play, 0], input)
            #expect(
                events.count == 1 && events.first?.0 == .init(ControllerAction.playA.assigned(to: deck), deck: deck))
            events.removeAll(); launchControlDAWPacket([0xB0, cue, 127, cue, 127, cue, 0], input)
            #expect(
                events.map(\.1) == [1, 0]
                    && events.allSatisfy { $0.0 == .init(ControllerAction.cuePreviewA.assigned(to: deck), deck: deck) })
            if xl {
                for (number, action): (UInt8, ControllerAction) in [(play + 8, .syncA), (cue + 8, .loadA)] {
                    events.removeAll(); launchControlDAWPacket([0xB0, number, 127, number, 0], input)
                    #expect(events.count == 1 && events.first?.0 == .init(action.assigned(to: deck), deck: deck))
                }
            }
        }
        events.removeAll(); launchControlDAWPacket([0x90, 38, 127, 0xB1, 38, 127, 0xBE, 13, 127], input);
        #expect(events.isEmpty)
    }
}

@Test(arguments: launchControlDAWModels) @MainActor
func controllerCatalogueLaunchControlDAWModeAndShiftRetireOnlyOwnedHolds(_ name: String) throws {
    try withLaunchControlDAW(name) { input in
        var values: [Double] = [];
        input.onTargetAction = { target, value in
            if target.action == .cuePreviewA && target.deck == .a { values.append(value) }
        }
        for change: [UInt8] in [[0xB6, 30, 6], [0xB6, 30, 1], [0xB6, 63, 127]] {
            values.removeAll()
            launchControlDAWPacket([0xB0, 38, 127], input); launchControlDAWPacket([0xB0, 38, 127], input, source: 11)
            launchControlDAWPacket(change, input); #expect(values == [1])
            launchControlDAWPacket(change, input, source: 11); #expect(values == [1, 0])
            if change[1] == 30 && change[2] == 6 {
                #expect(!input.isInputActive(10) && !input.isInputActive(11))
                launchControlDAWPacket([0xB0, 38, 127, 0xBF, 13, 127], input); #expect(values == [1, 0])
            }
            launchControlDAWPacket([0xB6, 30, 2, 63, 0], input);
            launchControlDAWPacket([0xB6, 30, 2, 63, 0], input, source: 11)
            #expect(input.isInputActive(10) && input.isInputActive(11))
        }
        values.removeAll(); launchControlDAWPacket([0xB0, 38, 127], input); input.stop(); #expect(values == [1, 0])
    }
}

@Test(arguments: launchControlDAWModels) @MainActor
func controllerCatalogueLaunchControlDAWMixerPickupAndModeResetUseExactSurfaceIndices(_ name: String) throws {
    try withLaunchControlDAW(name) { input in
        let xl = name == launchControlDAWModels[1]; input.currentTargetValue = { _ in 0.5 }
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        for (side, deck) in DeckID.allCases.enumerated() {
            var rows: [(UInt8, ControllerAction)] = [
                (UInt8(13 + 2 * side), .highA), (UInt8(14 + 2 * side), .midA), (UInt8(21 + 2 * side), .lowA),
                (UInt8(22 + 2 * side), xl ? .filterKnobA : .gainA),
            ]
            if xl {
                rows += [
                    (UInt8(29 + 2 * side), .gainA), (UInt8(30 + 2 * side), .levelA), (UInt8(5 + 2 * side), .levelA),
                    (UInt8(6 + 2 * side), .gainA),
                ]
            }
            for (number, action) in rows {
                events.removeAll(); launchControlDAWPacket([0xBF, number, 0], input); #expect(events.isEmpty)
                launchControlDAWPacket([0xBF, number, 64], input); launchControlDAWPacket([0xBF, number, 127], input)
                #expect(
                    events.count == 2 && events.last?.1 == 1
                        && events.allSatisfy { $0.0 == .init(action.assigned(to: deck), deck: deck) })
            }
        }
        launchControlDAWPacket([0xB6, 30, 6, 30, 2], input); events.removeAll();
        launchControlDAWPacket([0xBF, 13, 0], input); #expect(events.isEmpty)
        launchControlDAWPacket([0xBF, 13, 64], input); #expect(events.count == 1)
    }
}

@Test(arguments: launchControlDAWModels) @MainActor
func controllerCatalogueLaunchControlDAWFeedbackUsesSeparateColourAndPositionChannels(_ name: String) throws {
    let p = try #require(ControllerFactoryProfile.matching([name]))
    for output in p.feedback(destination: 20) {
        if output.channel == 15 {
            #expect(
                output.message(value: 0.5) == [0xBF, output.number, 64]
                    && output.message(value: 1) == [0xBF, output.number, 127])
        } else {
            let colour: UInt8 =
                output.action == .playA || output.action == .playB
                ? 19 : output.action == .cuePreviewA || output.action == .cuePreviewB ? 5 : 45
            #expect(
                output.message(value: 1) == [0xB0, output.number, colour]
                    && output.message(value: 0) == [0xB0, output.number, 0])
        }
    }
}

@Test(arguments: launchControlDAWModels) @MainActor
func controllerCatalogueLaunchControlDAWExitsAfterEachPartialSetupFailureAndOnStop(_ name: String) throws {
    let p = try #require(ControllerFactoryProfile.matching([name])); let d = try #require(p.definition);
    let port = d.portAliases!.first!
    for failure in 0...d.startup.count {
        let suite = "lc-daw-failure-\(UUID().uuidString)"; let preferences = UserDefaults(suiteName: suite)!
        defer { preferences.removePersistentDomain(forName: suite) }
        var packets: [[UInt8]] = []
        let input = ControllerMIDIConnection(
            preferences: preferences,
            factoryPacketSender: { bytes, _ in
                let index = packets.count; packets.append(bytes); return index != failure
            }, factoryInputConnector: { _ in true })
        input.sources = [
            .init(
                id: 10, reference: 10, name: name, identity: .init(id: 10, device: 1, names: [name], portNames: [port]))
        ]
        input.destinations = [
            .init(
                id: 20, reference: 20, name: name, identity: .init(id: 20, device: 1, names: [name], portNames: [port]))
        ]
        input.reconcileFactoryProfiles()
        if failure < d.startup.count {
            #expect(!input.isInputActive(10));
            #expect(packets == Array(d.startup.prefix(failure + 1)) + (d.startupAbort ?? []))
        } else {
            #expect(input.isInputActive(10)); #expect(packets == d.startup); packets.removeAll(); input.stop();
            #expect(packets == d.shutdown)
        }
    }
}

@Test(arguments: launchControlDAWModels) @MainActor
func controllerCatalogueLaunchControlDAWKeepsFourDeckOptInAndXLNavigation(_ name: String) throws {
    try withLaunchControlDAW(name, decks: DeckID.primary) { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        launchControlDAWPacket([0xB0, 41, 127, 41, 0, 43, 127, 43, 0, 37, 127, 37, 0], input)
        #expect(events == [.init(.playA, deck: .a)])
        events.removeAll()
        for number: UInt8 in [106, 107, 103, 102, 104] {
            launchControlDAWPacket([0xB0, number, 127, number, 0], input)
        }
        #expect(
            events.map(\.action)
                == (name == launchControlDAWModels[1]
                    ? [.browsePreviousGroup, .browseNextGroup, .browsePrevious, .browseNext, .openGroup] : []))
    }
}
