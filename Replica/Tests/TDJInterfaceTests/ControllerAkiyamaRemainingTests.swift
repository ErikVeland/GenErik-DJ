import Foundation
import TDJCore
import Testing

@testable import TDJInterface

private let remainingAkiyamaModels = ["Akiyama Pulsar", "Akiyama Tempus", "Akiyama Syncron"]
@MainActor private func withRemainingAkiyama(_ name: String, _ body: (ControllerMIDIConnection) throws -> Void) throws {
    let suite = "akiyama-remaining-\(UUID().uuidString)"; let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    var packets = 0
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { _, _ in
            packets += 1; return true
        }, factoryInputConnector: { _ in true })
    input.sources = [10, 11].map { id in
        .init(id: id, reference: UInt32(id), name: name, identity: .init(id: id, device: UInt32(id), names: [name]))
    }
    input.reconcileFactoryProfiles(); #expect(!input.isInputActive(10) && !input.isInputActive(11))
    let p = try #require(ControllerFactoryProfile.matching([name]))
    for source: Int32 in [10, 11] { input.select(source); input.applyFactoryProfile(p) }
    #expect(input.isInputActive(10) && input.isInputActive(11) && packets == 0); try body(input)
}
@MainActor private func remainingAkiyamaPacket(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10)
{ input.receiveBytes(bytes, source: source); input.flushPendingActions() }

@Test(arguments: remainingAkiyamaModels) @MainActor
func controllerCatalogueRemainingAkiyamaSubsetsRemainManualWithNoHardwareWrites(_ name: String) throws {
    let p = try #require(ControllerFactoryProfile.matching([name])); let d = try #require(p.definition)
    #expect(!p.selectsAutomatically && d.inputs.count == (name.hasSuffix("Syncron") ? 11 : 45))
    #expect(
        d.outputs.isEmpty && d.startup.isEmpty && d.shutdown.isEmpty && d.audioOutput == nil && d.inputProtocol == nil)
    #expect(ControllerFactoryProfile.matching([name], automaticOnly: true) == nil)
    #expect(ControllerFactoryProfile.matching([name + " clone"]) != p)
}

@Test(arguments: Array(remainingAkiyamaModels.prefix(2))) @MainActor
func controllerCatalogueRemainingAkiyamaNormalButtonsAndBothCueReleaseFormsUseExplicitABWires(_ name: String) throws {
    try withRemainingAkiyama(name) { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        for (channel, deck): (UInt8, DeckID) in [(0, .a), (1, .b)] {
            for (number, action): (UInt8, ControllerAction) in [
                (24, .playA), (18, .syncA), (34 + channel, .loadA), (16, .keylockA), (28, .cueA), (4, .loopInA),
                (5, .loopOutA), (6, .loopA), (8, .hotcue1A), (9, .hotcue2A), (10, .hotcue3A), (11, .hotcue4A),
            ] {
                events.removeAll();
                remainingAkiyamaPacket([0x90 + channel, number, 127, number, 127, number, 0], input)
                #expect(events.count == 1 && events.first?.0 == .init(action.assigned(to: deck), deck: deck))
            }
            for off: UInt8 in [0x80 + channel, 0x90 + channel] {
                events.removeAll();
                remainingAkiyamaPacket([0x90 + channel, 23, 127, 23, 127, off, 23, off < 0x90 ? 127 : 0], input)
                #expect(
                    events.map(\.1) == [1, 0]
                        && events.allSatisfy {
                            $0.0 == .init(ControllerAction.cuePreviewA.assigned(to: deck), deck: deck)
                        })
            }
            for (number, action): (UInt8, ControllerAction) in [(19, .pitchBendDownA), (20, .pitchBendUpA)] {
                events.removeAll();
                remainingAkiyamaPacket([0x90 + channel, number, 127, 0x80 + channel, number, 127], input)
                #expect(
                    events.map(\.1) == [1, 0]
                        && events.allSatisfy { $0.0 == .init(action.assigned(to: deck), deck: deck) })
            }
        }
        events.removeAll(); remainingAkiyamaPacket([0x92, 24, 127, 24, 0, 0x93, 23, 127, 23, 0], input);
        #expect(events.isEmpty)
    }
}

