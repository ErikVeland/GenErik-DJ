import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withBeatmix(_ body: (ControllerMIDIConnection) throws -> Void) rethrows {
    let suite = "beatmix-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, deckAvailability: { DeckID.allCases })
    input.sources = [
        .init(
            id: 10, reference: 100, name: "Beatmix 4 MK2", identity: .init(id: 10, device: 1, names: ["Beatmix 4 MK2"]))
    ]
    input.reconcileFactoryProfiles()
    try body(input)
}

@MainActor private func beatmixPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueBeatmixFamilyRetainsStoredIdentityAndDistinctOutputAddresses() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["Beatmix 4 MK2"], automaticOnly: true))
    #expect(profile.rawValue == "Reloop Beatmix 2/4 MK2")
    for name in ["Beatmix 2", "Beatmix 4", "Beatmix 2 MK2", "Beatmix 4 MK2", "Reloop Beatmix 2/4 MK2"] {
        #expect(ControllerFactoryProfile.matching([name], automaticOnly: true) == profile)
    }
    #expect(ControllerFactoryProfile.matching(["Beatmix 4 MK3"]) == nil)
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 148 && data.outputs.count == 28)
    for deck in DeckID.allCases {
        let outputs = profile.feedback(destination: 20).filter { $0.targetDeck == deck }
        #expect(outputs.first { $0.action == .playA || $0.action == .playB }?.number == 35)
        #expect(outputs.first { $0.action == .syncA || $0.action == .syncB }?.number == 32)
        #expect(outputs.filter { $0.action.hotcueSlot != nil }.allSatisfy { $0.onValue == 85 })
    }
}

@Test @MainActor func controllerCatalogueBeatmixRoutesFourDeckCoreAndSourceFixedLoops() {
    withBeatmix { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        beatmixPacket([0x91, 36, 127, 0x93, 80, 127, 0x94, 82, 127, 0x92, 4, 127, 6, 127], to: input)
        #expect(
            events == [
                .init(.playA, deck: .a), .init(.loadA, deck: .c), .init(.cueB, deck: .d),
                .init(.toggleFixedLoopB, deck: .b, argument: 1), .init(.toggleFixedLoopB, deck: .b, argument: 4),
            ])
        beatmixPacket([0x91, 16, 127, 17, 127, 24, 127, 25, 127], to: input)
        #expect(events.count == 5)
    }
}

@Test @MainActor func controllerCatalogueBeatmixUsesFactoryJogBytesInsteadOfTheConflictingScriptOffset() {
    withBeatmix { input in
        var jogs: [(ControllerActionTarget, ControllerMIDIValue)] = []
        input.onJogAction = { target, value in jogs.append((target, value)) }
        beatmixPacket([0xB1, 96, 1], to: input)
        beatmixPacket([0xB3, 96, 127], to: input)
        beatmixPacket([0xB4, 96, 2], to: input)
        #expect(jogs.map(\.1) == [.relative(1), .relative(-1), .relative(2)])
        #expect(
            jogs.map(\.0) == [
                .init(.jogA, deck: .a, argument: 800), .init(.jogA, deck: .c, argument: 800),
                .init(.jogB, deck: .d, argument: 800),
            ])
    }
}

@Test @MainActor func controllerCatalogueBeatmixShiftReleaseRearmsButtonsAndFinishesHeldContacts() {
    withBeatmix { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in events.append((target, value)) }
        beatmixPacket([0x91, 0, 127, 35, 127, 63, 127, 32, 127, 8, 127, 99, 127, 127, 127], to: input)
        #expect(events.map(\.0.action) == [.hotcue1A, .cuePreviewA, .jogTouchA])
        beatmixPacket([0x81, 8, 0, 99, 0, 127, 0, 32, 0, 0x91, 0, 127, 35, 127], to: input)
        #expect(
            events.map(\.0.action) == [
                .hotcue1A, .cuePreviewA, .jogTouchA, .cuePreviewA, .jogTouchA, .hotcue1A, .cuePreviewA,
            ])
        #expect(events.map(\.1) == [1, 1, 1, 0, 0, 1, 1])
    }
}

@Test @MainActor func controllerCatalogueBeatmixBankChangeRearmsOnlyItsSidesPitchPickup() {
    withBeatmix { input in
        var targets: [DeckID] = []
        input.currentTargetValue = { $0.action == .tempoA || $0.action == .tempoB ? 0.5 : nil }
        input.onTargetAction = { target, _ in
            if let deck = target.deck, target.action == .tempoA || target.action == .tempoB { targets.append(deck) }
        }
        beatmixPacket([0xE1, 0, 64, 0xE2, 0, 64], to: input)
        beatmixPacket([0xE1, 127, 127, 0xE2, 127, 127], to: input)
        #expect(Set(targets) == [.a, .b] && targets.count == 4)
        targets.removeAll()
        beatmixPacket([0x93, 40, 127, 0xE1, 127, 127, 0xE2, 127, 127], to: input)
        #expect(targets == [.b])
        beatmixPacket([0xE3, 127, 127], to: input)
        #expect(targets == [.b])
        beatmixPacket([0xE3, 0, 64], to: input)
        #expect(targets == [.b, .c])
    }
}

@Test @MainActor func controllerCatalogueBeatmixBankChangePreservesHeldPhysicalShiftAndReleasesOldCue() {
    withBeatmix { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in
            if [.cuePreviewA, .cuePreviewB, .loadA, .loadB].contains(target.action) { events.append((target, value)) }
        }
        beatmixPacket([0x91, 35, 127, 0x92, 35, 127, 0x91, 32, 127, 0x93, 40, 127, 80, 127], to: input)
        #expect(
            events.map(\.0) == [
                .init(.cuePreviewA, deck: .a), .init(.cuePreviewB, deck: .b), .init(.cuePreviewA, deck: .a),
            ])
        #expect(events.map(\.1) == [1, 1, 0])
        beatmixPacket([0x81, 32, 0, 0x83, 80, 0, 0x93, 80, 127, 0x82, 35, 0], to: input)
        #expect(events.suffix(2).map(\.0) == [.init(.loadA, deck: .c), .init(.cuePreviewB, deck: .b)])
    }
}
