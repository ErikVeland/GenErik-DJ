import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withDJ707M(decks: [DeckID] = DeckID.allCases, _ body: (ControllerMIDIConnection) throws -> Void)
    throws
{
    let suite = "dj707m-\(UUID().uuidString)"; let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { _, _ in
            Issue.record("The manual DJ-707M bridge core must not configure hardware."); return false
        }, deckAvailability: { decks }, factoryInputConnector: { _ in true })
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id), name: "Qualified MIDI bridge",
            identity: .init(id: id, device: UInt32(id), names: ["Roland DJ-707M"]))
    }
    input.reconcileFactoryProfiles(); #expect(!input.isInputActive(10) && !input.isInputActive(11))
    let p = try #require(ControllerFactoryProfile.matching(["Roland DJ-707M"]))
    for source: Int32 in [10, 11] { input.select(source); input.applyFactoryProfile(p) }
    #expect(input.bindingCount == 214 && input.isInputActive(10) && input.isInputActive(11))
    try body(input)
}

@MainActor private func dj707Packet(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source); input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueDJ707MRemainsManualInputOnlyAndSeparateFromSiblingProtocols() throws {
    let p = try #require(ControllerFactoryProfile.matching(["Roland DJ-707M"])); let d = try #require(p.definition)
    #expect(d.isValid && !p.selectsAutomatically && d.inputs.count == 107 && d.inputModes?.count == 4)
    #expect(d.outputs.isEmpty && d.startup.isEmpty && d.shutdown.isEmpty && d.audioOutput == nil)
    #expect(ControllerFactoryProfile.matching(["DJ-707M"], automaticOnly: true) == nil)
    for other in ["DJ-202", "DJ-505", "DJ-808"] { #expect(ControllerFactoryProfile.matching([other]) != p) }
    try withDJ707M { _ in }
}

@Test @MainActor func controllerCatalogueDJ707MNormalTransportAndShiftedKeylockKeepOwnTargets() throws {
    try withDJ707M { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        for (ch, deck): (UInt8, DeckID) in [(0, .a), (1, .b), (2, .c), (3, .d)] {
            for (action, n): (ControllerAction, UInt8) in [(.playA, 0), (.syncA, 2), (.cueA, 27)] {
                events.removeAll(); dj707Packet([0x90 + ch, n, 127, n, 127, n, 0], input)
                #expect(events == [.init(action.assigned(to: deck), deck: deck)])
            }
            events.removeAll();
            dj707Packet(
                [
                    0x90 + ch, 13, 127, 13, 0, 0x9F, 0, 127, 0x90 + ch, 0, 127, 0, 0, 1, 127, 1, 0, 2, 127, 2, 0, 27,
                    127, 27, 0,
                ], input)
            #expect(events.isEmpty)
            dj707Packet([0x90 + ch, 13, 127, 13, 127, 14, 0, 13, 1, 13, 0, 0x9F, 0, 0], input)
            #expect(events == Array(repeating: .init(.keylockA.assigned(to: deck), deck: deck), count: 2))
        }
    }
}

@Test @MainActor func controllerCatalogueDJ707MCueBothReleasesShiftAndSourceOwnedDeckCleanup() throws {
    try withDJ707M { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        for (ch, deck): (UInt8, DeckID) in [(0, .a), (1, .b), (2, .c), (3, .d)] {
            for velocity: UInt8 in [1, 64, 127] {
                for off: UInt8 in [0x80, 0x90] {
                    events.removeAll();
                    dj707Packet([0x90 + ch, 1, velocity, 1, 127, off + ch, 1, off == 0x80 ? 127 : 0], input)
                    #expect(
                        events.map(\.1) == [Double(velocity) / 127, 0]
                            && events.allSatisfy { $0.0 == .init(.cuePreviewA.assigned(to: deck), deck: deck) })
                }
            }
        }
        dj707Packet([0x90, 1, 127, 0x92, 1, 127], input); dj707Packet([0x90, 1, 127], input, source: 11);
        events.removeAll()
        dj707Packet([0x90, 8, 127], input)
        #expect(
            events.map { $0.0 } == [.init(.cuePreviewA, deck: .c)] && events.map(\.1) == [0])
        events.removeAll(); dj707Packet([0x80, 1, 127], input, source: 11)
        #expect(events.map(\.1) == [0])
        dj707Packet([0x90, 1, 127, 0x9F, 0, 127], input); #expect(events.last?.1 == 1)
        events.removeAll(); dj707Packet([0x80, 5, 127, 0x9F, 0, 0], input)
        #expect(events.map { $0.0 } == [.init(.cuePreviewA, deck: .a)] && events.map(\.1) == [0])
    }
}

