import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withS1(body: (ControllerMIDIConnection) throws -> Void) rethrows {
    let suite = "s1-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences)
    input.sources = [
        .init(id: 10, reference: 100, name: "DDJ-S1", identity: .init(id: 10, device: 1, names: ["DDJ-S1"]))
    ]
    input.reconcileFactoryProfiles()
    try body(input)
}

@MainActor private func s1Packet(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
}

@Test @MainActor func controllerPioneerS1UsesItsOwnTransportPadsAndLoadMessages() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["DDJ-S1"], automaticOnly: true))
    #expect(profile.definition?.startup.isEmpty == true)
    #expect(Set(profile.bindings(source: 10).compactMap(\.targetDeck)) == Set(DeckID.primary))
    #expect(profile.feedback(destination: 20).count == 18)
    #expect(ControllerFactoryProfile.matching(["DDJ-S1 clone"], automaticOnly: true) == nil)
    withS1 { input in
        var received: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in received.append(target) }
        s1Packet([0x91, 11, 127, 27, 127, 61, 127, 46, 127], to: input)
        #expect(
            received == [
                .init(.playB, deck: .b), .init(.syncB, deck: .b), .init(.loadB, deck: .b), .init(.hotcue5B, deck: .b),
            ])
        s1Packet([0x91, 88, 127, 0x96, 71, 127], to: input)
        #expect(received.count == 4)
    }
}

@Test @MainActor func controllerPioneerS1DoesNotMoveOnHalfOrRepeatedRelativePairs() {
    withS1 { input in
        var values: [Double] = []
        input.onAction = { action, value in if action == .jogA { values.append(value) } }
        s1Packet([0xB0, 34, 1, 2, 0], to: input)
        input.flushPendingActions()
        #expect(values.isEmpty)
        s1Packet([0xB0, 34, 1, 34, 1], to: input)
        input.flushPendingActions()
        #expect(values == [0.625])
        s1Packet([0xB0, 2, 127, 34, 127], to: input)
        input.flushPendingActions()
        #expect(values == [0.625, 0.375])
    }
}

@Test @MainActor func controllerPioneerS1KeepsDeckPairsIndependentAndClearsThemOnReconnect() {
    withS1 { input in
        var received: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in received.append((target, value)) }
        s1Packet([0xB0, 2, 0, 0xB1, 2, 127, 34, 127, 0xB0, 34, 1], to: input)
        input.flushPendingActions()
        #expect(Set(received.map(\.0)) == Set([.init(.jogA, deck: .a), .init(.jogB, deck: .b)]))
        #expect(received.first { $0.0.deck == .a }?.1 == 0.625)
        #expect(received.first { $0.0.deck == .b }?.1 == 0.375)
        let sources = input.sources
        s1Packet([0xB0, 2, 0], to: input)
        input.sources = []
        input.reconcileFactoryProfiles()
        input.sources = sources
        input.reconcileFactoryProfiles()
        let count = received.count
        s1Packet([0xB0, 34, 1], to: input)
        input.flushPendingActions()
        #expect(received.count == count)
    }
}

@Test @MainActor func controllerPioneerS1HandlesShiftJogTouchAndItsSevenBitMixer() {
    withS1 { input in
        var received: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in received.append((target, value)) }
        s1Packet([0x91, 104, 127, 0xB1, 7, 0, 39, 1, 0x81, 104, 0], to: input)
        input.flushPendingActions()
        #expect(
            received.map(\.0) == [.init(.jogTouchB, deck: .b), .init(.jogB, deck: .b), .init(.jogTouchB, deck: .b)])
        #expect(received.map(\.1) == [1, 0.625, 0])
        received = []
        s1Packet([0xB4, 9, 127, 0x94, 85, 127], to: input)
        input.flushPendingActions()
        #expect(Set(received.map(\.0)) == Set([.init(.levelB, deck: .b), .init(.cueB, deck: .b)]))
    }
}
