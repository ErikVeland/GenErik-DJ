import Foundation
import TDJCore
import Testing

@testable import TDJInterface
private let mpd2BitwigModels = ["Akai MPD226", "Akai MPD232"]

@MainActor private func withMPD2Bitwig(_ name: String, _ body: (ControllerMIDIConnection) throws -> Void) throws {
    let suite = "mpd2-bitwig-\(UUID().uuidString)"; let preferences = UserDefaults(suiteName: suite)!
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
    input.reconcileFactoryProfiles(); #expect(!input.isInputActive(10) && !input.isInputActive(11) && writes == 0)
    let p = try #require(ControllerFactoryProfile.matching([name]))
    for source: Int32 in [10, 11] { input.select(source); input.applyFactoryProfile(p) }
    #expect(input.bindingCount == 200 && writes == 0); try body(input)
}
@MainActor private func mpd2BitwigPacket(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source); input.flushPendingActions()
}

@Test(arguments: mpd2BitwigModels) @MainActor
func controllerCatalogueMPD2BitwigIndependentManualIdentityCapacityAndNoSetup(_ name: String) throws {
    let p = try #require(ControllerFactoryProfile.matching([name])); let d = try #require(p.definition)
    #expect(d.isValid && !p.selectsAutomatically && d.role == "accessory" && d.inputProtocol == .mpd2Bitwig)
    #expect(
        d.inputs.count == 100 && d.outputs.isEmpty && d.startup.isEmpty && d.shutdown.isEmpty && d.audioOutput == nil)
    let model = name.split(separator: " ").last!
    for other in ["\(model) Remote", "\(model) MIDI 4", "\(model) Port B", "MPD218", "MPK225"] {
        #expect(ControllerFactoryProfile.matching([other]) != p)
    }
    try withMPD2Bitwig(name) { _ in }
}

@Test(arguments: mpd2BitwigModels) @MainActor
func controllerCatalogueMPD2BitwigFourPadBanksAllNativeTargetsAndCueReleases(_ name: String) throws {
    try withMPD2Bitwig(name) { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        for (bank, deck) in DeckID.allCases.enumerated() {
            let base = UInt8(36 + 16 * bank)
            for slot in 0..<8 {
                events.removeAll(); let n = base + UInt8(slot)
                mpd2BitwigPacket([0x99, n, 127, n, 127, 0x89, n, 127], input)
                #expect(events.count == 1 && events.first?.0.deck == deck && events.first?.0.action.hotcueSlot == slot)
            }
            for (offset, action): (UInt8, ControllerAction) in [
                (8, .playA), (10, .syncA), (11, .loadA), (12, .loopInA), (13, .loopOutA), (14, .reloopA),
                (15, .keylockA),
            ] {
                events.removeAll(); let n = base + offset; mpd2BitwigPacket([0x99, n, 1, n, 1, n, 0], input)
                #expect(events.count == 1 && events.first?.0 == .init(action.assigned(to: deck), deck: deck))
            }
            for velocity: UInt8 in [1, 64, 127] {
                for off: UInt8 in [0x89, 0x99] {
                    events.removeAll();
                    mpd2BitwigPacket(
                        [0x99, base + 9, velocity, base + 9, velocity, off, base + 9, off == 0x89 ? 127 : 0], input)
                    #expect(events.map(\.1) == [Double(velocity) / 127, 0] && events.allSatisfy { $0.0.deck == deck })
                }
            }
        }
    }
}

@Test(arguments: mpd2BitwigModels) @MainActor
func controllerCatalogueMPD2BitwigPadCleanupPreservesOtherOwnersAndControlBankCue(_ name: String) throws {
    try withMPD2Bitwig(name) { input in
        var events: [(DeckID?, Double)] = []
        input.onTargetAction = { target, value in
            if [.cuePreviewA, .cuePreviewB].contains(target.action) { events.append((target.deck, value)) }
        }
        mpd2BitwigPacket([0x99, 45, 127], input); mpd2BitwigPacket([0x99, 45, 127], input, source: 11)
        mpd2BitwigPacket([0xB1, 30, 127, 0xB2, 40, 64], input); #expect(events.map(\.1) == [1])
        mpd2BitwigPacket([0x99, 61, 127], input); #expect(events.map(\.1) == [1, 1] && events.last?.0 == .b)
        mpd2BitwigPacket([0x89, 45, 127], input, source: 11); #expect(events.last?.0 == .a && events.last?.1 == 0)
        mpd2BitwigPacket([0x89, 45, 127, 0x99, 61, 127], input); #expect(events.count == 3)
        mpd2BitwigPacket([0x89, 61, 127], input);
        #expect(events.count == 4 && events.last?.0 == .b && events.last?.1 == 0)
        events.removeAll(); mpd2BitwigPacket([0x99, 45, 127], input); input.stop(); #expect(events.map(\.1) == [1, 0])
    }
}

