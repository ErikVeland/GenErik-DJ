import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withDJM450(decks: [DeckID] = DeckID.allCases, _ body: (ControllerMIDIConnection) throws -> Void)
    throws
{
    let suite = "djm-450-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, deckAvailability: { decks })
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id + 100), name: "DJM-450",
            identity: .init(id: id, device: UInt32(id), names: ["DJM-450"]))
    }
    input.reconcileFactoryProfiles()
    #expect(!input.isInputActive(10))
    input.select(10)
    input.applyFactoryProfile(try #require(ControllerFactoryProfile.matching(["DJM-450"])))
    #expect(input.bindingCount == 18)
    try body(input)
}

@MainActor private func djm450Packet(_ bytes: [UInt8], to input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source)
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueDJM450BothStripsIncludingFadersKeepsIndependentFactoryAddresses() throws {
    for decks in [DeckID.primary, DeckID.allCases] {
        try withDJM450(decks: decks) { input in
            input.currentTargetValue = { _ in 0.5 }
            var events: [(ControllerActionTarget, Double)] = []
            input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
            let strips: [[UInt8]] = [
                [1, 2, 3, 4, 5, 17], [6, 7, 8, 9, 10, 18], [12, 14, 15, 21, 22, 19], [80, 81, 92, 82, 83, 20],
            ]
            for (index, deck) in DeckID.primary.enumerated() {
                for (number, action) in zip(
                    strips[index], [ControllerAction.gainA, .highA, .midA, .lowA, .filterKnobA, .levelA])
                {
                    events.removeAll()
                    djm450Packet([0xB0, number, 0], to: input)
                    #expect(events.isEmpty)
                    djm450Packet([0xB0, number, 64], to: input)
                    djm450Packet([0xB0, number, 127], to: input)
                    #expect(events.count == (decks.contains(deck) ? 2 : 0))
                    #expect(events.allSatisfy { $0.0 == .init(action.assigned(to: deck), deck: deck) })
                    if decks.contains(deck) { #expect(events.map(\.1) == [64.0 / 127, 1]) }
                }
            }
            for (number, action): (UInt8, ControllerAction) in [
                (24, .master), (26, .monitor), (27, .cueMix), (11, .crossfader),
            ] {
                events.removeAll()
                djm450Packet([0xB0, number, 64], to: input)
                djm450Packet([0xB0, number, 0], to: input)
                #expect(events.map(\.1) == [64.0 / 127, 0])
                #expect(events.allSatisfy { $0.0.action == action })
            }
        }
    }
}

@Test @MainActor func controllerCatalogueDJM450TogglePFLRemainsDirectStateAndDoesNotLeakAcrossSourceOrDeck() throws {
    for decks in [DeckID.primary, DeckID.allCases] {
        try withDJM450(decks: decks) { input in
            input.currentTargetValue = { _ in 1 }
            var events: [(ControllerActionTarget, Double)] = []
            input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
            for (index, deck) in DeckID.primary.enumerated() {
                events.removeAll()
                let number = UInt8(70 + index)
                for value: UInt8 in [0, 127, 127, 0, 0, 127] { djm450Packet([0xB0, number, value], to: input) }
                #expect(events.count == (decks.contains(deck) ? 6 : 0))
                #expect(events.allSatisfy { $0.0 == .init(ControllerAction.cueStateA.assigned(to: deck), deck: deck) })
                if decks.contains(deck) { #expect(events.map(\.1) == [0, 1, 1, 0, 0, 1]) }
            }
            events.removeAll()
            input.select(11)
            djm450Packet([0xB0, 70, 127, 17, 64], to: input, source: 11)
            #expect(events.isEmpty)
        }
    }
}

@Test @MainActor func controllerCatalogueDJM450UnownedHardwareHasNoOutputRoutingOrSiblingProtocolSideEffects() throws {
    try withDJM450 { input in
        input.currentTargetValue = { _ in 0.5 }
        var actions: [ControllerAction] = []
        input.onAction = { action, _ in if !action.isJog { actions.append(action) } }
        for number: UInt8 in [
            13, 19, 20, 72, 73, 74, 25, 33, 38, 40, 41, 42, 43, 45, 46, 53, 54, 55, 65, 66, 67, 68, 76, 77, 91, 94, 95,
            102, 103, 104, 108,
            114, 116,
        ] {
            djm450Packet([0xB0, number, 64], to: input)
            djm450Packet([0xB0, number, 127, number, 0], to: input)
        }
        for number: UInt8 in [
            1, 2, 3, 4, 8, 30, 39, 51, 52, 53, 55, 56, 57, 59, 60, 61, 62, 63, 64, 65, 66, 68, 70, 72, 85, 96, 97, 98,
            99, 105, 106, 107, 118,
        ] {
            djm450Packet([0x90, number, 127, number, 0], to: input)
        }
        djm450Packet([0xB1, 17, 64, 0x91, 10, 127, 0xF8, 0xFA, 0xFC], to: input)
        #expect(actions.isEmpty)
    }
    let profile = try #require(ControllerFactoryProfile.matching(["DJM-450"]))
    #expect(!profile.selectsAutomatically && profile.definition?.role == "accessory")
    #expect(profile.definition?.outputs.isEmpty == true && profile.definition?.startup.isEmpty == true)
    #expect(profile.definition?.shutdown.isEmpty == true && profile.definition?.audioOutput == nil)
    for name in ["DJM-250", "DJM-250MK2", "DJM-S3", "DJM-750MK2", "DJM-900NXS2"] {
        #expect(ControllerFactoryProfile.matching([name]) != profile)
    }
}
