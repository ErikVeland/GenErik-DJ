import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withP1Nano(
    decks: [DeckID] = DeckID.allCases, _ body: (ControllerMIDIConnection, UserDefaults) throws -> Void
) rethrows {
    let suite = "p1-nano-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences, factoryPacketSender: { _, _ in true }, deckAvailability: { decks })
    input.sources = [
        .init(
            id: 10, reference: 100, name: "P1-Nano MIDI 1",
            identity: .init(id: 10, device: 1, names: ["P1-Nano MIDI 1"])),
        .init(id: 11, reference: 101, name: "Other MIDI", identity: .init(id: 11, device: 2, names: ["Other MIDI"])),
    ]
    input.reconcileFactoryProfiles()
    #expect(!input.isInputActive(10))
    input.select(10)
    if let profile = ControllerFactoryProfile.matching(["Icon P1-Nano MIDI 1"]) {
        input.applyFactoryProfile(profile)
        #expect(input.isInputActive(10))
    } else {
        Issue.record("Missing manual P1-Nano profile")
    }
    try body(input, preferences)
}

@MainActor private func p1Packet(_ bytes: [UInt8], source: Int32 = 10, to input: ControllerMIDIConnection) {
    input.receiveBytes(bytes, source: source)
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueP1NanoRoutesSelectedTransportAndFourDeckOptIn() {
    for decks in [DeckID.primary, DeckID.allCases] {
        withP1Nano(decks: decks) { input, _ in
            var events: [(ControllerActionTarget, Double)] = []
            input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
            for (index, deck) in DeckID.allCases.enumerated() {
                p1Packet([0x90, 24 + UInt8(index), 127], to: input)
                for (number, action): (UInt8, ControllerAction) in [
                    (94, .playA), (93, .cuePreviewA), (91, .jumpBackA), (92, .jumpForwardA), (86, .loopA),
                ] {
                    events.removeAll()
                    p1Packet([0x90, number, 127, 0x80, number, 127], to: input)
                    let count = decks.contains(deck) ? (action.isMomentary ? 2 : 1) : 0
                    #expect(
                        events.map(\.0) == Array(repeating: .init(action.assigned(to: deck), deck: deck), count: count))
                }
            }
        }
    }
}

@Test @MainActor func controllerCatalogueP1NanoRetainsAllKnobParametersAndExactCountedSteps() {
    withP1Nano { input, _ in
        input.currentTargetValue = { _ in 0.5 }
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
        for (index, deck) in DeckID.allCases.enumerated() {
            for action in [ControllerAction.gainA, .highA, .midA, .lowA, .filterKnobA] {
                events.removeAll()
                p1Packet([0xB0, 16 + UInt8(index), 3], to: input)
                #expect(events.last?.0 == .init(action.assigned(to: deck), deck: deck))
                #expect(abs((events.last?.1 ?? 0) - 0.53) < 0.00001)
                p1Packet([0xB0, 16 + UInt8(index), 66], to: input)
                #expect(abs((events.last?.1 ?? 0) - 0.48) < 0.00001)
                p1Packet([0x90, 50, 127, 50, 0, 0xB0, 16 + UInt8(index), 1, 0x90, 50, 127, 50, 0], to: input)
            }
        }
    }
}

@Test @MainActor func controllerCatalogueP1NanoPreservesFullNormalAndFlipFadersWithoutMasterGuessing() {
    withP1Nano { input, _ in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
        for flip in [false, true] {
            if flip { p1Packet([0x90, 50, 127, 50, 0], to: input) }
            for (index, deck) in DeckID.allCases.enumerated() {
                events.removeAll()
                for (lsb, msb): (UInt8, UInt8) in [(0, 0), (0, 64), (1, 64), (127, 127)] {
                    p1Packet([0xE0 + UInt8(index), lsb, msb], to: input)
                }
                let expected: [Double] =
                    flip ? [1, 0.5, 0.5 - 1.0 / 16382, 0] : [0, 8192.0 / 16383, 8193.0 / 16383, 1]
                #expect(events.map(\.1).count == expected.count)
                for (actual, expected) in zip(events.map(\.1), expected) { #expect(abs(actual - expected) < 0.00001) }
                #expect(
                    events.allSatisfy {
                        $0.0 == .init((flip ? ControllerAction.tempoA : .levelA).assigned(to: deck), deck: deck)
                    })
            }
        }
        events.removeAll()
        p1Packet([0xE8, 127, 127, 0x90, 95, 127, 0x93, 0, 127], to: input)
        #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueP1NanoDeckAndFlipChangesReleaseOwnedCueButPreserveOtherSources() throws {
    try withP1Nano { input, _ in
        input.select(11)
        input.applyFactoryProfile(try #require(ControllerFactoryProfile.matching(["Icon P1-Nano MIDI 1"])))
        var values: [Double] = []
        input.onAction = { action, value in if action == .cuePreviewA { values.append(value) } }
        p1Packet([0x90, 93, 127], to: input)
        p1Packet([0x90, 93, 127], source: 11, to: input)
        p1Packet([0x90, 26, 127], to: input)
        #expect(values == [1])
        p1Packet([0x80, 93, 127], source: 11, to: input)
        #expect(values == [1, 0])
        p1Packet([0x90, 24, 127, 93, 127, 50, 127], to: input)
        #expect(values == [1, 0, 1, 0])
    }
}

@Test @MainActor func controllerCatalogueP1NanoRestoresManualProtocolWithoutStaleModeAndStopsExpandedOverload() {
    withP1Nano { input, preferences in
        p1Packet([0x90, 27, 127, 50, 127, 50, 0, 0xB0, 16, 1], to: input)
        let restored = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
        restored.sources = input.sources
        var actions: [ControllerAction] = []
        restored.onAction = { action, _ in if !action.isJog { actions.append(action) } }
        p1Packet([0x90, 94, 127, 94, 0], to: restored)
        #expect(actions == [.playA])
        actions.removeAll()
        #expect(restored.receiveBytes([0x90, 27, 127, 94, 127], source: 10, limit: 1) == nil)
        #expect(actions.isEmpty && restored.status.contains("overload"))
    }
}

@Test func controllerCatalogueP1NanoEncoderMetadataRequiresItsReviewedProtocolAndTargets() throws {
    func valid(protocolName: String = "p1Nano", number: Int = 16, action: String = "gainA", kind: String = "control")
        throws -> Bool
    {
        let data = Data(
            """
            {"id":"p1-test","aliases":["p1-test"],"inputs":[
            {"action":"\(action)","kind":"\(kind)","channel":0,"number":\(number),"encoding":"p1NanoEncoder","inverted":false}
            ],"outputs":[],"startup":[],"shutdown":[],"autoSelect":false,"scope":"test","source":"test","inputProtocol":"\(protocolName)"}
            """.utf8)
        return try JSONDecoder().decode(ControllerProfileData.self, from: data).isValid
    }
    #expect(try valid())
    #expect(try !valid(protocolName: "cdj101"))
    #expect(try !valid(number: 15))
    #expect(try !valid(action: "playA"))
    #expect(try !valid(kind: "note"))
}
