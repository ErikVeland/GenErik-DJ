import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withMixon4(_ body: (ControllerMIDIConnection, [[UInt8]]) throws -> Void) rethrows {
    let suite = "mixon4-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    var packets: [[UInt8]] = []
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { bytes, _ in
            packets.append(bytes); return true
        },
        deckAvailability: { DeckID.allCases })
    input.sources = [
        .init(id: 10, reference: 100, name: "MIXON4", identity: .init(id: 10, device: 1, names: ["MIXON4"]))
    ]
    input.destinations = [
        .init(id: 20, reference: 200, name: "MIXON4", identity: .init(id: 20, device: 1, names: ["MIXON4"]))
    ]
    input.reconcileFactoryProfiles()
    try body(input, packets)
}

@MainActor private func mixon4Packet(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueMixon4UsesItsOwnFactoryQueryAndRGBTable() throws {
    try withMixon4 { input, packets in
        #expect(input.isInputActive(10))
        #expect(packets == [[0xF0, 0, 32, 127, 3, 1, 0xF7]])
        let profile = try #require(ControllerFactoryProfile.matching(["Reloop Mixon 4"], automaticOnly: true))
        let data = try #require(profile.definition)
        #expect(data.inputs.count == 154 && data.outputs.count == 52)
        #expect(ControllerFactoryProfile.matching(["Mixon 8 Pro"]) != profile)
        let pads = profile.feedback(destination: 20).filter { $0.action.hotcueSlot != nil }
        #expect(pads.count == 32 && pads.allSatisfy { $0.onValue == 3 && $0.offValue == 67 })
        #expect(data.inputs.allSatisfy { $0.action != .master })
    }
}

@Test @MainActor func controllerCatalogueMixon4KeepsMixerPadAndGlobalChannelsSeparate() {
    withMixon4 { input, _ in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        mixon4Packet([0x94, 12, 127, 0x96, 2, 127, 0x97, 3, 127, 0x91, 7, 127, 0x9A, 0, 127], to: input)
        #expect(
            events == [
                .init(.playA, deck: .a), .init(.loadA, deck: .c), .init(.cueB, deck: .d), .init(.hotcue8B, deck: .b),
                .init(.openGroup),
            ])
        events.removeAll()
        mixon4Packet([0xB6, 0, 127, 1, 127, 2, 127, 3, 127, 4, 127, 5, 127], to: input)
        #expect(Set(events.map(\.action)) == [.gainA, .highA, .midA, .lowA, .filterKnobA, .levelA])
        #expect(events.allSatisfy { $0.deck == .c })
        events.removeAll()
        mixon4Packet([0x90, 8, 127, 16, 127, 24, 127, 32, 127], to: input)
        #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueMixon4ShiftFinishesCueAndRearmsHotCueWithoutUnsupportedActions() {
    withMixon4 { input, _ in
        var events: [(ControllerAction, Double)] = []
        input.onTargetAction = { target, value in events.append((target.action, value)) }
        mixon4Packet([0x94, 13, 127, 0x90, 0, 127, 0x9A, 3, 127, 0x94, 77, 127, 0x90, 64, 127], to: input)
        #expect(events.map(\.0) == [.cuePreviewA, .hotcue1A])
        mixon4Packet([0x84, 77, 0, 0x80, 64, 0, 0x8A, 3, 0, 0x90, 0, 127, 0x94, 13, 127, 0x84, 13, 0], to: input)
        #expect(events.map(\.0) == [.cuePreviewA, .hotcue1A, .cuePreviewA, .hotcue1A, .cuePreviewA, .cuePreviewA])
        #expect(events.map(\.1) == [1, 1, 0, 1, 1, 0])
    }
}

@Test @MainActor func controllerCatalogueMixon4PitchPickupSurvivesBankAndShiftChanges() {
    withMixon4 { input, _ in
        var decks: [DeckID] = []
        input.currentTargetValue = { [.tempoA, .tempoB].contains($0.action) ? 0.5 : nil }
        input.onTargetAction = { target, _ in
            if [.tempoA, .tempoB].contains(target.action), let deck = target.deck { decks.append(deck) }
        }
        mixon4Packet([0xE4, 0, 64, 0xE5, 0, 64], to: input)
        #expect(Set(decks) == [.a, .b])
        decks.removeAll()
        mixon4Packet([0x96, 18, 127, 0xE4, 127, 127, 0xE5, 127, 127], to: input)
        #expect(decks == [.b])
        mixon4Packet([0xE6, 0, 64], to: input)
        #expect(decks == [.b, .c])
        decks.removeAll()
        mixon4Packet([0x9A, 3, 127, 0xE6, 127, 127, 0x8A, 3, 0, 0xE6, 127, 127], to: input)
        #expect(decks.isEmpty)
        mixon4Packet([0xE6, 0, 64], to: input)
        #expect(decks == [.c])
    }
}

@Test @MainActor func controllerCatalogueMixon4BankReportReleasesOnlyItsSidesHeldCue() {
    withMixon4 { input, _ in
        var events: [(DeckID, Double)] = []
        input.onTargetAction = { target, value in
            if [.cuePreviewA, .cuePreviewB].contains(target.action), let deck = target.deck {
                events.append((deck, value))
            }
        }
        mixon4Packet([0x94, 13, 127, 0x95, 13, 127, 0x96, 18, 127], to: input)
        #expect(events.map(\.0) == [.a, .b, .a] && events.map(\.1) == [1, 1, 0])
        mixon4Packet([0x85, 13, 0], to: input)
        #expect(events.last?.0 == .b && events.last?.1 == 0)
    }
}
