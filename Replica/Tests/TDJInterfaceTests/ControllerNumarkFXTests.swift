import Foundation
import TDJCore
import Testing

@testable import TDJInterface

private let numarkFXNames = ["Mixtrack Pro FX", "Mixtrack Platinum FX"]

@MainActor private func withNumarkFX(
    _ name: String, sender: @escaping ([UInt8], Int32) -> Bool = { _, _ in true },
    decks: @escaping () -> [DeckID] = { DeckID.allCases },
    body: (ControllerMIDIConnection) throws -> Void
) rethrows {
    let suite = "numark-fx-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: sender, deckAvailability: decks)
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.destinations = [
        .init(id: 30, reference: 300, name: name, identity: .init(id: 30, device: 2, names: [name])),
        .init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name])),
    ]
    input.reconcileFactoryProfiles()
    try body(input)
}

@MainActor private func numarkFXPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
}

@Test func controllerCatalogueSetupPacketsBoundSysExAndRejectEmbeddedStatuses() {
    for bytes: [UInt8] in [
        [0x90, 9, 127], [0xF0, 0, 0x20, 0x7F, 3, 0xF7], [0xF0] + Array(repeating: 0, count: 126) + [0xF7],
    ] {
        #expect(ControllerProfileData.validSetupMessage(bytes))
    }
    for bytes: [UInt8] in [
        [], [0x90, 9], [0x90, 9, 128], [0xF0, 0xF7], [0xF0, 0, 0xF7], [0xF0, 0, 0x90, 0xF7],
        [0xF0, 0, 1, 0xF7, 0], [0xF0, 0, 1, 2], [0xF0] + Array(repeating: 0, count: 127) + [0xF7],
    ] {
        #expect(!ControllerProfileData.validSetupMessage(bytes))
    }
}

@Test @MainActor func controllerCatalogueNumarkFXSendsDistinctStartupAndShutdownOnlyToThePairedOutput() throws {
    for name in numarkFXNames {
        var packets: [[UInt8]] = []
        try withNumarkFX(
            name,
            sender: { bytes, destination in
                #expect(destination == 20)
                packets.append(bytes)
                return true
            }
        ) { input in
            let profile = try #require(ControllerFactoryProfile.matching([name], automaticOnly: true))
            #expect(input.isInputActive(10))
            let startup = try #require(profile.definition?.startup)
            #expect(packets == startup)
            #expect(startup[1][4] == (name == "Mixtrack Platinum FX" ? 0x13 : 3))
            input.reconcileFactoryProfiles()
            #expect(packets == startup)
            let sources = input.sources
            input.sources = []
            input.reconcileFactoryProfiles()
            #expect(packets.last == [0xF0, 0, 0x20, 0x7F, 2, 0xF7])
            input.sources = sources
            input.reconcileFactoryProfiles()
            #expect(Array(packets.suffix(startup.count)) == startup)
        }
    }
}

@Test @MainActor func controllerCatalogueNumarkFXFailedSetupCannotEnableCoreControls() {
    for name in numarkFXNames {
        var calls = 0
        withNumarkFX(
            name,
            sender: { _, _ in
                calls += 1; return calls != 2
            }
        ) { input in
            #expect(calls == 2)
            #expect(!input.isInputActive(10))
            var actions: [ControllerAction] = []
            input.onAction = { action, _ in actions.append(action) }
            numarkFXPacket([0x90, 0, 127], to: input)
            #expect(actions.isEmpty)
        }
    }
}

@Test @MainActor func controllerCatalogueNumarkFXRoutesTransportLoopsAndLoadWithoutInventingPadModes() throws {
    for name in numarkFXNames {
        let profile = try #require(ControllerFactoryProfile.matching([name], automaticOnly: true))
        let decks = name == "Mixtrack Platinum FX" ? DeckID.allCases : DeckID.primary
        #expect(Set(profile.bindings(source: 10).compactMap(\.targetDeck)) == Set(decks))
        #expect(
            profile.bindings(source: 10).filter { $0.action.hotcueSlot != nil }.count
                == (name == "Mixtrack Pro FX" ? 16 : 0))
        withNumarkFX(name) { input in
            var received: [ControllerActionTarget] = []
            input.onTargetAction = { target, _ in received.append(target) }
            for (channel, deck) in zip(UInt8(0)..<4, decks) {
                numarkFXPacket(
                    [
                        0x90 | channel, 0, 127, 2, 127, 0x9F, 2 + channel, 127, 0x94 + channel, 64, 127, 54, 127, 55,
                        127,
                    ], to: input)
                let actions: [ControllerAction] =
                    deck.leftSide
                    ? [.playA, .syncA, .loadA, .loopA, .loopInA, .loopOutA]
                    : [.playB, .syncB, .loadB, .loopB, .loopInB, .loopOutB]
                #expect(Array(received.suffix(6)) == actions.map { .init($0, deck: deck) })
            }
            #expect(received.count == decks.count * 6)
        }
    }
    #expect(ControllerFactoryProfile.matching(["Mixtrack Pro FX clone"], automaticOnly: true) == nil)
}

@Test @MainActor func controllerCatalogueNumarkFXRetainsSignedJogsNativeTempoDirectionAndDistinctHeadphoneAddresses() {
    for name in numarkFXNames {
        withNumarkFX(name) { input in
            var received: [(ControllerActionTarget, Double)] = []
            input.onTargetAction = { target, value in received.append((target, value)) }
            numarkFXPacket([0xB1, 6, 127, 9, 127, 41, 127], to: input)
            if name == "Mixtrack Platinum FX" {
                numarkFXPacket([0xBF, 12, 127], to: input)
            } else {
                numarkFXPacket([0xBE, 47, 127], to: input)
            }
            input.flushPendingActions()
            #expect(received.first { $0.0.action == .jogB }?.1 == 0.375)
            #expect(received.first { $0.0.action == .tempoB }?.1 == 1)
            #expect(received.first { $0.0.action == .monitor }?.1 == 1)
        }
    }
    withNumarkFX("Mixtrack Platinum FX", decks: { DeckID.primary }) { input in
        var received: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in received.append(target) }
        numarkFXPacket([0x92, 0, 127, 0x9F, 4, 127, 0xB2, 6, 1], to: input)
        input.flushPendingActions()
        #expect(received.isEmpty)
    }
}
