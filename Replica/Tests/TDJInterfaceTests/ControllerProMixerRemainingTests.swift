import Foundation
import TDJCore
import Testing

@testable import TDJInterface

private let publicRemainingModels = ["Akai Pro AMX", "ION ICUE", "Reloop DIGITAL JOCKEY"]
@MainActor private func withRemainingPublicController(_ name: String, _ body: (ControllerMIDIConnection) throws -> Void)
    throws
{
    let suite = "remaining-public-\(UUID().uuidString)"; let preferences = UserDefaults(suiteName: suite)!
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
    input.reconcileFactoryProfiles(); #expect(!input.isInputActive(10) && !input.isInputActive(11))
    let p = try #require(ControllerFactoryProfile.matching([name]));
    for source: Int32 in [10, 11] { input.select(source); input.applyFactoryProfile(p) }
    #expect(
        input.isInputActive(10) && input.isInputActive(11) && writes == 0
            && input.bindingCount == p.bindings(source: 10).count * 2);
    try body(input)
}
@MainActor private func remainingPublicPacket(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source); input.flushPendingActions()
}

@Test(arguments: publicRemainingModels) @MainActor
func controllerCatalogueRemainingPublicModelsKeepManualIdentityCapacityAndNoWrites(_ name: String) throws {
    let p = try #require(ControllerFactoryProfile.matching([name])); let d = try #require(p.definition)
    #expect(
        !p.selectsAutomatically
            && d.inputs.count == (name == publicRemainingModels[0] ? 32 : name == publicRemainingModels[1] ? 30 : 118))
    #expect(d.outputs.isEmpty && d.startup.isEmpty && d.shutdown.isEmpty && d.audioOutput == nil)
    #expect(ControllerFactoryProfile.matching([name], automaticOnly: true) == nil)
    for other in ["Digital Jockey2 IE", "ION Discover DJ", "Numark Total Control", "AFX"] {
        #expect(ControllerFactoryProfile.matching([other]) != p)
    }
    try withRemainingPublicController(name) { _ in }
}

@Test(arguments: publicRemainingModels) @MainActor
func controllerCatalogueRemainingPublicCueBothReleasesAndStopKeepSourceOwnership(_ name: String) throws {
    try withRemainingPublicController(name) { input in
        var values: [Double] = [];
        input.onTargetAction = { target, value in
            if target.action == .cuePreviewA && target.deck == .a { values.append(value) }
        }
        let cue: UInt8 = name == publicRemainingModels[0] ? 8 : name == publicRemainingModels[1] ? 51 : 23
        for off: UInt8 in [0x80, 0x90] {
            values.removeAll(); remainingPublicPacket([0x90, cue, 127, cue, 127], input);
            remainingPublicPacket([0x90, cue, 127], input, source: 11)
            remainingPublicPacket([off, cue, off == 0x80 ? 127 : 0], input); #expect(values == [1])
            remainingPublicPacket([off, cue, off == 0x80 ? 127 : 0], input, source: 11); #expect(values == [1, 0])
        }
        values.removeAll(); remainingPublicPacket([0x90, cue, 127], input); input.stop(); #expect(values == [1, 0])
    }
}

