import Foundation
import TDJCore
import Testing

@testable import TDJInterface
private let bmiCoreModels = ["BeyondMusic (BMI) ABMA1", "BeyondMusic (BMI) ABMA3"]

@MainActor private func withBMICore(_ name: String, _ body: (ControllerMIDIConnection) throws -> Void) throws {
    let suite = "bmi-core-\(UUID().uuidString)"; let preferences = UserDefaults(suiteName: suite)!
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
    input.reconcileFactoryProfiles(); #expect(!input.isInputActive(10) && !input.isInputActive(11) && writes == 0)
    let p = try #require(ControllerFactoryProfile.matching([name]))
    for source: Int32 in [10, 11] { input.select(source); input.applyFactoryProfile(p) }
    #expect(input.bindingCount == p.bindings(source: 10).count * 2 && writes == 0); try body(input)
}
@MainActor private func bmiCorePacket(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source); input.flushPendingActions()
}

@Test(arguments: bmiCoreModels) @MainActor func controllerCatalogueBMICoreIndependentManualIdentityAndNoSetup(
    _ name: String
) throws {
    let p = try #require(ControllerFactoryProfile.matching([name])); let d = try #require(p.definition)
    let first = name.hasSuffix("1")
    #expect(
        d.isValid && !p.selectsAutomatically && d.inputs.count == (first ? 55 : 58)
            && d.outputs.count == (first ? 12 : 14))
    #expect(d.startup.isEmpty && d.shutdown.isEmpty && d.audioOutput == nil && d.inputProtocol == nil)
    for generic in ["ABMA USBAUDIO", "JB Systems DJ-KONTROL 2", "JB Systems DJ-KONTROL 3", "Beyond Music Abm4"] {
        #expect(ControllerFactoryProfile.matching([generic]) != p)
    }
    try withBMICore(name) { _ in }
}

@Test(arguments: bmiCoreModels) @MainActor func controllerCatalogueBMICoreOwnCueContractAndBendReleaseOwnership(
    _ name: String
) throws {
    try withBMICore(name) { input in
        var events: [(ControllerAction, Double)] = [];
        input.onTargetAction = { target, value in if !target.action.isJog { events.append((target.action, value)) } }
        for (wire, action): (UInt8, ControllerAction) in [
            (51, .cuePreviewA), (60, .cuePreviewB), (121, .pitchBendDownA), (120, .pitchBendUpA),
            (104, .pitchBendDownB), (103, .pitchBendUpB),
        ] {
            for off: UInt8 in [0x80, 0x90] {
                events.removeAll(); bmiCorePacket([0x90, wire, 127, wire, 127], input)
                bmiCorePacket([0x90, wire, 127], input, source: 11)
                bmiCorePacket([off, wire, off == 0x80 ? 127 : 0], input)
                let active = wire > 100 || name.hasSuffix("3")
                #expect(events.map(\.1) == (active ? [1] : []))
                bmiCorePacket([off, wire, off == 0x80 ? 127 : 0], input, source: 11)
                #expect(events.map(\.1) == (active ? [1, 0] : []) && events.allSatisfy { $0.0 == action })
            }
        }
        events.removeAll(); bmiCorePacket([0x90, 121, 127], input); input.stop(); #expect(events.map(\.1) == [1, 0])
    }
}

