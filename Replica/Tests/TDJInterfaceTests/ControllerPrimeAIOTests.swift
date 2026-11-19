import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withPrimeAIO(_ name: String, _ body: (ControllerMIDIConnection) throws -> Void) throws {
    let suite = "prime-aio-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences)
    input.sources = [
        .init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name])),
        .init(id: 11, reference: 101, name: name, identity: .init(id: 11, device: 2, names: [name])),
    ]
    let profile = try #require(ControllerFactoryProfile.matching([name]))
    #expect(profile.selectsAutomatically == (name == "PRIME GO"))
    input.reconcileFactoryProfiles()
    if name == "PRIME 2" {
        #expect(!input.isInputActive(10))
        for source: Int32 in [10, 11] { input.select(source); input.applyFactoryProfile(profile) }
    }
    #expect(input.isInputActive(10) && input.isInputActive(11))
    try body(input)
}

@MainActor private func primeAIOPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source)
    input.flushPendingActions()
}

@Test @MainActor func controllerCataloguePrimeAIONormalTransportAndIndependentLoopContractsKeepExactAddresses() throws {
    for name in ["PRIME GO", "PRIME 2"] {
        try withPrimeAIO(name) { input in
            var events: [(ControllerActionTarget, Double)] = []
            input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
            for (index, deck) in DeckID.primary.enumerated() {
                var controls: [(UInt8, ControllerAction)] = [
                    (10, .playA), (9, .cuePreviewA), (8, .syncA), (29, .pitchBendDownA), (30, .pitchBendUpA),
                ]
                controls += name == "PRIME GO" ? [(39, .loopA)] : [(34, .keylockA), (37, .loopInA), (38, .loopOutA)]
                for (number, action) in controls {
                    events.removeAll()
                    primeAIOPacket([0x92 + UInt8(index), number, 127, 0x82 + UInt8(index), number, 127], to: input)
                    #expect(events.count == (action.isMomentary ? 2 : 1))
                    #expect(events.allSatisfy { $0.0 == .init(action.assigned(to: deck), deck: deck) })
                }
                events.removeAll()
                primeAIOPacket([0x9F, UInt8(index) + 1, 127, UInt8(index) + 1, 0], to: input)
                #expect(events.map { $0.0 } == [.init(ControllerAction.loadA.assigned(to: deck), deck: deck)])
                events.removeAll()
                primeAIOPacket([0xB2 + UInt8(index), 32, 1, 32, 127], to: input)
                #expect(events.map { Int((($0.1 - 0.5) * 126).rounded()) } == [1, -1])
                #expect(events.allSatisfy { $0.0 == .init(ControllerAction.loopSizeA.assigned(to: deck), deck: deck) })
            }
        }
    }
}

@Test @MainActor func controllerCataloguePrimeAIOFixedMixerPFLAndGlobalsKeepNoteCCAndDeckOwnership() throws {
    for name in ["PRIME GO", "PRIME 2"] {
        try withPrimeAIO(name) { input in
            input.currentTargetValue = { _ in 0.5 }
            var events: [(ControllerActionTarget, Double)] = []
            input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
            for (index, deck) in DeckID.primary.enumerated() {
                for (number, action): (UInt8, ControllerAction) in [
                    (3, .gainA), (4, .highA), (6, .midA), (8, .lowA), (14, .levelA),
                ] {
                    events.removeAll()
                    primeAIOPacket([0xB0 + UInt8(index), number, 64], to: input)
                    primeAIOPacket([0xB0 + UInt8(index), number, 127], to: input)
                    #expect(events.map(\.1) == [64.0 / 127, 1])
                    #expect(events.allSatisfy { $0.0 == .init(action.assigned(to: deck), deck: deck) })
                }
                events.removeAll()
                primeAIOPacket([0x90 + UInt8(index), 13, 127, 13, 0], to: input)
                #expect(events.map { $0.0 } == [.init(ControllerAction.cueA.assigned(to: deck), deck: deck)])
            }
            for (number, action): (UInt8, ControllerAction) in [(12, .cueMix), (13, .monitor), (14, .crossfader)] {
                events.removeAll()
                primeAIOPacket([0xBF, number, 64], to: input)
                primeAIOPacket([0xBF, number, 0], to: input)
                #expect(events.map(\.1) == [64.0 / 127, 0])
                #expect(events.allSatisfy { $0.0.action == action })
            }
        }
    }
}