@Test @MainActor func controllerCatalogueDJ707MPadsStartUnknownBlockOtherModesAndRetainOwnSelection() throws {
    try withDJ707M { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        for (ch, deck): (UInt8, DeckID) in [(4, .a), (5, .b), (6, .c), (7, .d)] {
            events.removeAll(); dj707Packet([0x90 + ch, 20, 127, 20, 0], input); #expect(events.isEmpty)
            for mode: UInt8 in 1..<12 { dj707Packet([0x90 + ch, mode, 127, mode, 0, 20, 127, 20, 0], input) }
            #expect(events.isEmpty)
            dj707Packet([0x90 + ch, 0, 127, 0, 0], input)
            for slot: UInt8 in 0..<8 {
                events.removeAll();
                dj707Packet(
                    [
                        0x90 + ch, 20 + slot, 127, 20 + slot, 127, 0x80 + ch, 28 + slot, 127, 0x90 + ch, 20 + slot, 1,
                        20 + slot, 0,
                    ], input)
                #expect(events.count == 2 && events.allSatisfy { $0.deck == deck && $0.action.hotcueSlot == Int(slot) })
            }
        }
        events.removeAll(); input.reconcileFactoryProfiles(); dj707Packet([0x94, 20, 127, 20, 0], input)
        #expect(events == [.init(.hotcue1A, deck: .a)])
        events.removeAll(); dj707Packet([0x90, 8, 127, 8, 0, 0x94, 20, 127, 20, 0, 0x95, 20, 127, 20, 0], input)
        #expect(events == [.init(.hotcue1B, deck: .b)])
        events.removeAll(); dj707Packet([0x95, 20, 127, 20, 0], input, source: 11); #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueDJ707MFilterPickupLoadsBrowseAndInactiveUnqualifiedControls() throws {
    try withDJ707M { input in
        input.currentTargetValue = { _ in 0.5 }
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        for (ch, deck): (UInt8, DeckID) in [(0, .a), (1, .b), (2, .c), (3, .d)] {
            events.removeAll(); dj707Packet([0xB0 + ch, 26, 0], input); #expect(events.isEmpty)
            dj707Packet([0xB0 + ch, 26, 64], input); dj707Packet([0xB0 + ch, 26, 127], input)
            #expect(
                events.count == 2 && events.last?.0 == .init(.filterKnobA.assigned(to: deck), deck: deck)
                    && events.last?.1 == 1)
            events.removeAll(); dj707Packet([0x9F, 2 + ch, 127, 2 + ch, 127, 2 + ch, 0], input)
            #expect(events.map { $0.0 } == [.init(.loadA.assigned(to: deck), deck: deck)])
        }
        events.removeAll(); dj707Packet([0xBF, 0, 64], input); #expect(events.isEmpty)
        dj707Packet([0xBF, 0, 65], input); dj707Packet([0xBF, 0, 63], input);
        dj707Packet([0x9F, 7, 127, 7, 127, 7, 0], input)
        #expect(events.map { $0.0.action } == [.browse, .browse, .browsePreviousGroup, .browsePreviousGroup])
        #expect(Array(events.prefix(2)).map(\.1) == [0.5 + 1.0 / 126, 0.5 - 1.0 / 126])
        events.removeAll()
        for ch: UInt8 in 0..<4 {
            dj707Packet(
                [
                    0xB0 + ch, 6, 65, 9, 127, 59, 127, 22, 127, 52, 127, 23, 127, 53, 127, 24, 127, 54, 127, 25, 127,
                    55, 127, 28, 127, 58, 127, 30, 127, 34, 127, 0x90 + ch, 6, 127, 7, 127, 14, 127, 0xE0 + ch, 0, 0,
                ], input)
        }
        dj707Packet(
            [
                0xBF, 1, 65, 8, 127, 88, 127, 10, 127, 13, 127, 0x9F, 14, 127, 16, 127, 17, 127, 27, 127, 70, 127, 71,
                127, 0x98, 0, 127, 0x9E, 0, 127,
            ], input)
        #expect(events.isEmpty)
    }
    try withDJ707M(decks: [.a, .b]) { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        dj707Packet([0x96, 0, 127, 20, 127, 0x92, 0, 127, 1, 127, 0xB2, 26, 64, 0x9F, 4, 127], input);
        #expect(events.isEmpty)
    }
}
