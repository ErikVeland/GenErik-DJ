import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withNS4FX(
    _ decks: [DeckID] = DeckID.allCases, _ body: (ControllerMIDIConnection) throws -> Void
) rethrows {
    let suite = "ns4fx-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences, factoryPacketSender: { _, _ in true },
        deckAvailability: { decks })
    input.sources = [.init(id: 10, reference: 100, name: "NS4FX", identity: .init(id: 10, device: 1, names: ["NS4FX"]))]
    input.destinations = [
        .init(id: 20, reference: 200, name: "NS4FX", identity: .init(id: 20, device: 1, names: ["NS4FX"]))
    ]
    input.reconcileFactoryProfiles()
    try body(input)
}

@MainActor private func ns4fxPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
}

@Test @MainActor func controllerCatalogueNS4FXBankChangeReleasesOnlyTheSelectedSidesCue() {
    withNS4FX { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in
            if [.cuePreviewA, .cuePreviewB].contains(target.action) { events.append((target, value)) }
        }
        ns4fxPacket([0x90, 1, 127, 0x91, 1, 127], to: input)
        ns4fxPacket([0x92, 8, 127], to: input)
        #expect(events.map(\.0.deck) == [.a, .b, .a])
        #expect(events.map(\.1) == [1, 1, 0])
    }
}

@Test @MainActor func controllerCatalogueNS4FXBankChangeResetsPickupOnlyOnItsSide() {
    withNS4FX { input in
        input.currentTargetValue = { [.tempoA, .tempoB].contains($0.action) ? 0.5 : nil }
        var events: [(ControllerAction, Double)] = []
        input.onAction = { action, value in if [.tempoA, .tempoB].contains(action) { events.append((action, value)) } }
        ns4fxPacket([0xB0, 9, 64, 41, 0, 0xB1, 9, 64, 41, 0], to: input)
        input.flushPendingActions()
        events.removeAll()
        ns4fxPacket([0x92, 8, 127, 0xB0, 9, 0, 41, 0, 0xB1, 9, 0, 41, 0], to: input)
        input.flushPendingActions()
        #expect(events.map(\.0) == [.tempoB])
        ns4fxPacket([0xB0, 9, 64, 41, 0], to: input)
        input.flushPendingActions()
        #expect(events.last?.0 == .tempoA)
    }
}

@Test @MainActor func controllerCatalogueNS4FXBankChangeDiscardsOnlyItsSidesIncompletePairs() {
    withNS4FX { input in
        var actions: [ControllerAction] = []
        input.onAction = { action, _ in if [.tempoA, .tempoB].contains(action) { actions.append(action) } }
        ns4fxPacket([0xB0, 9, 64, 0xB1, 9, 64], to: input)
        input.flushPendingActions()
        actions.removeAll()
        ns4fxPacket([0x92, 8, 127, 0xB0, 41, 127, 0xB1, 41, 127], to: input)
        input.flushPendingActions()
        #expect(actions == [.tempoB])
    }
}

@Test @MainActor func controllerCatalogueNS4FXShiftRearmsTempoPickupWithoutResettingTheCrossfader() {
    withNS4FX { input in
        input.currentTargetValue = { [.tempoA, .crossfader].contains($0.action) ? 0.5 : nil }
        var events: [(ControllerAction, Double)] = []
        input.onAction = { action, value in
            if [.tempoA, .crossfader].contains(action) { events.append((action, value)) }
        }
        ns4fxPacket([0xB0, 9, 64, 41, 0, 0xBF, 8, 64], to: input)
        input.flushPendingActions()
        events.removeAll()
        ns4fxPacket(
            [
                0x90, 32, 127, 0xB0, 9, 0, 41, 0, 0x80, 32, 0,
                0xB0, 9, 0, 41, 0, 0xBF, 8, 0,
            ], to: input)
        input.flushPendingActions()
        #expect(events.map(\.0) == [.crossfader])
        ns4fxPacket([0xB0, 9, 64, 41, 0], to: input)
        input.flushPendingActions()
        #expect(events.last?.0 == .tempoA)
    }
}

