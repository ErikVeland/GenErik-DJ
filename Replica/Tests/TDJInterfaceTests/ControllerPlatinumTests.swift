import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withOriginalPlatinum(_ body: (ControllerMIDIConnection) throws -> Void) rethrows {
    let suite = "original-platinum-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences, factoryPacketSender: { _, _ in true }, deckAvailability: { DeckID.allCases })
    input.sources = [
        .init(
            id: 10, reference: 100, name: "Mixtrack Platinum",
            identity: .init(id: 10, device: 1, names: ["Mixtrack Platinum"]))
    ]
    input.destinations = [
        .init(
            id: 20, reference: 200, name: "Mixtrack Platinum",
            identity: .init(id: 20, device: 1, names: ["Mixtrack Platinum"]))
    ]
    input.reconcileFactoryProfiles()
    try body(input)
}

@MainActor private func originalPlatinumPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
}

@Test @MainActor func controllerCatalogueOriginalPlatinumIsSeparateFromFXAndKeepsDeckLocalLoad() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["Mixtrack Platinum"], automaticOnly: true))
    let fx = try #require(ControllerFactoryProfile.matching(["Mixtrack Platinum FX"], automaticOnly: true))
    #expect(profile != fx)
    #expect(profile.definition?.startup.first?.count == 14)
    #expect(
        profile.bindings(source: 10).filter { $0.action == .tempoA || $0.action == .tempoB }.allSatisfy {
            $0.lowNumber == 119
        })
    withOriginalPlatinum { input in
        var received: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in received.append(target) }
        for (channel, deck) in zip(UInt8(0)..<4, DeckID.allCases) {
            originalPlatinumPacket([0x90 | channel, 0, 127, 16, 127], to: input)
            #expect(
                Array(received.suffix(2)) == [
                    .init(deck.leftSide ? .playA : .playB, deck: deck),
                    .init(deck.leftSide ? .loadA : .loadB, deck: deck),
                ])
        }
    }
}

@Test @MainActor func controllerCatalogueOriginalPlatinumUsesCC119ForTempoAndIgnoresTheStandardLowByte() {
    withOriginalPlatinum { input in
        var values: [Double] = []
        input.onTargetAction = { target, value in if target == .init(.tempoB, deck: .d) { values.append(value) } }
        originalPlatinumPacket([0xB3, 9, 127], to: input)
        input.flushPendingActions()
        #expect(values.count == 1)
        originalPlatinumPacket([0xB3, 41, 127], to: input)
        input.flushPendingActions()
        #expect(values.count == 1)
        originalPlatinumPacket([0xB3, 119, 127], to: input)
        input.flushPendingActions()
        #expect(values.last == 1)
        #expect(values.count == 2)
    }
}

@Test @MainActor func controllerCatalogueOriginalPlatinumKeepsGlobalShiftAndTouchReleaseSemantics() {
    withOriginalPlatinum { input in
        var received: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in received.append((target, value)) }
        originalPlatinumPacket([0x90, 6, 127, 0x9F, 50, 127, 0x80, 6, 0, 0x91, 0, 127, 0x95, 56, 127], to: input)
        #expect(
            received.map(\.0) == [.init(.jogTouchA, deck: .a), .init(.jogTouchA, deck: .a), .init(.loopInB, deck: .b)])
        #expect(received.prefix(2).map(\.1) == [1, 0])
        originalPlatinumPacket([0x8F, 50, 0, 0x81, 0, 0, 0x91, 0, 127], to: input)
        #expect(received.last?.0 == .init(.playB, deck: .b))
    }
}

@Test @MainActor func controllerCatalogueOriginalPlatinumKeepsWrappedJogHistoryPerDeckAndResetsOnReconnect() {
    withOriginalPlatinum { input in
        var values: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in if target.action.isJog { values.append((target, value)) } }
        originalPlatinumPacket([0xB0, 6, 50], to: input)
        input.flushPendingActions()
        originalPlatinumPacket([0xB0, 6, 70, 0xB1, 6, 70], to: input)
        input.flushPendingActions()
        #expect(values.dropFirst().first { $0.0.action == .jogA }?.1 == 1)
        #expect(values.dropFirst().first { $0.0.action == .jogB }?.1 == 0)
        let sources = input.sources
        input.sources = []
        input.reconcileFactoryProfiles()
        input.sources = sources
        input.reconcileFactoryProfiles()
        originalPlatinumPacket([0xB0, 6, 70], to: input)
        input.flushPendingActions()
        #expect(values.last?.1 == 0)
    }
}

@Test func controllerCatalogueRejectsInvalidExplicitPairMetadata() throws {
    for (encoding, low, valid) in [
        ("paired14Bit", 119, true), ("paired14Bit", 9, false), ("paired14Bit", 128, false), ("absolute", 119, false),
    ] {
        let data = try JSONSerialization.data(withJSONObject: [
            "schemaVersion": 1,
            "profiles": [
                [
                    "id": "pair fixture", "aliases": ["pair fixture"],
                    "inputs": [
                        [
                            "action": "tempoA", "kind": "control", "channel": 0, "number": 9, "encoding": encoding,
                            "inverted": false, "lowNumber": low,
                        ]
                    ], "outputs": [], "startup": [], "shutdown": [], "autoSelect": true, "scope": "fixture",
                    "source": "fixture",
                ]
            ],
        ])
        if valid {
            #expect(try ControllerProfileCatalogue.decode(data).profiles.count == 1)
        } else {
            #expect(throws: (any Error).self) { try ControllerProfileCatalogue.decode(data) }
        }
    }
}
