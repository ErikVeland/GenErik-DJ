import Foundation
import TDJCore
import Testing

@testable import TDJInterface

private let legacySystemNames = ["XDJ-AERO", "XDJ-R1"]

@MainActor private func withLegacySystem(
    _ name: String, decks: @escaping () -> [DeckID] = { DeckID.allCases },
    body: (ControllerMIDIConnection) throws -> Void
) rethrows {
    let suite = "legacy-system-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, deckAvailability: decks)
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    try body(input)
}

@MainActor private func legacySystemPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
}

@Test @MainActor func controllerPioneerLegacySystemsMatchExactModelsAndActualHotCueCounts() throws {
    for name in legacySystemNames {
        let profile = try #require(ControllerFactoryProfile.matching([name], automaticOnly: true))
        #expect(profile.definition?.startup.isEmpty == true)
        #expect(profile.definition?.shutdown.isEmpty == true)
        #expect(!profile.isPlayer)
        #expect(Set(profile.bindings(source: 10).compactMap(\.targetDeck)) == Set(DeckID.allCases))
        #expect(
            profile.bindings(source: 10).filter { $0.action.hotcueSlot != nil }.count == (name == "XDJ-R1" ? 12 : 0))
    }
    for name in ["XDJ-AERO clone", "XDJ-R1S", "XDJ-R2"] {
        #expect(ControllerFactoryProfile.matching([name], automaticOnly: true) == nil)
    }
}

@Test @MainActor func controllerPioneerLegacySystemsFlushDeckBrowsersBeforeTheCorrectLoad() {
    for name in legacySystemNames {
        withLegacySystem(name) { input in
            var received: [(ControllerActionTarget, Double)] = []
            input.onTargetAction = { target, value in received.append((target, value)) }
            for (channel, deck) in zip(UInt8(0)..<4, DeckID.allCases) {
                legacySystemPacket([0xB0 | channel, 64, 2, 0x90 | channel, 66, 127], to: input)
                #expect(received[received.count - 2].0.action == .browse)
                #expect(abs(received[received.count - 2].1 - (0.5 + 2.0 / 126)) < 0.000001)
                #expect(received.last?.0 == .init(deck.leftSide ? .loadA : .loadB, deck: deck))
            }
            #expect(received.count == 8)
            legacySystemPacket([0x96, 66, 127, 70, 127, 71, 127], to: input)
            #expect(received.count == 8)
        }
    }
}

@Test @MainActor func controllerPioneerLegacySystemsRetainLoopEncoderAndShiftJogContracts() {
    for name in legacySystemNames {
        withLegacySystem(name) { input in
            var received: [(ControllerActionTarget, Double)] = []
            input.onTargetAction = { target, value in received.append((target, value)) }
            legacySystemPacket([0xB1, 19, 126, 7, 65, 0x91, 20, 127, 80, 127], to: input)
            input.flushPendingActions()
            #expect(
                received.map(\.0) == [
                    .init(.loopSizeB, deck: .b), .init(.loopB, deck: .b), .init(.reloopB, deck: .b),
                    .init(.jogB, deck: .b),
                ])
            #expect(abs(received[0].1 - (0.5 - 2.0 / 126)) < 0.000001)
            #expect(received.last?.1 == 0.625)
        }
    }
}

@Test @MainActor func controllerPioneerLegacySystemsKeepFourDeckMixersSeparateFromBrowsers() {
    for name in legacySystemNames {
        withLegacySystem(name) { input in
            var received: [ControllerActionTarget] = []
            input.onTargetAction = { target, _ in received.append(target) }
            legacySystemPacket([0xB6, 25, 127, 57, 127, 0x96, 87, 127, 0x93, 11, 127], to: input)
            input.flushPendingActions()
            #expect(Set(received) == Set([.init(.levelB, deck: .d), .init(.cueB, deck: .d), .init(.playB, deck: .d)]))
        }
    }
}

@Test @MainActor func controllerPioneerLegacySystemsBlockInactiveDecksAndKeepHotCuesModelSpecific() {
    for name in legacySystemNames {
        withLegacySystem(name, decks: { DeckID.primary }) { input in
            var received: [ControllerActionTarget] = []
            input.onTargetAction = { target, _ in received.append(target) }
            legacySystemPacket([0x92, 66, 127, 11, 127, 0xB2, 19, 2], to: input)
            input.flushPendingActions()
            #expect(received.isEmpty)
            legacySystemPacket([0x90, 48, 127], to: input)
            #expect(received == (name == "XDJ-R1" ? [.init(.hotcue3A, deck: .a)] : []))
        }
    }
}