@Test @MainActor func controllerCataloguePrimeGOPairedTempoAndOwnerBrowserDoNotCopyToPrime2() throws {
    try withPrimeAIO("PRIME GO") { input in
        input.currentTargetValue = { _ in 0.5 }
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
        for (index, deck) in DeckID.primary.enumerated() {
            events.removeAll()
            let status = UInt8(index) + 0xB2
            primeAIOPacket([status, 75, 127], to: input)
            #expect(events.isEmpty)
            primeAIOPacket([status, 31, 64, 75, 0], to: input)
            primeAIOPacket([status, 31, 0, 75, 0], to: input)
            #expect(events.last?.1 == 1 && events.last?.0.deck == deck)
            primeAIOPacket([status, 31, 127, 75, 127], to: input)
            #expect(events.last?.1 == 0 && events.last?.0.deck == deck)
        }
        events.removeAll()
        primeAIOPacket([0xBF, 5, 1], to: input)
        #expect(events.last?.0.action == .browse && events.last?.1 == 0.5 - 1.0 / 126)
        primeAIOPacket([0xBF, 5, 127], to: input)
        #expect(events.last?.1 == 0.5 + 1.0 / 126)
    }
    try withPrimeAIO("PRIME 2") { input in
        var events: [ControllerAction] = []
        input.onAction = { action, _ in if !action.isJog { events.append(action) } }
        primeAIOPacket([0xB2, 31, 127, 75, 127, 0xBF, 5, 1], to: input)
        #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCataloguePrimeAIOShiftAndSourceBoundariesReleaseCueAndRearmPlay() throws {
    for name in ["PRIME GO", "PRIME 2"] {
        try withPrimeAIO(name) { input in
            let shift: [UInt8] = name == "PRIME GO" ? [0x9F, 8, 127] : [0x92, 28, 127]
            let unshift: [UInt8] = name == "PRIME GO" ? [0x8F, 8, 127] : [0x82, 28, 127]
            var values: [Double] = []
            var events: [ControllerAction] = []
            input.onAction = { action, value in
                if action == .cuePreviewA { values.append(value) }
                if !action.isJog { events.append(action) }
            }
            primeAIOPacket([0x92, 9, 127], to: input)
            primeAIOPacket([0x92, 9, 127], to: input, source: 11)
            primeAIOPacket(shift + [0x82, 9, 127], to: input)
            #expect(values == [1])
            primeAIOPacket([0x82, 9, 127], to: input, source: 11)
            #expect(values == [1, 0])
            primeAIOPacket([0x92, 10, 127, 10, 0], to: input)
            events.removeAll()
            primeAIOPacket(unshift + [0x92, 10, 127, 10, 0], to: input)
            #expect(events == [.playA])
            if name == "PRIME 2" {
                primeAIOPacket([0x92, 28, 127, 0x93, 28, 127, 0x82, 28, 127], to: input)
                events.removeAll()
                primeAIOPacket([0x92, 10, 127, 10, 0], to: input)
                #expect(events.isEmpty)
                primeAIOPacket([0x83, 28, 127, 0x92, 10, 127, 10, 0], to: input)
                #expect(events == [.playA])
            }
        }
    }
}

@Test @MainActor func controllerCataloguePrimeAIOUnqualifiedPadsJogScreensAndSiblingModelsStayInactive() throws {
    for name in ["PRIME GO", "PRIME 2"] {
        try withPrimeAIO(name) { input in
            var events: [ControllerAction] = []
            input.onAction = { action, _ in if !action.isJog { events.append(action) } }
            for channel: UInt8 in 2...3 {
                for number: UInt8 in Array(11...27) + [33, 35, 36, 40, 43] {
                    primeAIOPacket([0x90 + channel, number, 127, number, 0], to: input)
                }
                primeAIOPacket([0xB0 + channel, 55, 64, 77, 127, 37, 127, 0xE0 + channel, 127, 127], to: input)
            }
            primeAIOPacket(
                [0xBF, 20, 127, 0xB0, 11, 127, 0x90, 14, 127, 15, 127, 0x94, 10, 127, 0x9F, 6, 127, 7, 127], to: input)
            #expect(events.isEmpty)
        }
        let profile = try #require(ControllerFactoryProfile.matching([name]))
        #expect(profile.definition?.outputs.isEmpty == true && profile.definition?.startup.isEmpty == true)
        #expect(profile.definition?.shutdown.isEmpty == true && profile.definition?.audioOutput == nil)
        for other in ["PRIME GO+", "PRIME 4", "PRIME 4+", "SC LIVE 2", "SC LIVE 4"] {
            #expect(ControllerFactoryProfile.matching([other]) != profile)
        }
    }
}
