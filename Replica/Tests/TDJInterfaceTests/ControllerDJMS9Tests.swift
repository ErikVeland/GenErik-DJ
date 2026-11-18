import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withS9(decks: [DeckID] = DeckID.allCases, _ body: (ControllerMIDIConnection) throws -> Void)
    throws
{
    let suite = "djm-s9-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, deckAvailability: { decks })
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id + 100), name: "DJM-S9",
            identity: .init(id: id, device: UInt32(id), names: ["DJM-S9"]))
    }
    input.reconcileFactoryProfiles()
    #expect(!input.isInputActive(10) && !input.isInputActive(11))
    input.select(10)
    input.applyFactoryProfile(try #require(ControllerFactoryProfile.matching(["DJM-S9"])))
    #expect(input.bindingCount == 42)
    try body(input)
}

@MainActor private func s9Packet(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source)
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueS9PairsFourStripsWithoutUnlockingUnavailableDecks() throws {
    for decks in [DeckID.primary, DeckID.allCases] {
        try withS9(decks: decks) { input in
            input.currentTargetValue = { _ in 0.5 }
            var events: [(ControllerActionTarget, Double)] = []
            input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
            var wires: [(UInt8, UInt8, ControllerAction, DeckID?)] = []
            for (index, deck) in DeckID.allCases.enumerated() {
                for (number, action): (UInt8, ControllerAction) in [
                    (4, .gainA), (7, .highA), (11, .midA), (15, .lowA), (1, .filterKnobA), (19, .levelA),
                ] {
                    wires.append((UInt8(index), number, action.assigned(to: deck), deck))
                }
            }
            wires += [(6, 31, .crossfader, nil), (6, 8, .master, nil), (6, 13, .monitor, nil), (6, 12, .cueMix, nil)]
            for (wire, number, action, deck) in wires {
                events.removeAll()
                s9Packet([0xB0 + wire, number + 32, 127], input)
                #expect(events.isEmpty)
                s9Packet([0xB0 + wire, number, 0], input)
                #expect(events.isEmpty)
                s9Packet([0xB0 + wire, number, 64], input)
                s9Packet([0xB0 + wire, number, 127, number + 32, 127], input)
                if let deck, !decks.contains(deck) {
                    #expect(events.isEmpty)
                } else {
                    #expect(events.first?.1 == 8192.0 / 16383 && events.last?.1 == 1)
                    #expect(events.allSatisfy { $0.0 == .init(action, deck: deck) })
                }
            }
        }
    }
}

@Test @MainActor func controllerCatalogueS9BrowserAndLoopSizesKeepNormalEdgesAndSourceShift() throws {
    try withS9 { input in
        input.currentTargetValue = { _ in 0.5 }
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
        s9Packet([0xB6, 64, 1], input)
        s9Packet([0xB6, 64, 127], input)
        #expect(events.map(\.1) == [0.5 + 1.0 / 126, 0.5 - 1.0 / 126])
        events.removeAll()
        s9Packet([0x96, 65, 127, 65, 0, 101, 127, 101, 0, 70, 127, 70, 0, 71, 127, 71, 0], input)
        #expect(events.map(\.0.action) == [.openGroup, .browsePreviousGroup, .loadA, .loadB])
        for (index, deck) in DeckID.allCases.enumerated() {
            for (number, action): (UInt8, ControllerAction) in [(18, .loopDownA), (19, .loopUpA)] {
                for off: UInt8 in [0x80, 0x90] {
                    events.removeAll()
                    s9Packet(
                        [
                            0x90 + UInt8(index), number, 127, number, 127, off + UInt8(index), number,
                            off == 0x80 ? 127 : 0,
                        ], input)
                    #expect(events.count == 1 && events.first?.0 == .init(action.assigned(to: deck), deck: deck))
                }
            }
        }
        s9Packet([0x96, 63, 127], input, source: 11)
        events.removeAll()
        s9Packet([0x90, 18, 127, 18, 0], input)
        #expect(events.count == 1)
        s9Packet([0x96, 63, 127], input)
        events.removeAll()
        s9Packet([0x90, 18, 127, 18, 0, 0x96, 70, 127, 70, 0, 0xB6, 64, 1], input)
        #expect(events.isEmpty)
        s9Packet([0x96, 63, 0, 0x90, 19, 127, 19, 0], input)
        #expect(events.count == 1 && events.first?.0.action == .loopUpA)
    }
}

@Test @MainActor func controllerCatalogueS9ConflictingPadsAndUnownedHardwareStayInactive() throws {
    try withS9 { input in
        var actions: [ControllerAction] = []
        input.onAction = { action, _ in if !action.isJog { actions.append(action) } }
        for channel: UInt8 in [0, 1, 2, 3] {
            for number: UInt8 in [
                1, 9, 16, 17, 20, 27, 30, 32, 34, 36, 44, 64, 65, 66, 67, 69, 80, 81, 82, 102, 105, 107, 109, 111,
            ] {
                s9Packet([0x90 + channel, number, 127, number, 0], input)
            }
        }
        for channel: UInt8 in [7, 8, 9, 10] {
            for number: UInt8 in 0...15 { s9Packet([0x90 + channel, number, 127, number, 0], input) }
        }
        for number: UInt8 in [1, 2, 3, 4, 5, 6, 7, 9, 14, 33, 34, 35, 36, 37, 38, 39, 41, 46, 100] {
            s9Packet([0xB6, number, 64, number, 127, number, 0], input)
        }
        s9Packet([0xF8, 0xFA, 0xFC, 0xB0, 4, 64], input, source: 11)
        #expect(actions.isEmpty)
    }
    let profile = try #require(ControllerFactoryProfile.matching(["DJM-S9"]))
    #expect(!profile.selectsAutomatically && profile.definition?.role == "accessory")
    #expect(profile.definition?.outputs.isEmpty == true && profile.definition?.startup.isEmpty == true)
    #expect(profile.definition?.shutdown.isEmpty == true && profile.definition?.audioOutput == nil)
    for name in ["DJM-S5", "DJM-S7", "DJM-S11"] { #expect(ControllerFactoryProfile.matching([name]) != profile) }
}
