import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withNEON(
    decks: [DeckID] = DeckID.allCases,
    _ body: (ControllerMIDIConnection, [[UInt8]]) throws -> Void
) rethrows {
    let suite = "neon-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    var packets: [[UInt8]] = []
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { bytes, _ in
            packets.append(bytes); return true
        },
        deckAvailability: { decks })
    input.sources = [
        .init(id: 10, reference: 100, name: "Reloop NEON", identity: .init(id: 10, device: 1, names: ["Reloop NEON"]))
    ]
    input.destinations = [
        .init(id: 20, reference: 200, name: "Reloop NEON", identity: .init(id: 20, device: 1, names: ["Reloop NEON"]))
    ]
    input.reconcileFactoryProfiles()
    try body(input, packets)
}

@MainActor private func neonPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueNEONUsesItsOwnAccessoryProtocolAndSetup() throws {
    try withNEON { input, packets in
        #expect(input.isInputActive(10))
        let profile = try #require(ControllerFactoryProfile.matching(["Reloop NEON"], automaticOnly: true))
        let data = try #require(profile.definition)
        #expect(data.role == "accessory" && data.inputs.count == 96 && data.outputs.isEmpty)
        #expect(packets == [[0xF0, 10, 0, 0xF7]])
        #expect(ControllerFactoryProfile.matching(["Reloop NEON 2"]) == nil)
        #expect(
            !data.inputs.contains {
                $0.action.isBrowserEncoder || [.loadA, .loadB, .syncA, .syncB].contains($0.action)
            })
    }
}

@Test @MainActor func controllerCatalogueNEONKeepsPadModesAndPressureSeparate() {
    withNEON { input, _ in
        var targets: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in targets.append(target) }
        neonPacket([0x97, 0, 127, 8, 127, 24, 127, 96, 127, 112, 127, 0xB7, 16, 127, 0xA7, 16, 127], to: input)
        #expect(targets.isEmpty)
        for (index, deck) in DeckID.allCases.enumerated() {
            neonPacket([0x97 + UInt8(index), 16, 64, 23, 127], to: input)
            #expect(
                targets.suffix(2) == [
                    .init(deck.leftSide ? .hotcue1A : .hotcue1B, deck: deck),
                    .init(deck.leftSide ? .hotcue8A : .hotcue8B, deck: deck),
                ])
        }
    }
}

@Test @MainActor func controllerCatalogueNEONShiftedDeleteReleasesRearmWithoutDeletingOrFiring() {
    for status in [UInt8(0x97), 0x87] {
        withNEON { input, _ in
            var targets: [ControllerActionTarget] = []
            input.onTargetAction = { target, _ in targets.append(target) }
            neonPacket([0x97, 16, 127, 48, 127], to: input)
            #expect(targets == [.init(.hotcue1A, deck: .a)])
            neonPacket([status, 48, status == 0x87 ? 99 : 0, 0x97, 16, 127], to: input)
            #expect(targets == [.init(.hotcue1A, deck: .a), .init(.hotcue1A, deck: .a)])
        }
    }
}

@Test @MainActor func controllerCatalogueNEONManualLoopPadsRetainTheFactoryLayout() {
    withNEON { input, _ in
        var targets: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in targets.append(target) }
        neonPacket([0x9A, 120, 127, 121, 127, 122, 127, 123, 127, 124, 127, 125, 127, 126, 127, 127, 127], to: input)
        #expect(
            targets == [
                .init(.loopB, deck: .d), .init(.loopInB, deck: .d), .init(.loopOutB, deck: .d),
                .init(.reloopB, deck: .d),
            ])
        targets.removeAll()
        neonPacket([0x9A, 88, 127, 92, 127, 93, 127, 94, 127], to: input)
        #expect(targets.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueNEONDeckReportsRearmTheSharedPhysicalPadSurface() {
    withNEON { input, _ in
        var targets: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in targets.append(target) }
        neonPacket([0x97, 16, 127, 0x94, 1, 127, 0x98, 16, 127, 0x93, 1, 127, 0x97, 16, 127], to: input)
        #expect(targets == [.init(.hotcue1A, deck: .a), .init(.hotcue1B, deck: .b), .init(.hotcue1A, deck: .a)])
    }
}

@Test @MainActor func controllerCatalogueNEONHardwareBankSetupDoesNotEnableAppTrialDecks() {
    withNEON(decks: [.a, .b]) { input, _ in
        var targets: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in targets.append(target) }
        neonPacket([0x99, 16, 127, 0x9A, 16, 127, 0x97, 16, 127], to: input)
        #expect(targets == [.init(.hotcue1A, deck: .a)])
    }
}