@Test(arguments: publicRemainingModels) @MainActor
func controllerCatalogueRemainingPublicIndependentTransportTargetsAndLoadsUseOwnWires(_ name: String) throws {
    try withRemainingPublicController(name) { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        let rows: [(DeckID, [(UInt8, ControllerAction)])]
        if name == publicRemainingModels[0] {
            rows = [
                (.a, [(10, .playA), (6, .syncA), (12, .cueA), (4, .loadA)]),
                (.b, [(11, .playA), (7, .syncA), (13, .cueA), (5, .loadA)]),
            ]
        } else if name == publicRemainingModels[1] {
            rows = [
                (
                    .a,
                    [
                        (67, .playA), (64, .syncA), (56, .keylockA), (48, .cueA), (75, .loadA), (73, .loopInA),
                        (74, .loopOutA),
                    ]
                ),
                (
                    .b,
                    [
                        (76, .playA), (71, .syncA), (63, .keylockA), (55, .cueA), (52, .loadA), (77, .loopInA),
                        (78, .loopOutA),
                    ]
                ),
            ]
        } else {
            rows = [
                (
                    .a,
                    [
                        (25, .playA), (1, .syncA), (2, .keylockA), (5, .cueA), (19, .loadA), (15, .loopInA),
                        (16, .loopOutA), (17, .loopA), (18, .reloopA),
                    ]
                ),
                (
                    .b,
                    [
                        (85, .playA), (61, .syncA), (62, .keylockA), (65, .cueA), (79, .loadA), (75, .loopInA),
                        (76, .loopOutA), (77, .loopA), (78, .reloopA),
                    ]
                ),
            ]
        }
        for (deck, controls) in rows {
            for (number, action) in controls {
                events.removeAll(); remainingPublicPacket([0x90, number, 127, number, 127, number, 0], input)
                #expect(events == [.init(action.assigned(to: deck), deck: deck)])
            }
        }
        events.removeAll(); remainingPublicPacket([0x91, 25, 127, 51, 127, 10, 127, 0xB1, 7, 64, 60, 64], input);
        #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueAMXNormalShiftRetiresOnlyItsOwnCueAndResetsMixerPickup() throws {
    try withRemainingPublicController("Akai Pro AMX") { input in
        input.currentTargetValue = { _ in 0.5 }; var cue: [Double] = []; var gain: [Double] = []
        input.onTargetAction = { target, value in
            if target.action == .cuePreviewA { cue.append(value) }; if target.action == .gainA { gain.append(value) }
        }
        remainingPublicPacket([0x90, 8, 127], input); remainingPublicPacket([0x90, 8, 127], input, source: 11)
        remainingPublicPacket([0xB0, 60, 64], input); remainingPublicPacket([0xB0, 60, 127], input); gain.removeAll()
        remainingPublicPacket([0x90, 0, 127, 8, 0, 10, 127, 10, 0, 0xB0, 60, 0], input);
        #expect(cue == [1] && gain.isEmpty)
        remainingPublicPacket([0x90, 0, 127], input, source: 11); #expect(cue == [1, 0])
        remainingPublicPacket([0x90, 0, 0, 0xB0, 60, 0], input); #expect(gain.isEmpty)
        remainingPublicPacket([0xB0, 60, 64], input); #expect(gain.count == 1)
    }
}

@Test @MainActor func controllerCatalogueOriginalDigitalJockeyBothFamiliesRearmOnCrossFamilyReleases() throws {
    try withRemainingPublicController("Reloop DIGITAL JOCKEY") { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        for base: UInt8 in [0, 60] {
            for number: UInt8 in [1, 2, 3, 4, 5, 15, 16, 17, 18, 19, 23, 25] {
                for family: UInt8 in [0, 30] {
                    for off: UInt8 in [0x80, 0x90] {
                        events.removeAll(); let press = base + family + number;
                        let release = base + (30 - family) + number
                        remainingPublicPacket(
                            [0x90, press, 127, off, release, off == 0x80 ? 127 : 0, 0x90, press, 127, press, 0], input)
                        #expect(events.filter { $0.1 > 0 }.count == 2)
                        if [3, 4, 23].contains(number) { #expect(events.map(\.1) == [1, 0, 1, 0]) }
                    }
                }
            }
        }
    }
}

@Test(arguments: publicRemainingModels) @MainActor
func controllerCatalogueRemainingPublicMixerPickupAndUnqualifiedControlsStayBounded(_ name: String) throws {
    try withRemainingPublicController(name) { input in
        input.currentTargetValue = { _ in 0.5 }; var events: [(ControllerActionTarget, Double)] = [];
        input.onTargetAction = { events.append(($0, $1)) }
        let controls: [(DeckID, UInt8, ControllerAction)] =
            name == publicRemainingModels[0]
            ? [
                (.a, 7, .levelA), (.b, 11, .levelA), (.a, 60, .gainA), (.b, 61, .gainA), (.a, 8, .lowA),
                (.b, 14, .highA),
            ]
            : name == publicRemainingModels[1]
                ? [
                    (.a, 8, .levelA), (.b, 9, .levelA), (.a, 13, .gainA), (.b, 14, .gainA), (.a, 20, .lowA),
                    (.b, 17, .highA),
                ]
                : [
                    (.a, 6, .levelA), (.b, 66, .levelA), (.a, 2, .gainA), (.b, 62, .gainA), (.a, 36, .levelA),
                    (.b, 96, .levelA), (.a, 32, .gainA), (.b, 92, .gainA),
                ]
        for (deck, number, action) in controls {
            events.removeAll(); remainingPublicPacket([0xB0, number, 0], input); #expect(events.isEmpty)
            remainingPublicPacket([0xB0, number, 64], input); remainingPublicPacket([0xB0, number, 127], input)
            #expect(
                events.count == 2 && events.last?.1 == 1
                    && events.allSatisfy { $0.0 == .init(action.assigned(to: deck), deck: deck) })
        }
        events.removeAll()
        if name == publicRemainingModels[0] {
            remainingPublicPacket([0xB0, 51, 127, 55, 127, 59, 65, 0x90, 102, 127, 103, 127, 26, 127], input)
        } else if name == publicRemainingModels[1] {
            remainingPublicPacket(
                [0xB0, 10, 127, 15, 127, 23, 127, 24, 65, 25, 65, 26, 65, 0x90, 59, 127, 68, 127], input)
        } else {
            remainingPublicPacket(
                [
                    0xB0, 11, 65, 71, 65, 41, 65, 101, 65, 19, 65, 49, 65, 15, 127, 0x90, 24, 127, 54, 127, 84, 127,
                    114, 127, 29, 127, 89, 127,
                ], input)
        }
        remainingPublicPacket([0xE0, 0, 127, 0xE1, 0, 127], input); #expect(events.isEmpty)
    }
}