@Test(arguments: Array(remainingAkiyamaModels.prefix(2))) @MainActor
func controllerCatalogueRemainingAkiyamaComposedShiftAndSourceOwnedCueCleanupUseHoldMode(_ name: String) throws {
    try withRemainingAkiyama(name) { input in
        var values: [Double] = [];
        input.onTargetAction = { target, value in
            if target.action == .cuePreviewA && target.deck == .a { values.append(value) }
        }
        remainingAkiyamaPacket([0x90, 23, 127], input); remainingAkiyamaPacket([0x90, 23, 127], input, source: 11)
        remainingAkiyamaPacket([0x90, 45, 127], input); #expect(values == [1])
        remainingAkiyamaPacket([0x91, 45, 127], input, source: 11); #expect(values == [1, 0])
        remainingAkiyamaPacket([0x90, 45, 0], input); remainingAkiyamaPacket([0x91, 45, 0], input, source: 11)
        var actions: [ControllerAction] = []; input.onTargetAction = { target, _ in actions.append(target.action) }
        remainingAkiyamaPacket([0x90, 45, 127, 0x91, 45, 127, 0x90, 45, 0, 24, 127, 24, 0], input);
        #expect(actions.isEmpty)
        remainingAkiyamaPacket([0x91, 45, 0, 0x90, 24, 127, 24, 0], input); #expect(actions == [.playA])
        values.removeAll();
        input.onTargetAction = { target, value in if target.action == .cuePreviewA { values.append(value) } }
        remainingAkiyamaPacket([0x90, 23, 127], input); input.stop(); #expect(values == [1, 0])
    }
}

@Test(arguments: remainingAkiyamaModels) @MainActor
func controllerCatalogueRemainingAkiyamaCommonMixerFactsKeepPerControlPickupAndStrictChannels(_ name: String) throws {
    try withRemainingAkiyama(name) { input in
        input.currentTargetValue = { _ in 0.5 }; var events: [(ControllerActionTarget, Double)] = [];
        input.onTargetAction = { events.append(($0, $1)) }
        let syncron = name.hasSuffix("Syncron")
        for (channel, deck): (UInt8, DeckID) in [(0, .a), (1, .b)] {
            let controls: [(UInt8, ControllerAction)] =
                syncron
                ? [
                    (16 + 16 * channel, .levelA), (17 + 16 * channel, .gainA), (18 + 16 * channel, .highA),
                    (19 + 16 * channel, .midA), (20 + 16 * channel, .lowA),
                ] : [(7, .levelA), (3, .gainA), (4, .highA), (5, .midA), (6, .lowA)]
            for (number, action) in controls {
                events.removeAll(); remainingAkiyamaPacket([0xB0 + channel, number, 0], input); #expect(events.isEmpty)
                remainingAkiyamaPacket([0xB0 + channel, number, 64], input);
                remainingAkiyamaPacket([0xB0 + channel, number, 127], input)
                #expect(
                    events.count == 2 && events.last?.1 == 1
                        && events.allSatisfy { $0.0 == .init(action.assigned(to: deck), deck: deck) })
            }
        }
        let globals: [(UInt8, UInt8, ControllerAction)] =
            syncron ? [(4, 48, .crossfader)] : [(0, 16, .crossfader), (0, 19, .cueMix), (0, 20, .monitor)]
        for (channel, number, action) in globals {
            events.removeAll(); remainingAkiyamaPacket([0xB0 + channel, number, 0], input); #expect(events.isEmpty)
            remainingAkiyamaPacket([0xB0 + channel, number, 64], input);
            remainingAkiyamaPacket([0xB0 + channel, number, 127], input)
            #expect(events.count == 2 && events.last?.1 == 1 && events.allSatisfy { $0.0.action == action })
        }
        events.removeAll(); remainingAkiyamaPacket([0xB5, 48, 127, 0xB2, 3, 127, 0xB3, 6, 127, 0xE0, 0, 127], input);
        #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueRemainingAkiyamaSyncronDisputedTransportAndJogWiresStayInactive() throws {
    try withRemainingAkiyama("Akiyama Syncron") { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        for channel: UInt8 in [0, 1] {
            for number: UInt8 in [0, 1, 2, 3, 4, 8, 13, 29, 31, 32, 33, 96] {
                remainingAkiyamaPacket([0x90 + channel, number, 127, number, 0], input)
            }
            remainingAkiyamaPacket([0xB0 + channel, 24, 127, 40, 127, 0xE0 + channel, 0, 127], input)
        }
        remainingAkiyamaPacket([0xB4, 49, 127, 51, 127], input); #expect(events.isEmpty)
    }
}
