import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withT1(body: (ControllerMIDIConnection) throws -> Void) rethrows {
    let suite = "ddj-t1-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, deckAvailability: { DeckID.allCases })
    input.sources = [
        .init(id: 10, reference: 100, name: "DDJ-T1", identity: .init(id: 10, device: 1, names: ["DDJ-T1"]))
    ]
    input.reconcileFactoryProfiles()
    try body(input)
}

@MainActor private func t1Packet(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
}

@Test @MainActor func controllerCatalogueT1KeepsFourDeckTransportAndGlobalMixerMessages() throws {
    #expect(ControllerFactoryProfile.matching(["Pioneer DJ DDJ-T1"], automaticOnly: true) != nil)
    #expect(ControllerFactoryProfile.matching(["DDJ-T1 clone"], automaticOnly: true) == nil)
    withT1 { input in
        var targets: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in targets.append(target) }
        t1Packet([0x90, 11, 127, 0x93, 11, 127, 0x96, 70, 127, 73, 127, 86, 127, 91, 127], to: input)
        #expect(
            targets == [
                .init(.playA, deck: .a), .init(.playB, deck: .d), .init(.loadA, deck: .a), .init(.loadB, deck: .d),
                .init(.cueA, deck: .c), .init(.syncB, deck: .d),
            ])
    }
}

@Test @MainActor func controllerCatalogueT1UsesItsOwnPairedRelativeJogInsteadOfS1PlatterAddresses() {
    withT1 { input in
        var values: [Double] = []
        input.onAction = { action, value in if action == .jogA { values.append(value) } }
        t1Packet([0xB0, 2, 0, 34, 1, 33, 1, 1, 0], to: input)
        input.flushPendingActions()
        #expect(values.isEmpty)
        t1Packet([0xB0, 33, 1], to: input)
        input.flushPendingActions()
        #expect(values == [0.625])
        t1Packet([0xB0, 6, 127, 38, 127], to: input)
        input.flushPendingActions()
        #expect(values == [0.625, 0.375])
    }
}

@Test @MainActor func controllerCatalogueT1KeepsNormalAndShiftTempoPairsAndSevenBitMixer() {
    withT1 { input in
        var values: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in values.append((target, value)) }
        t1Packet([0xB1, 0, 127, 32, 127], to: input)
        input.flushPendingActions()
        #expect(values.last?.0 == .init(.tempoB, deck: .b))
        #expect(values.last?.1 == 1)
        t1Packet([0xB1, 5, 0, 37, 0, 0xB6, 25, 127, 31, 0, 2, 127], to: input)
        input.flushPendingActions()
        #expect(values.last { $0.0 == .init(.tempoB, deck: .b) }?.1 == 0)
        #expect(values.last { $0.0 == .init(.levelB, deck: .d) }?.1 == 1)
        #expect(values.last { $0.0.action == .crossfader }?.1 == 0)
        #expect(values.last { $0.0.action == .monitor }?.1 == 1)
    }
}

@Test @MainActor func controllerCatalogueT1KeepsLoopEncoderAndTouchReleaseWithoutInventingShiftEvents() {
    withT1 { input in
        var values: [(ControllerAction, Double)] = []
        input.onAction = { action, value in values.append((action, value)) }
        t1Packet([0xB0, 19, 127, 0x90, 20, 127, 54, 127, 71, 127, 0x80, 103, 0], to: input)
        #expect(values.map(\.0) == [.loopSizeA, .loopA, .jogTouchA, .jogTouchA])
        #expect(values.first?.1 == 0.5 - 1.0 / 126)
        #expect(values.last?.1 == 0)
        let count = values.count
        t1Packet([0xB0, 3, 127, 0x90, 42, 127, 46, 127, 47, 127], to: input)
        #expect(values.count == count)
    }
}

@Test @MainActor func controllerCatalogueT1KeepsOnlyUnambiguousDeckFeedbackAndNoInventedHandshake() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["DDJ-T1"], automaticOnly: true))
    #expect(profile.definition?.startup.isEmpty == true)
    #expect(profile.definition?.shutdown.isEmpty == true)
    let feedback = profile.feedback(destination: 20)
    #expect(feedback.count == 8)
    #expect(feedback.allSatisfy { $0.channel < 4 && [.playA, .playB, .keylockA, .keylockB].contains($0.action) })
    let play = try #require(feedback.first { $0.target == .init(.playB, deck: .d) })
    #expect(play.message(value: 1) == [0x93, 11, 127])
    #expect(play.message(value: 0) == [0x93, 11, 0])
}
