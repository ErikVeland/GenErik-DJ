import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withMPD218(_ body: (ControllerMIDIConnection) throws -> Void) throws {
    let suite = "mpd218-\(UUID().uuidString)"; let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    var writes = 0
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { _, _ in
            writes += 1; return true
        }, deckAvailability: { DeckID.allCases }, factoryInputConnector: { _ in true })
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id), name: "MPD218 Port A",
            identity: .init(id: id, device: UInt32(id), names: ["MPD218 Port A"]))
    }
    input.reconcileFactoryProfiles(); #expect(input.isInputActive(10) && input.isInputActive(11) && writes == 0)
    try body(input)
}
@MainActor private func mpd218Packet(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source); input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueMPD218OwnIdentityAndNoPresetOrOutputWrites() throws {
    let p = try #require(ControllerFactoryProfile.matching(["MPD218 Port A"])); let d = try #require(p.definition)
    #expect(d.isValid && p.selectsAutomatically && d.role == "accessory" && d.inputProtocol == .mpd218Chroma)
    #expect(
        d.inputs.count == 66 && d.outputs.isEmpty && d.startup.isEmpty && d.shutdown.isEmpty && d.audioOutput == nil)
    for other in ["MPD218 Port B", "MPD226", "MPD232", "MPD18"] {
        #expect(ControllerFactoryProfile.matching([other]) != p)
    }
    try withMPD218 { _ in }
}

@Test @MainActor func controllerCatalogueMPD218AllThreeBanksAndNativeTargetsKeepBothCueReleaseForms() throws {
    try withMPD218 { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        for (bank, deck) in Array(DeckID.allCases.prefix(3)).enumerated() {
            let base = UInt8(36 + 16 * bank)
            for slot in 0..<8 {
                events.removeAll(); let n = base + UInt8(slot)
                mpd218Packet([0x99, n, 127, n, 127, 0x89, n, 127], input)
                #expect(events.count == 1 && events.first?.0.deck == deck && events.first?.0.action.hotcueSlot == slot)
            }
            for (offset, action): (UInt8, ControllerAction) in [
                (8, .playA), (10, .syncA), (11, .loadA), (12, .loopInA), (13, .loopOutA), (14, .reloopA),
                (15, .keylockA),
            ] {
                events.removeAll(); let n = base + offset; mpd218Packet([0x99, n, 1, n, 1, n, 0], input)
                #expect(events.count == 1 && events.first?.0 == .init(action.assigned(to: deck), deck: deck))
            }
            for velocity: UInt8 in [1, 64, 127] {
                for off: UInt8 in [0x89, 0x99] {
                    events.removeAll();
                    mpd218Packet(
                        [0x99, base + 9, velocity, base + 9, velocity, off, base + 9, off == 0x89 ? 127 : 0], input)
                    #expect(events.map(\.1) == [Double(velocity) / 127, 0] && events.allSatisfy { $0.0.deck == deck })
                }
            }
        }
    }
}

@Test @MainActor func controllerCatalogueMPD218BankCleanupKeepsSourcesAndLateCueReleasesIndependent() throws {
    try withMPD218 { input in
        var events: [(DeckID?, Double)] = []
        input.onTargetAction = { target, value in
            if [.cuePreviewA, .cuePreviewB].contains(target.action) { events.append((target.deck, value)) }
        }
        mpd218Packet([0x99, 45, 127], input); mpd218Packet([0x99, 45, 127], input, source: 11)
        mpd218Packet([0x99, 61, 127], input); #expect(events.map(\.1) == [1, 1] && events.last?.0 == .b)
        mpd218Packet([0x89, 45, 127], input, source: 11); #expect(events.last?.0 == .a && events.last?.1 == 0)
        mpd218Packet([0x89, 45, 127, 0x99, 61, 127], input); #expect(events.count == 3)
        mpd218Packet([0x89, 61, 127], input); #expect(events.count == 4 && events.last?.0 == .b && events.last?.1 == 0)
        events.removeAll(); mpd218Packet([0x99, 45, 127], input); mpd218Packet([0x99, 68, 127, 68, 0], input)
        #expect(events.map(\.1) == [1, 0])
        mpd218Packet([0x99, 45, 127], input); input.stop(); #expect(events.map(\.1) == [1, 0, 1, 0])
    }
}

@Test @MainActor func controllerCatalogueMPD218All18KnobsKeepTheirDeckAndPickupAcrossPadBankChanges() throws {
    try withMPD218 { input in
        input.currentTargetValue = { _ in 0.5 }; var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in if !target.action.isMomentary { events.append((target, value)) } }
        for (bank, deck) in Array(DeckID.allCases.prefix(3)).enumerated() {
            let numbers: [UInt8] = bank == 0 ? [3, 9, 12, 13, 14, 15] : bank == 1 ? Array(16...21) : Array(22...27)
            for (number, action) in zip(numbers, [ControllerAction.gainA, .highA, .midA, .lowA, .levelA, .filterKnobA])
            {
                events.removeAll(); mpd218Packet([0xB0, number, 64], input); mpd218Packet([0xB0, number, 127], input)
                #expect(
                    events.count == 2 && events.last?.0 == .init(action.assigned(to: deck), deck: deck)
                        && events.last?.1 == 1)
            }
        }
        events.removeAll(); mpd218Packet([0x99, 45, 127], input)
        mpd218Packet([0xB0, 3, 0], input);
        #expect(events.count == 1 && events.first?.0.action == .gainA && events.first?.1 == 0)
        events.removeAll(); mpd218Packet([0x99, 61, 127], input)
        mpd218Packet([0xB0, 3, 127], input); #expect(events.count == 1 && events.first?.1 == 1)
        events.removeAll(); mpd218Packet([0xB0, 3, 127], input, source: 11); #expect(events.isEmpty)
        mpd218Packet([0xB0, 3, 64], input, source: 11); #expect(events.count == 1)
    }
}

@Test @MainActor func controllerCatalogueMPD218RejectsOtherChannelsNotesAndPressureMessages() throws {
    try withMPD218 { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        mpd218Packet(
            [
                0x99, 35, 127, 84, 127, 0x98, 36, 127, 0x90, 36, 127, 0xB9, 3, 64, 0xB0, 4, 64, 28, 64, 0xD9, 127, 0xA9,
                36, 127, 0xE9, 0, 64,
            ], input)
        #expect(events.isEmpty)
    }
}