@Test(arguments: mpd2BitwigModels) @MainActor
func controllerCatalogueMPD2BitwigCCButtonsRearmAcrossChangedAndLateReleaseBanks(_ name: String) throws {
    try withMPD2Bitwig(name) { input in
        var events: [ControllerAction] = [];
        input.onTargetAction = { target, _ in if target.action.isButton { events.append(target.action) } }
        for (channel, action): (UInt8, ControllerAction) in [(1, .cueA), (2, .syncA), (3, .keylockA)] {
            for column in 0..<4 {
                events.removeAll(); let n = UInt8(30 + column); let deck = DeckID.allCases[column]
                mpd2BitwigPacket([0xB0 + channel, n, 127, n, 127, n, 0], input)
                #expect(events == [action.assigned(to: deck)])
            }
        }
        events.removeAll();
        mpd2BitwigPacket([0xB1, 30, 127, 0xB2, 30, 127, 0xB1, 30, 127, 0xB2, 30, 0, 0xB1, 30, 127], input)
        #expect(events == [.cueA, .syncA, .cueA])
        mpd2BitwigPacket([0xB1, 30, 0, 30, 127], input); #expect(events == [.cueA, .syncA, .cueA, .cueA])
    }
}

@Test(arguments: mpd2BitwigModels) @MainActor func controllerCatalogueMPD2BitwigFadersKnobsAndIndependentBankPickup(
    _ name: String
) throws {
    try withMPD2Bitwig(name) { input in
        input.currentTargetValue = { _ in 0.5 }; var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in if !target.action.isButton { events.append((target, value)) } }
        for (channel, fader, knob): (UInt8, ControllerAction, ControllerAction) in [
            (1, .levelA, .gainA), (2, .highA, .midA), (3, .lowA, .filterKnobA),
        ] {
            for (column, deck) in DeckID.allCases.enumerated() {
                events.removeAll(); let n = UInt8(40 + column)
                mpd2BitwigPacket([0xB0 + channel, n, 64], input); mpd2BitwigPacket([0xB0 + channel, n, 127], input)
                #expect(
                    events.count == 2 && events.last?.0 == .init(fader.assigned(to: deck), deck: deck)
                        && events.last?.1 == 1)
                events.removeAll(); let k = UInt8(50 + column)
                mpd2BitwigPacket([0xB0 + channel, k, 1], input); mpd2BitwigPacket([0xB0 + channel, k, 127], input)
                #expect(
                    events.map(\.1) == [0.5 + 1.0 / 127, 0.5 - 1.0 / 127]
                        && events.allSatisfy { $0.0 == .init(knob.assigned(to: deck), deck: deck) })
            }
        }
        mpd2BitwigPacket([0xB1, 50, 1], input)
        events.removeAll(); mpd2BitwigPacket([0xB1, 40, 0], input); #expect(events.isEmpty)
        mpd2BitwigPacket([0xB1, 40, 64], input); mpd2BitwigPacket([0xB1, 40, 0], input);
        #expect(events.count == 2 && events.last?.1 == 0)
        events.removeAll(); mpd2BitwigPacket([0x99, 45, 127, 61, 127], input)
        mpd2BitwigPacket([0xB1, 40, 127], input);
        #expect(events.count == 1 && events.first?.0.action == .levelA && events.first?.1 == 1)
        events.removeAll(); mpd2BitwigPacket([0xB1, 40, 127], input, source: 11); #expect(events.isEmpty)
        mpd2BitwigPacket([0xB1, 40, 64], input, source: 11); #expect(events.count == 1)
    }
}

@Test(arguments: mpd2BitwigModels) @MainActor
func controllerCatalogueMPD2BitwigRejectsExtraColumnsUnknownStepsTransportAndPressure(_ name: String) throws {
    try withMPD2Bitwig(name) { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        mpd2BitwigPacket(
            [
                0x99, 35, 127, 100, 127, 0x98, 36, 127, 0xB0, 118, 127, 0xB1, 34, 127, 44, 64, 54, 1, 0xD9, 127, 0xA9,
                36, 127,
            ], input)
        for value: UInt8 in [0, 2, 63, 64, 65, 126] { mpd2BitwigPacket([0xB2, 50, value], input) }
        #expect(events.isEmpty)
    }
}
