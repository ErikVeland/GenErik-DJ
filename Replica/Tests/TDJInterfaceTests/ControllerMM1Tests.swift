import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withMM1(
    decks: [DeckID] = DeckID.allCases, _ body: (ControllerMIDIConnection) throws -> Void
) rethrows {
    let suite = "mm1-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences, factoryPacketSender: { _, _ in true }, deckAvailability: { decks })
    input.sources = [
        .init(id: 10, reference: 100, name: "CMD MM-1", identity: .init(id: 10, device: 1, names: ["CMD MM-1"]))
    ]
    input.reconcileFactoryProfiles()
    #expect(input.isInputActive(10))
    try body(input)
}

@MainActor private func mm1Packet(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueMM1MatchesItsOwnNamedPortWithoutSiblingOrOutputAssumptions() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["CMD MM-1"], automaticOnly: true))
    #expect(!profile.hasAutomaticSplitOutput)
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 496 && data.outputs.isEmpty && data.startup.isEmpty && data.shutdown.isEmpty)
    #expect(Set(data.inputs.map(\.channel)) == Set((0..<16).map { UInt8($0) }))
    #expect(data.inputs.allSatisfy { $0.anyChannel != true })
    for name in ["CMD", "CMD DC-1", "CMD DV-1", "CMD STUDIO 4a", "USB MIDI"] {
        #expect(ControllerFactoryProfile.matching([name], automaticOnly: true) != profile)
    }
}

@Test @MainActor func controllerCatalogueMM1AcceptsAllConfiguredChannelsWithCABDStripOrderAndCDOptIn() {
    let order: [DeckID] = [.c, .a, .b, .d]
    for decks in [DeckID.primary, DeckID.allCases] {
        withMM1(decks: decks) { input in
            var events: [(ControllerActionTarget, Double)] = []
            input.onTargetAction = { events.append(($0, $1)) }
            for channel: UInt8 in 0..<16 {
                events.removeAll()
                for strip: UInt8 in 0..<4 {
                    mm1Packet([0xB0 + channel, 6 + strip, 127], to: input)
                    mm1Packet([0xB0 + channel, 48 + strip, 0], to: input)
                    mm1Packet([0x90 + channel, 48 + strip, 127, 48 + strip, 0], to: input)
                }
                let active = order.filter { decks.contains($0) }
                #expect(events.map { $0.0.deck } == active.flatMap { Array(repeating: Optional($0), count: 3) })
                #expect(events.map(\.1) == active.flatMap { _ in [1.0, 0, 1] })
                let expected: [ControllerActionTarget] = active.flatMap { deck -> [ControllerActionTarget] in
                    let a = deck == .a || deck == .c
                    return [
                        .init(a ? .highA : .highB, deck: deck), .init(a ? .levelA : .levelB, deck: deck),
                        .init(a ? .cueA : .cueB, deck: deck),
                    ]
                }
                #expect(events.map { $0.0 } == expected)
            }
        }
    }
}

@Test @MainActor func controllerCatalogueMM1KeepsAllDefaultKnobRowsSeparateFromGainAndMIDIButtons() {
    withMM1 { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        let order: [DeckID] = [.c, .a, .b, .d]
        for (strip, deck) in order.enumerated() {
            events.removeAll()
            for base: UInt8 in [6, 10, 14, 18] { mm1Packet([0xB4, base + UInt8(strip), 64], to: input) }
            #expect(events.map { $0.0.deck } == Array(repeating: Optional(deck), count: 4))
            let a = deck == .a || deck == .c
            #expect(
                events.map { $0.0.action }
                    == (a ? [.highA, .midA, .lowA, .filterKnobA] : [.highB, .midB, .lowB, .filterKnobB]))
            #expect(events.allSatisfy { $0.1 == 64.0 / 127 })
        }
        events.removeAll()
        mm1Packet([0x94, 3, 127, 18, 127, 19, 127, 20, 127, 6, 127, 0xB4, 1, 127, 22, 127], to: input)
        #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueMM1BothModifiersKeepIndependentOwnershipAndCannotLoadOrSync() {
    withMM1 { input in
        var events: [ControllerAction] = []
        input.onAction = { action, _ in events.append(action) }
        mm1Packet([0x94, 16, 127, 17, 127, 16, 0], to: input)
        mm1Packet([0x94, 49, 127, 49, 0, 0xB4, 7, 127, 49, 127, 3, 65], to: input)
        #expect(events.isEmpty)
        mm1Packet([0x84, 17, 127, 0x94, 49, 127], to: input)
        #expect(events == [.cueA])
        events.removeAll()
        mm1Packet([0x94, 16, 127, 17, 127, 17, 0, 49, 0, 49, 127], to: input)
        #expect(events.isEmpty)
        mm1Packet([0x94, 16, 0, 49, 0, 49, 127], to: input)
        #expect(events == [.cueA])
    }
}

@Test @MainActor func controllerCatalogueMM1KeepsGlobalLevelsAndExactSignedBrowserCounts() {
    withMM1 { input in
        var events: [(ControllerAction, Double)] = []
        input.onAction = { events.append(($0, $1)) }
        for (number, action) in [(UInt8(2), ControllerAction.master), (4, .monitor), (5, .cueMix), (64, .crossfader)] {
            events.removeAll()
            mm1Packet([0xB4, number, 127], to: input)
            #expect(events.count == 1 && events.first?.0 == action && events.first?.1 == 1)
        }
        for raw: UInt8 in [0, 63, 64, 65, 127] {
            events.removeAll()
            mm1Packet([0xB4, 3, raw], to: input)
            #expect(events.allSatisfy { $0.0 == .browse })
            #expect(abs(events.reduce(0) { $0 + ($1.1 - 0.5) * 126 } - Double(Int(raw) - 64)) < 0.000001)
        }
    }
}
