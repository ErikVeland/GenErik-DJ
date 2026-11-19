import Foundation
import TDJCore
import Testing

@testable import TDJInterface

private let legacyUSBModels = ["American Audio VERSADECK", "Synq DMC-2000", "CITRONIC MPX10"]
@MainActor private func withLegacyUSBPlayer(_ name: String, _ body: (ControllerMIDIConnection) throws -> Void) throws {
    let suite = "legacy-usb-\(UUID().uuidString)"; let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences, factoryPacketSender: { _, _ in true }, factoryInputConnector: { _ in true })
    input.sources = [10, 11].map { id in
        .init(id: id, reference: UInt32(id), name: name, identity: .init(id: id, device: UInt32(id), names: [name]))
    }
    input.reconcileFactoryProfiles(); #expect(input.isInputActive(10) && input.isInputActive(11)); try body(input)
}
@MainActor private func legacyUSBPacket(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source); input.flushPendingActions()
}

@Test(arguments: legacyUSBModels) @MainActor
func controllerCatalogueLegacyUSBDefaultsKeepIndependentIdentityAndNoModeOrAudioWrites(_ name: String) throws {
    let p = try #require(ControllerFactoryProfile.matching([name], automaticOnly: true));
    let d = try #require(p.definition)
    #expect(
        d.inputs.count == 78 && d.outputs.count == 16 && d.startup.isEmpty && d.shutdown.isEmpty && d.audioOutput == nil
            && d.inputProtocol == .legacyUSBPlayer)
    #expect(ControllerFactoryProfile.matching([name + " clone"]) != p)
    #expect(ControllerFactoryProfile.matching(["DMC-1000"]) != p)
}

@Test(arguments: legacyUSBModels) @MainActor
func controllerCatalogueLegacyUSBDefaultButtonsAndBothCueReleasesUseManufacturerDeckChannels(_ name: String) throws {
    try withLegacyUSBPlayer(name) { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        for (channel, deck): (UInt8, DeckID) in [(0, .a), (2, .b)] {
            for (number, action): (UInt8, ControllerAction) in [
                (32, .playA), (29, .keylockA), (2, .loopInA), (3, .loopOutA), (4, .reloopA), (1, .loadA),
                (8, .hotcue1A), (9, .hotcue2A), (10, .hotcue3A), (11, .hotcue4A),
                (13, name == legacyUSBModels[1] ? .loadA : .cueA),
            ] {
                events.removeAll(); legacyUSBPacket([0x90 + channel, number, 127, number, 127, number, 0], input)
                #expect(events.count == 1 && events.first?.0 == .init(action.assigned(to: deck), deck: deck))
            }
            events.removeAll(); legacyUSBPacket([0x90 + channel, 5, 127, 5, 0], input);
            #expect(events.map(\.0.action) == [.openGroup])
            for off: UInt8 in [0x80 + channel, 0x90 + channel] {
                events.removeAll();
                legacyUSBPacket([0x90 + channel, 31, 127, 31, 127, off, 31, off < 0x90 ? 127 : 0], input)
                #expect(
                    events.map(\.1) == [1, 0]
                        && events.allSatisfy {
                            $0.0 == .init(ControllerAction.cuePreviewA.assigned(to: deck), deck: deck)
                        })
            }
        }
    }
}