@Test @MainActor func controllerCatalogueNS4FXBankChangeStillProtectsALearnedTempoMapping() {
    withNS4FX { input in
        input.select(10)
        input.learningEncoding = .paired14Bit
        input.learning = .tempoA
        ns4fxPacket([0xB0, 9, 64], to: input)
        #expect(input.learning == nil)
        #expect(input.factoryProfileName(source: 10) == nil)
        input.currentTargetValue = { $0.action == .tempoA ? 0.5 : nil }
        var values: [Double] = []
        input.onAction = { action, value in if action == .tempoA { values.append(value) } }
        ns4fxPacket([0xB0, 9, 64, 41, 0], to: input)
        input.flushPendingActions()
        #expect(!values.isEmpty)
        values.removeAll()
        ns4fxPacket([0x92, 8, 127, 0xB0, 9, 0, 41, 0], to: input)
        input.flushPendingActions()
        #expect(values.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueNS4FXBankChangeIgnoresUnrelatedAndReleasePackets() {
    withNS4FX { input in
        var releases: [ControllerActionTarget] = []
        input.onTargetAction = { target, value in
            if target.action == .cuePreviewA && value == 0 { releases.append(target) }
        }
        ns4fxPacket([0x90, 1, 127, 0x92, 8, 0, 0x82, 8, 127, 0x94, 8, 127, 0x92, 9, 127], to: input)
        #expect(releases.isEmpty)
        ns4fxPacket([0x92, 8, 127], to: input)
        #expect(releases == [.init(.cuePreviewA, deck: .a)])
    }
}

@Test func controllerCatalogueNS4FXBankChangesRequireBoundedUniqueAddressesAndDeckScopes() throws {
    let valid: [String: Any] = ["channel": 0, "number": 8, "onValue": 127, "decks": ["a", "c"]]
    var invalid: [[String: Any]] = []
    for (key, value) in [
        ("channel", 16 as Any), ("number", 128 as Any), ("onValue", 0 as Any), ("onValue", 128 as Any),
        ("decks", [] as [String] as Any), ("decks", ["a", "a"] as Any),
    ] {
        var bank = valid
        bank[key] = value
        invalid.append(bank)
    }
    let cases: [(String?, [[String: Any]])] =
        invalid.map { (nil, [$0]) }
        + [(nil, [valid, valid]), (nil, Array(repeating: valid, count: 17)), ("player", [valid])]
    for (role, banks) in cases {
        var profile: [String: Any] = [
            "id": "fixture", "aliases": ["fixture"],
            "inputs": [
                [
                    "action": "playA", "kind": "note", "channel": 0, "number": 0,
                    "encoding": "absolute", "inverted": false,
                ]
            ], "outputs": [], "startup": [], "shutdown": [],
            "autoSelect": true, "scope": "fixture", "source": "fixture", "bankChanges": banks,
        ]
        if let role { profile["role"] = role }
        let data = try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "profiles": [profile]])
        #expect(throws: (any Error).self) { try ControllerProfileCatalogue.decode(data) }
    }
}

@Test @MainActor func controllerCatalogueNS4FXKeepsItsExactCoreIdentityAndFourDeckAddresses() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["NS4FX"], automaticOnly: true))
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 64 && data.outputs.count == 12)
    #expect(data.startup.count == 5 && data.shutdown.count == 4)
    #expect(data.bankChanges?.count == 4)
    #expect(ControllerFactoryProfile.matching(["NS4FX MK2"], automaticOnly: true) == nil)
    #expect(!data.inputs.contains { $0.action == .keylockA || $0.action.hotcueSlot != nil })
    withNS4FX { input in
        var targets: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in targets.append(target) }
        ns4fxPacket([0x93, 0, 127, 0x9F, 5, 127, 0x92, 27, 127], to: input)
        #expect(targets == [.init(.playB, deck: .d), .init(.loadB, deck: .d), .init(.cueA, deck: .c)])
    }
    let play = try #require(profile.feedback(destination: 20).first { $0.target == .init(.playB, deck: .d) })
    #expect(play.message(value: 1) == [0x93, 0, 127])
    #expect(play.message(value: 0) == [0x93, 0, 1])
}

@Test @MainActor func controllerCatalogueNS4FXKeepsWrappedJogCountsAndClearsOldBankDirection() {
    withNS4FX { input in
        var counts: [Double] = []
        input.onJogAction = { target, motion in
            #expect(target == .init(.jogA, deck: .a, argument: 1240))
            if case .relative(let value) = motion { counts.append(value) }
        }
        ns4fxPacket([0xB0, 6, 63, 6, 65], to: input)
        input.flushPendingActions()
        #expect(counts == [128])
        ns4fxPacket([0x92, 8, 127, 0x90, 8, 127, 0xB0, 6, 65], to: input)
        input.flushPendingActions()
        #expect(counts.last == -63)
    }
}

@Test @MainActor func controllerCatalogueNS4FXShiftSuppressesUnsupportedAlternativesWhileMixerKeepsWorking() {
    withNS4FX { input in
        var actions: [ControllerAction] = []
        input.onAction = { action, _ in actions.append(action) }
        ns4fxPacket(
            [
                0x90, 32, 127, 0x91, 32, 127, 0x80, 32, 0,
                0x90, 4, 127, 5, 127, 0x9F, 2, 127, 0x8F, 2, 0,
                0xB0, 9, 0, 41, 0, 6, 1, 0xBF, 12, 0, 0xB1, 22, 127,
            ], to: input)
        input.flushPendingActions()
        #expect(actions == [.gainB])
        ns4fxPacket([0x81, 32, 0, 0x90, 0, 127], to: input)
        #expect(actions.last == .playA)
    }
}

@Test @MainActor func controllerCatalogueNS4FXPreservesTheNativeTwoDeckGate() {
    withNS4FX([.a, .b]) { input in
        var targets: [ControllerActionTarget] = []
        input.onTargetAction = { target, value in if value > 0 { targets.append(target) } }
        ns4fxPacket([0x92, 0, 127, 0x93, 0, 127, 0x9F, 4, 127, 5, 127, 0x90, 0, 127], to: input)
        #expect(targets == [.init(.playA, deck: .a)])
    }
}
