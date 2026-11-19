import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withEngineFixed(
    _ name: String, decks: [DeckID] = DeckID.allCases, _ body: (ControllerMIDIConnection) throws -> Void
) throws {
    let suite = "engine-fixed-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, deckAvailability: { decks })
    input.sources = [
        .init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name])),
        .init(id: 11, reference: 101, name: name, identity: .init(id: 11, device: 2, names: [name])),
    ]
    input.reconcileFactoryProfiles()
    #expect(!input.isInputActive(10))
    let profile = try #require(ControllerFactoryProfile.matching([name]))
    #expect(!profile.selectsAutomatically)
    for source: Int32 in [10, 11] { input.select(source); input.applyFactoryProfile(profile) }
    try body(input)
}

@MainActor private func engineFixedPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source)
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueEngineFixedEveryMixerStripAndModelSpecificGlobalKeepsItsAddress() throws {
    for name in ["SC Live 2", "SC Live 4", "Mixstream Pro Go"] {
        for decks in [DeckID.primary, DeckID.allCases] {
            try withEngineFixed(name, decks: decks) { input in
                input.currentTargetValue = { _ in 0.5 }
                var events: [(ControllerActionTarget, Double)] = []
                input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
                let targets = name == "SC Live 4" ? DeckID.allCases : DeckID.primary
                for (index, deck) in targets.enumerated() {
                    for (number, action): (UInt8, ControllerAction) in [
                        (3, .gainA), (4, .highA), (6, .midA), (8, .lowA), (14, .levelA),
                    ] {
                        events.removeAll()
                        engineFixedPacket([0xB0 + UInt8(index), number, 64], to: input)
                        engineFixedPacket([0xB0 + UInt8(index), number, 127], to: input)
                        #expect(events.count == (decks.contains(deck) ? 2 : 0))
                        #expect(events.allSatisfy { $0.0 == .init(action.assigned(to: deck), deck: deck) })
                        if decks.contains(deck) { #expect(events.map(\.1) == [64.0 / 127, 1]) }
                    }
                    events.removeAll()
                    engineFixedPacket([0x90 + UInt8(index), 13, 127, 0x80 + UInt8(index), 13, 127], to: input)
                    #expect(events.count == (decks.contains(deck) ? 1 : 0))
                    #expect(events.allSatisfy { $0.0 == .init(ControllerAction.cueA.assigned(to: deck), deck: deck) })
                }
                let globals: [(UInt8, ControllerAction)] =
                    name == "Mixstream Pro Go"
                    ? [(9, .cueMix), (10, .monitor), (14, .crossfader), (15, .master)]
                    : [(18, .cueMix), (19, .monitor), (14, .crossfader), (20, .master)]
                for (number, action) in globals {
                    events.removeAll()
                    engineFixedPacket([0xBF, number, 64], to: input)
                    engineFixedPacket([0xBF, number, 0], to: input)
                    #expect(events.map(\.1) == [64.0 / 127, 0])
                    #expect(events.allSatisfy { $0.0.action == action })
                }
            }
        }
    }
}

@Test @MainActor func controllerCatalogueEngineFixedTransportAndLoopAddressesRemainModelSpecific() throws {
    for name in ["SC Live 2", "Mixstream Pro Go"] {
        try withEngineFixed(name) { input in
            var events: [(ControllerActionTarget, Double)] = []
            input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
            for (index, deck) in DeckID.primary.enumerated() {
                var buttons: [(UInt8, ControllerAction)] = [
                    (10, .playA), (9, .cuePreviewA), (8, .syncA), (29, .pitchBendDownA), (30, .pitchBendUpA),
                ]
                if name == "SC Live 2" { buttons += [(34, .keylockA), (37, .loopInA), (38, .loopOutA)] }
                for (number, action) in buttons {
                    events.removeAll()
                    engineFixedPacket([0x92 + UInt8(index), number, 127, 0x82 + UInt8(index), number, 127], to: input)
                    #expect(events.count == (action.isMomentary ? 2 : 1))
                    #expect(events.allSatisfy { $0.0 == .init(action.assigned(to: deck), deck: deck) })
                }
                events.removeAll()
                engineFixedPacket([0x9F, 1 + UInt8(index), 127, 1 + UInt8(index), 0], to: input)
                #expect(events.map { $0.0 } == [.init(ControllerAction.loadA.assigned(to: deck), deck: deck)])
                events.removeAll()
                engineFixedPacket([0xB2 + UInt8(index), 32, 1, 32, 127], to: input)
                #expect(events.count == (name == "SC Live 2" ? 2 : 0))
                if name == "SC Live 2" { #expect(events.map { Int((($0.1 - 0.5) * 126).rounded()) } == [1, -1]) }
            }
        }
    }
}

@Test @MainActor func controllerCatalogueEngineFixedTempoExistsOnlyForExplicitSC2PolarityAndPair() throws {
    for name in ["SC Live 2", "SC Live 4", "Mixstream Pro Go"] {
        try withEngineFixed(name) { input in
            input.currentTargetValue = { _ in 0.5 }
            var events: [(ControllerActionTarget, Double)] = []
            input.onTargetAction = { target, value in
                if target.action == .tempoA || target.action == .tempoB { events.append((target, value)) }
            }
            engineFixedPacket([0xB2, 75, 127], to: input)
            #expect(events.isEmpty)
            engineFixedPacket([0xB2, 31, 64, 75, 0], to: input)
            engineFixedPacket([0xB2, 31, 0, 75, 0], to: input)
            if name == "SC Live 2" {
                #expect(events.last?.1 == 1 && events.last?.0.deck == .a)
                engineFixedPacket([0xB2, 31, 127, 75, 127], to: input)
                #expect(events.last?.1 == 0)
            } else {
                #expect(events.isEmpty)
            }
        }
    }
}

@Test @MainActor func controllerCatalogueEngineFixedShiftRearmAndOwnedCueNeverCrossSources() throws {
    for name in ["SC Live 2", "Mixstream Pro Go"] {
        try withEngineFixed(name) { input in
            var values: [Double] = []
            var actions: [ControllerAction] = []
            input.onAction = { action, value in
                if action == .cuePreviewA { values.append(value) }
                if !action.isJog { actions.append(action) }
            }
            engineFixedPacket([0x92, 9, 127], to: input)
            engineFixedPacket([0x92, 9, 127], to: input, source: 11)
            engineFixedPacket([0x92, 28, 127, 0x82, 9, 127], to: input)
            #expect(values == [1])
            engineFixedPacket([0x82, 9, 127], to: input, source: 11)
            #expect(values == [1, 0])
            engineFixedPacket([0x92, 10, 127, 10, 0], to: input)
            actions.removeAll()
            engineFixedPacket([0x82, 28, 127, 0x92, 10, 127, 10, 0], to: input)
            #expect(actions == [.playA])
        }
    }
}

@Test @MainActor func controllerCatalogueEngineFixedNeverRoutesSC4LayersOrOtherUnqualifiedControls() throws {
    for name in ["SC Live 2", "SC Live 4", "Mixstream Pro Go"] {
        try withEngineFixed(name) { input in
            var actions: [ControllerAction] = []
            input.onAction = { action, _ in if !action.isJog { actions.append(action) } }
            for channel: UInt8 in 4...7 {
                engineFixedPacket(
                    [
                        0x90 + channel, 10, 127, 9, 127, 31, 127, 28, 127, 15, 127, 0xB0 + channel, 17, 127, 49, 127,
                        55, 127, 77, 127, 31, 127, 75, 127,
                    ], to: input)
            }
            if name == "SC Live 4" {
                engineFixedPacket([0x9F, 1, 127, 2, 127, 28, 127, 29, 127, 30, 127, 31, 127], to: input)
            } else {
                for channel: UInt8 in 2...3 {
                    for number: UInt8 in [11, 12, 13, 14, 15, 16, 17, 18, 23, 24, 31, 33, 35, 36, 39] {
                        engineFixedPacket([0x90 + channel, number, 127, number, 0], to: input)
                    }
                    engineFixedPacket([0xB0 + channel, 17, 127, 49, 127, 55, 127, 77, 127], to: input)
                }
            }
            engineFixedPacket([0xB0, 11, 127, 0xBF, 5, 1, 0x9F, 6, 127, 7, 127], to: input)
            #expect(actions.isEmpty)
        }
        let profile = try #require(ControllerFactoryProfile.matching([name]))
        #expect(profile.definition?.startup.isEmpty == true && profile.definition?.shutdown.isEmpty == true)
        #expect(profile.definition?.outputs.isEmpty == true && profile.definition?.audioOutput == nil)
        for other in ["PRIME 4", "PRIME GO", "Mixstream Pro", "Mixstream Pro+"] {
            #expect(ControllerFactoryProfile.matching([other]) != profile)
        }
    }
}
