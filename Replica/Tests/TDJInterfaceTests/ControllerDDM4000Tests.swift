import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withDDM4000(
    decks: [DeckID] = DeckID.allCases, _ body: (ControllerMIDIConnection) -> Void
) {
    let suite = "ddm4000-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences, factoryPacketSender: { _, _ in true }, deckAvailability: { decks })
    input.sources = [
        .init(id: 10, reference: 100, name: "DIN MIDI", identity: .init(id: 10, device: 1, names: ["DIN MIDI"]))
    ]
    input.select(10)
    if let profile = ControllerFactoryProfile.matching(["Behringer DDM4000"]) {
        input.applyFactoryProfile(profile)
        #expect(input.isInputActive(10))
    } else {
        Issue.record("Missing manual DDM4000 profile")
    }
    body(input)
}

@MainActor private func ddmPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    input.receiveBytes(bytes, source: 10)
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueDDM4000RoutesEveryReviewedStripAndCrossfaderWithFourDeckOptIn() {
    for decks in [DeckID.primary, DeckID.allCases] {
        withDDM4000(decks: decks) { input in
            input.currentTargetValue = { _ in 0.5 }
            var events: [(ControllerActionTarget, Double)] = []
            input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
            for (index, deck) in DeckID.allCases.enumerated() {
                let base = UInt8(4 + index * 4)
                for (offset, action): (UInt8, ControllerAction) in [(0, .highA), (1, .midA), (2, .lowA), (3, .levelA)] {
                    events.removeAll()
                    ddmPacket([0xB0, base + offset, 64], to: input)
                    ddmPacket([0xB0, base + offset, 127], to: input)
                    #expect(events.count == (decks.contains(deck) ? 2 : 0))
                    #expect(events.allSatisfy { $0.0 == .init(action.assigned(to: deck), deck: deck) })
                    if decks.contains(deck) { #expect(events.map(\.1) == [64.0 / 127, 1]) }
                }
            }
            events.removeAll()
            ddmPacket([0xB0, 21, 64], to: input)
            ddmPacket([0xB0, 21, 0], to: input)
            #expect(events.map { $0.0.action } == [.crossfader, .crossfader])
            #expect(events.map(\.1) == [64.0 / 127, 0])
        }
    }
}

@Test @MainActor func controllerCatalogueDDM4000KeepsPFLNotesSeparateFromLightCCsAndOtherHardware() {
    withDDM4000 { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in if !target.action.isJog { events.append(target) } }
        for (note, deck): (UInt8, DeckID) in [(63, .a), (73, .b), (83, .c), (93, .d)] {
            ddmPacket([0x90, note, 127, 0x80, note, 127], to: input)
            #expect(events.last == .init(ControllerAction.cueA.assigned(to: deck), deck: deck))
        }
        #expect(events.count == 4)
        events.removeAll()
        ddmPacket(
            [
                0xB0, 63, 127, 73, 127, 83, 127, 93, 127, 0, 127, 1, 127, 2, 127, 3, 127, 20, 127, 0xB1, 4, 127, 0x90,
                0, 127, 32, 127, 40, 127, 41, 127, 31, 127, 109, 127,
            ], to: input)
        #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueDDM4000UsesFourIndependentCCLightBindingsAndManualIdentity() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["Behringer DDM4000"]))
    #expect(!profile.selectsAutomatically)
    #expect(profile.definition?.startup.isEmpty == true && profile.definition?.shutdown.isEmpty == true)
    #expect(profile.definition?.audioOutput == nil)
    let lamps = profile.feedback(destination: 20)
    #expect(lamps.count == 4)
    for lamp in lamps {
        #expect(lamp.kind == .control && lamp.channel == 0)
        #expect(lamp.message(value: 1) == [0xB0, lamp.number, 127])
        #expect(lamp.message(value: 0) == [0xB0, lamp.number, 0])
    }
    for name in ["Behringer BCR2000", "Behringer BCF2000", "Behringer CMD MM-1"] {
        #expect(ControllerFactoryProfile.matching([name]) != profile)
    }
}
