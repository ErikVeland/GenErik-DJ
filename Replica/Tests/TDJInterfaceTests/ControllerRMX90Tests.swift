import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withRMX90(
    decks: [DeckID] = DeckID.allCases, _ body: (ControllerMIDIConnection) throws -> Void
) throws {
    let suite = "rmx90-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences, factoryPacketSender: { _, _ in true }, deckAvailability: { decks })
    input.sources = [
        .init(id: 10, reference: 100, name: "RMX-90DVS", identity: .init(id: 10, device: 1, names: ["RMX-90DVS"]))
    ]
    input.reconcileFactoryProfiles()
    #expect(!input.isInputActive(10))
    input.select(10)
    input.applyFactoryProfile(try #require(ControllerFactoryProfile.matching(["RMX-90DVS"])))
    try body(input)
}

@MainActor private func rmx90Packet(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueRMX90KeepsManualIdentityWithoutOutputOrTransport() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["Reloop RMX-90 DVS"]))
    #expect(!profile.selectsAutomatically && !profile.hasAutomaticSplitOutput)
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 32 && data.outputs.isEmpty && data.startup.isEmpty && data.shutdown.isEmpty)
    for name in ["RMX-80", "RMX-60", "RMX-95", "Reloop TOUCH", "USB Audio Device"] {
        #expect(ControllerFactoryProfile.matching([name]) != profile)
    }
    #expect(!data.inputs.contains { [.playA, .playB, .cuePreviewA, .cuePreviewB, .syncA, .syncB].contains($0.action) })
}

@Test @MainActor func controllerCatalogueRMX90RoutesFactoryMixerRowsToFourIndependentTargets() throws {
    try withRMX90 { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        let actions: [[ControllerAction]] = [
            [.gainA, .highA, .midA, .lowA, .filterKnobA, .levelA],
            [.gainB, .highB, .midB, .lowB, .filterKnobB, .levelB],
        ]
        for (side, deck) in DeckID.allCases.enumerated() {
            for (offset, action) in actions[side % 2].enumerated() {
                for value: UInt8 in [0, 64, 127] {
                    events.removeAll()
                    rmx90Packet([0xB0, UInt8(side * 6 + offset + 1), value], to: input)
                    #expect(events.count == 1)
                    #expect(events.first?.0 == .init(action, deck: deck))
                    #expect(events.first?.1 == Double(value) / 127)
                }
            }
        }
    }
}

@Test @MainActor func controllerCatalogueRMX90PFLRearmsWithBothReleasesAndCDRemainOptIn() throws {
    for decks in [DeckID.primary, DeckID.allCases] {
        try withRMX90(decks: decks) { input in
            var events: [(ControllerActionTarget, Double)] = []
            input.onTargetAction = { events.append(($0, $1)) }
            for note: UInt8 in [2, 5, 8, 11] {
                rmx90Packet([0x90, note, 127, note, 0, note, 127, 0x80, note, 127, 0x90, note, 127], to: input)
            }
            #expect(events.map { $0.0.deck } == decks.flatMap { Array(repeating: Optional($0), count: 3) })
            #expect(events.allSatisfy { [.cueA, .cueB].contains($0.0.action) && $0.1 == 1 })
            events.removeAll()
            rmx90Packet([0xB0, 18, 127, 24, 127], to: input)
            #expect(Set(events.compactMap { $0.0.deck }) == Set(decks.count == 4 ? [DeckID.c, .d] : []))
        }
    }
}

@Test @MainActor func controllerCatalogueRMX90SeparatesGlobalsFromBoothSelectorsFXAndReservedChannels() throws {
    try withRMX90 { input in
        var events: [(ControllerAction, Double)] = []
        input.onAction = { events.append(($0, $1)) }
        rmx90Packet([0xB0, 25, 0, 26, 127, 39, 64, 40, 127], to: input)
        #expect(events.count == 4)
        let values = Dictionary(uniqueKeysWithValues: events)
        #expect(values[.crossfader] == 0 && values[.master] == 1)
        #expect(values[.cueMix] == 64.0 / 127 && values[.monitor] == 1)
        events.removeAll()
        rmx90Packet([0xB0, 27, 127, 28, 127, 31, 63, 32, 64, 33, 127, 38, 127], to: input)
        rmx90Packet([0x90, 1, 127, 3, 64, 4, 127, 6, 64, 7, 127, 9, 64, 10, 127, 12, 64, 32, 127], to: input)
        for channel: UInt8 in 1...15 {
            rmx90Packet([0xB0 + channel, 1, 127, 25, 127, 0x90 + channel, 2, 127], to: input)
        }
        #expect(events.isEmpty)
    }
}