@Test(arguments: bmiCoreModels) @MainActor
func controllerCatalogueBMICoreOwnNativeButtonsLoopsAndRejectedConditionalRoles(_ name: String) throws {
    try withBMICore(name) { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        for (wire, action, deck): (UInt8, ControllerAction, DeckID) in [
            (67, .playA, .a), (76, .playB, .b), (75, .loadA, .a), (52, .loadB, .b), (64, .syncA, .a), (71, .syncB, .b),
            (56, .keylockA, .a), (63, .keylockB, .b), (85, .cueA, .a), (86, .cueB, .b), (73, .loopInA, .a),
            (78, .loopOutB, .b), (112, .reloopA, .a), (95, .reloopB, .b), (115, .hotcue1A, .a), (100, .hotcue3B, .b),
        ] {
            events.removeAll(); bmiCorePacket([0x90, wire, 127, wire, 127, wire, 0], input)
            #expect(events.count == 1 && events.first?.0 == .init(action, deck: deck))
        }
        for (wire, beats, deck): (UInt8, Double, DeckID) in [
            (109, 2, .a), (110, 4, .a), (111, 8, .a), (92, 2, .b), (93, 4, .b), (94, 8, .b),
        ] {
            events.removeAll(); bmiCorePacket([0x90, wire, 127, wire, 0], input)
            #expect(events.count == 1 && events.first?.0.argument == beats && events.first?.0.deck == deck)
        }
        events.removeAll();
        bmiCorePacket(
            [
                0x90, 59, 127, 68, 127, 90, 127, 87, 127, 4, 127, 5, 127, 0xB0, 0, 1, 4, 127, 22, 64, 23, 64, 0x91, 67,
                127, 0xE0, 0, 64,
            ], input)
        #expect(events.isEmpty)
    }
}

@Test(arguments: bmiCoreModels) @MainActor func controllerCatalogueBMICoreIndependentAxesLibraryAnd330CountWheelBend(
    _ name: String
) throws {
    try withBMICore(name) { input in
        input.currentTargetValue = { _ in 0.5 }; var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        for (wire, action, deck): (UInt8, ControllerAction, DeckID) in [
            (8, .levelA, .a), (9, .levelB, .b), (13, .gainA, .a), (14, .gainB, .b), (16, .highA, .a), (17, .highB, .b),
            (18, .midA, .a), (19, .midB, .b), (20, .lowA, .a), (21, .lowB, .b), (11, .tempoA, .a), (12, .tempoB, .b),
        ] {
            events.removeAll(); bmiCorePacket([0xB0, wire, 64], input); bmiCorePacket([0xB0, wire, 127], input)
            #expect(events.count == 2 && events.last?.0 == .init(action, deck: deck) && events.last?.1 == 1)
        }
        events.removeAll(); bmiCorePacket([0xB0, 10, 64], input); bmiCorePacket([0xB0, 10, 0], input)
        #expect(events.last?.0.action == .crossfader && events.last?.1 == 1)
        events.removeAll(); bmiCorePacket([0xB0, 34, 64], input)
        #expect(events.count == (name.hasSuffix("3") ? 1 : 0))
        events.removeAll(); bmiCorePacket([0xB0, 26, 1], input); bmiCorePacket([0xB0, 26, 127], input)
        #expect(events.map(\.1) == [0.5 + 1.0 / 126, 0.5 - 1.0 / 126])
        var jogs: [ControllerMIDIValue] = [];
        input.onJogAction = { target, value in
            #expect(target.argument == 330 && target.deck == .a); jogs.append(value)
        }
        bmiCorePacket([0xB0, 25, 1], input); bmiCorePacket([0xB0, 25, 127], input)
        #expect(jogs == [.relative(1), .relative(-1)])
    }
}

@Test(arguments: bmiCoreModels) @MainActor func controllerCatalogueBMICoreOwnLampAddressesStaySeparateFromInputs(
    _ name: String
) throws {
    let p = try #require(ControllerFactoryProfile.matching([name])); let lamps = p.feedback(destination: 20)
    #expect(lamps.first { $0.action == .playA }?.number == 37 && lamps.first { $0.action == .playB }?.number == 84)
    #expect(lamps.first { $0.action == .cueA }?.number == 101 && lamps.first { $0.action == .cueB }?.number == 97)
    for lamp in lamps {
        #expect(lamp.message(value: 1) == [0x90, lamp.number, 127])
        #expect(lamp.message(value: 0) == [0x90, lamp.number, 0])
    }
}
