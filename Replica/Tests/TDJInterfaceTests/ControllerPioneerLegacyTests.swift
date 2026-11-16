import Foundation
import TDJCore
import Testing

@testable import TDJInterface

private let legacyPioneerNames = ["DDJ-WeGO3", "DDJ-WeGO2", "DDJ-WeGO", "DDJ-ERGO"]

@MainActor private func withLegacyPioneer(
    _ name: String, decks: @escaping () -> [DeckID] = { DeckID.allCases },
    body: (ControllerMIDIConnection) throws -> Void
) rethrows {
    let suite = "legacy-pioneer-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, deckAvailability: decks)
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    try body(input)
}

@MainActor private func legacyPioneerPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
}

@Test @MainActor func controllerPioneerLegacyMatchesGenerationsAndDocumentsTheirDeckLimits() throws {
    for name in legacyPioneerNames + ["DDJ-ERGO-V"] {
        let profile = try #require(ControllerFactoryProfile.matching([name], automaticOnly: true))
        let bindings = profile.bindings(source: 10)
        let decks = Set(bindings.compactMap(\.targetDeck))
        #expect(decks == Set(name == "DDJ-WeGO3" ? DeckID.primary : DeckID.allCases))
        #expect(profile.definition?.startup.isEmpty == true)
        #expect(profile.definition?.shutdown.isEmpty == true)
        #expect(bindings.filter { $0.action.hotcueSlot != nil }.count == decks.count * 4)
    }
    for name in ["DDJ-WeGO5", "DDJ-ERGO clone", "DDJ-ERGO-K"] {
        #expect(ControllerFactoryProfile.matching([name], automaticOnly: true) == nil)
    }
}

@Test @MainActor func controllerPioneerLegacyRoutesEachPublishedPlayLoadAndHotCueChannel() {
    for name in legacyPioneerNames {
        withLegacyPioneer(name) { input in
            var received: [ControllerActionTarget] = []
            input.onTargetAction = { target, _ in received.append(target) }
            let decks = name == "DDJ-WeGO3" ? DeckID.primary : DeckID.allCases
            for (channel, deck) in zip(UInt8(0)..<4, decks) {
                legacyPioneerPacket(
                    [0x90 | channel, name == "DDJ-WeGO3" ? 8 : 11, 127, 49, 127, 0x96, 70 + channel, 127], to: input)
                let actions: [ControllerAction] =
                    deck.leftSide ? [.playA, .hotcue4A, .loadA] : [.playB, .hotcue4B, .loadB]
                #expect(Array(received.suffix(3)) == actions.map { .init($0, deck: deck) })
            }
            #expect(received.count == decks.count * 3)
        }
    }
}

@Test @MainActor func controllerPioneerLegacyUsesEachGenerationsJogEncodingAndShiftAddress() {
    for name in legacyPioneerNames {
        let ergo = name == "DDJ-ERGO"
        withLegacyPioneer(name) { input in
            var values: [Double] = []
            input.onTargetAction = { target, value in
                #expect(target == .init(.jogB, deck: .b))
                values.append(value)
            }
            legacyPioneerPacket([0xB1, 39, ergo ? 1 : 65], to: input)
            input.flushPendingActions()
            legacyPioneerPacket([0xB1, 39, ergo ? 127 : 63], to: input)
            input.flushPendingActions()
            #expect(values == [0.625, 0.375])
        }
    }
}

@Test @MainActor func controllerPioneerLegacyKeepsMixerMessagesOnTheGlobalChannel() {
    for name in legacyPioneerNames {
        withLegacyPioneer(name) { input in
            var received: [(ControllerActionTarget, Double)] = []
            input.onTargetAction = { target, value in received.append((target, value)) }
            legacyPioneerPacket([0xB6, 21, 127, 53, 127, 0x96, 85, 127], to: input)
            input.flushPendingActions()
            #expect(Set(received.map(\.0)) == Set([.init(.levelB, deck: .b), .init(.cueB, deck: .b)]))
            #expect(received.allSatisfy { $0.1 == 1 })
        }
    }
}

@Test @MainActor func controllerPioneerLegacyRetainsDistinctLoopButtonsAndSignedEncoders() {
    for name in legacyPioneerNames {
        withLegacyPioneer(name) { input in
            var received: [ControllerActionTarget] = []
            input.onTargetAction = { target, _ in received.append(target) }
            if name == "DDJ-WeGO3" {
                legacyPioneerPacket([0x90, 18, 127, 19, 127, 20, 127, 80, 127], to: input)
                #expect(received.map(\.action) == [.loopDownA, .loopUpA, .loopA, .reloopA])
            } else {
                legacyPioneerPacket([0xB0, 19, 2, 0x90, 20, 127, 80, 127], to: input)
                #expect(received.map(\.action) == [.loopSizeA, .loopA, .reloopA])
            }
        }
    }
}

@Test @MainActor func controllerPioneerLegacyBlocksUnpublishedAndInactiveDeckPackets() {
    for name in legacyPioneerNames {
        withLegacyPioneer(name, decks: { DeckID.primary }) { input in
            var received: [ControllerAction] = []
            input.onTargetAction = { target, _ in received.append(target.action) }
            legacyPioneerPacket([0x92, 11, 127, 0xB2, 19, 1, 0x96, 72, 127], to: input)
            input.flushPendingActions()
            #expect(received.isEmpty)
        }
    }
    withLegacyPioneer("DDJ-WeGO3") { input in
        var received: [ControllerAction] = []
        input.onAction = { action, _ in received.append(action) }
        legacyPioneerPacket([0x90, 11, 127, 26, 127, 0x92, 8, 127, 0x96, 72, 127], to: input)
        input.flushPendingActions()
        #expect(received.isEmpty)
    }
    withLegacyPioneer("DDJ-ERGO") { input in
        var received: [Double] = []
        input.onAction = { action, value in if action == .jogTouchA { received.append(value) } }
        legacyPioneerPacket([0x90, 55, 127, 54, 127, 0x80, 55, 0], to: input)
        #expect(received == [1, 0])
    }
}