@Test(arguments: legacyUSBModels) @MainActor
func controllerCatalogueLegacyUSBAlternateReleasesRearmEveryNormalButtonWithoutExtraActions(_ name: String) throws {
    try withLegacyUSBPlayer(name) { input in
        let profile = try #require(ControllerFactoryProfile.matching([name]));
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        let buttons = profile.bindings(source: 10).filter { $0.kind == .note && $0.releaseOnly != true }
        for binding in buttons {
            for off: UInt8 in [0x80 + binding.channel, 0x90 + binding.channel] {
                events.removeAll();
                legacyUSBPacket(
                    [0x90 + binding.channel, binding.number, 127, off, binding.number + 63, off < 0x90 ? 127 : 0], input
                )
                legacyUSBPacket([0x90 + binding.channel, binding.number, 127, binding.number, 0], input)
                #expect(events.filter { $0.1 > 0 }.count == 2)
                if binding.action.isMomentary { #expect(events.map(\.1) == [1, 0, 1, 0]) }
            }
        }
    }
}

@Test(arguments: legacyUSBModels) @MainActor
func controllerCatalogueLegacyUSBShiftContextRetiresOnlyItsSourceAndChannel(_ name: String) throws {
    try withLegacyUSBPlayer(name) { input in
        var values: [Double] = [];
        input.onTargetAction = { target, value in if target.action == .cuePreviewA { values.append(value) } }
        legacyUSBPacket([0x90, 31, 127], input); legacyUSBPacket([0x90, 31, 127], input, source: 11)
        legacyUSBPacket([0x90, 94, 127], input); #expect(values == [1])
        legacyUSBPacket([0x90, 94, 127], input, source: 11); #expect(values == [1, 0])
        legacyUSBPacket([0x80, 31, 127, 0x90, 94, 0], input)
        legacyUSBPacket([0x90, 31, 127], input); #expect(values == [1, 0, 1])
        legacyUSBPacket([0xB2, 33, 64, 96, 64], input); legacyUSBPacket([0xB1, 48, 64, 111, 64], input);
        #expect(values == [1, 0, 1])
        input.stop(); #expect(values == [1, 0, 1, 0])
    }
}

@Test(arguments: legacyUSBModels) @MainActor
func controllerCatalogueLegacyUSBMixerPickupReturnsAfterShiftWithoutResettingOtherOwners(_ name: String) throws {
    try withLegacyUSBPlayer(name) { input in
        input.currentTargetValue = { _ in 0.5 }; var events: [ControllerActionTarget] = [];
        input.onTargetAction = { target, _ in events.append(target) }
        for (channel, number): (UInt8, UInt8) in [(0, 17), (2, 33), (1, 48)] {
            legacyUSBPacket([0xB0 + channel, number, 64], input); legacyUSBPacket([0xB0 + channel, number, 127], input)
            events.removeAll(); legacyUSBPacket([0xB0 + channel, number + 63, 0], input); #expect(events.isEmpty)
            legacyUSBPacket([0xB0 + channel, number, 0], input); #expect(events.isEmpty)
            legacyUSBPacket([0xB0 + channel, number, 64], input); #expect(events.count == 1)
        }
        legacyUSBPacket([0xB0, 17, 64], input, source: 11); events.removeAll()
        legacyUSBPacket([0xB0, 80, 0], input); legacyUSBPacket([0xB0, 17, 127], input, source: 11);
        #expect(events.count == 1)
        events.removeAll(); legacyUSBPacket([0xB2, 33, 127], input);
        #expect(events.count == 1 && events.first?.deck == .b)
    }
}

@Test(arguments: legacyUSBModels) @MainActor
func controllerCatalogueLegacyUSBBrowsersUseDocumentedMultiStepOffsetsAndRejectOtherChannels(_ name: String) throws {
    try withLegacyUSBPlayer(name) { input in
        var events: [(ControllerAction, Double)] = []; input.onAction = { events.append(($0, $1)) }
        for (channel, base): (UInt8, UInt8) in [(0, 22), (2, 38)] {
            for (number, action): (UInt8, ControllerAction) in [(base, .browse), (base + 1, .browseGroups)] {
                events.removeAll(); legacyUSBPacket([0xB0 + channel, number, 64], input); #expect(events.isEmpty)
                legacyUSBPacket([0xB0 + channel, number, 67], input);
                legacyUSBPacket([0xB0 + channel, number, 49], input)
                #expect(events.map(\.0) == [action, action] && events.map(\.1) == [0.5 + 3.0 / 126, 0.5 - 15.0 / 126])
            }
        }
        events.removeAll()
        for channel: UInt8 in [0, 2] {
            legacyUSBPacket(
                [
                    0x90 + channel, 30, 127, 33, 127, 12, 127, 24, 127, 27, 127, 0xB0 + channel, 24, 65, 40, 65,
                    0xE0 + channel, 0, 127,
                ], input)
        }
        legacyUSBPacket([0x91, 31, 127, 32, 127, 0x93, 31, 127, 0xB3, 17, 64, 0xB1, 17, 64], input);
        #expect(events.isEmpty)
    }
}

@Test(arguments: legacyUSBModels) @MainActor
func controllerCatalogueLegacyUSBFeedbackUsesOwnRedColourRulesAndExactDecks(_ name: String) throws {
    let p = try #require(ControllerFactoryProfile.matching([name])); let lamps = p.feedback(destination: 20);
    #expect(lamps.count == 16)
    for lamp in lamps {
        let red: UInt8 = name == legacyUSBModels[0] && (8...11).contains(lamp.number) ? 1 : 127
        #expect([UInt8(0), 2].contains(lamp.channel))
        #expect(lamp.message(value: 1) == [0x90 + lamp.channel, lamp.number, red])
        #expect(lamp.message(value: 0) == [0x90 + lamp.channel, lamp.number, 0])
    }
}
