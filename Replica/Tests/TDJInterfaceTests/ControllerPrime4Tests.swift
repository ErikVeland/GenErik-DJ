import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withPrime4(
    _ name: String = "PRIME 4", _ body: (ControllerMIDIConnection, UserDefaults) throws -> Void
) throws {
    let suite = "prime4-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, deckAvailability: { DeckID.allCases })
    input.sources = [10, 11].map {
        .init(
            id: $0, reference: UInt32($0 + 100), name: name, identity: .init(id: $0, device: UInt32($0), names: [name]))
    }
    let profile = try #require(ControllerFactoryProfile.matching([name]))
    #expect(!profile.selectsAutomatically && profile.definition?.inputProtocol == .denonPrime4)
    input.select(10)
    input.applyFactoryProfile(profile)
    input.select(11)
    input.applyFactoryProfile(try #require(ControllerFactoryProfile.matching(["SC5000M PRIME"])))
    try body(input, preferences)
}

@MainActor private func prime4Packet(_ bytes: [UInt8], to input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source)
    input.flushPendingActions()
}

@Test @MainActor func controllerCataloguePrime4NormalButtonsLoadAndAllHotcuesRouteEveryDeck() throws {
    for name in ["PRIME 4", "PRIME 4+"] {
        try withPrime4(name) { input, _ in
            var events: [(ControllerActionTarget, Double)] = []
            input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
            for (index, deck) in DeckID.allCases.enumerated() {
                let side = UInt8(index % 2)
                prime4Packet([0x9F, 28 + UInt8(index), 127, 28 + UInt8(index), 0], to: input)
                for (number, action): (UInt8, ControllerAction) in [
                    (10, .playA), (9, .cuePreviewA), (8, .syncA), (34, .keylockA), (29, .pitchBendDownA),
                    (30, .pitchBendUpA), (37, .loopInA), (38, .loopOutA), (126, .loadA),
                ] {
                    events.removeAll()
                    let raw = number == 126 ? 1 + side : number
                    let channel: UInt8 = number == 126 ? 15 : 4 + side
                    prime4Packet([0x90 + channel, raw, 127, 0x80 + channel, raw, 127], to: input)
                    #expect(events.count == (action.isMomentary ? 2 : 1))
                    #expect(events.allSatisfy { $0.0 == .init(action.assigned(to: deck), deck: deck) })
                }
                for slot: UInt8 in 0..<8 {
                    events.removeAll()
                    prime4Packet([0x94 + side, 15 + slot, 127, 15 + slot, 0], to: input)
                    #expect(
                        events.count == 1 && events.first?.0.action.hotcueSlot == Int(slot)
                            && events.first?.0.deck == deck)
                }
                events.removeAll()
                prime4Packet([0xB4 + side, 32, 1], to: input)
                prime4Packet([0xB4 + side, 32, 127], to: input)
                #expect(events.map { Int((($0.1 - 0.5) * 126).rounded()) } == [1, -1])
                #expect(
                    events.allSatisfy {
                        $0.0.deck == deck && $0.0.action == ControllerAction.loopSizeA.assigned(to: deck)
                    })
            }
        }
    }
}

@Test @MainActor func controllerCataloguePrime4DeckModesAndShiftReleaseOnlyOwnedContacts() throws {
    try withPrime4 { input, _ in
        var cue: [Double] = []
        var actions: [ControllerAction] = []
        input.onTargetAction = { target, value in
            if target.action == .cuePreviewA { cue.append(value) }
            if !target.action.isJog { actions.append(target.action) }
        }
        prime4Packet([0x94, 9, 127], to: input)
        prime4Packet([0x90, 2, 127], to: input, source: 11)
        prime4Packet([0x9F, 30, 127, 30, 0], to: input)
        #expect(cue == [1])
        prime4Packet([0x80, 2, 127], to: input, source: 11)
        #expect(cue == [1, 0])
        prime4Packet([0x84, 9, 127, 0x9F, 28, 127, 28, 0, 0x94, 28, 127, 12, 127, 12, 0], to: input)
        actions.removeAll()
        prime4Packet([0x94, 10, 127, 10, 0, 15, 127, 15, 0], to: input)
        #expect(actions.isEmpty)
        prime4Packet([0x95, 28, 0, 0x94, 11, 127, 11, 0], to: input)
        actions.removeAll()
        prime4Packet([0x94, 10, 127, 10, 0, 15, 127, 15, 0], to: input)
        #expect(actions == [.playA, .hotcue1A])
        prime4Packet([0x94, 9, 127, 12, 127, 12, 0], to: input)
        #expect(cue.suffix(2) == [1, 0])
    }
}

@Test @MainActor func controllerCataloguePrime4PitchPairingInvertsAndResetsPickupAtDeckBoundary() throws {
    try withPrime4 { input, _ in
        input.currentTargetValue = { _ in 0.5 }
        var values: [(DeckID?, Double)] = []
        input.onTargetAction = { target, value in if target.action == .tempoA { values.append((target.deck, value)) } }
        prime4Packet([0xB4, 75, 0, 31, 64], to: input)
        prime4Packet([0xB4, 75, 0, 31, 0], to: input)
        #expect(values.last?.1 == 1 && values.last?.0 == .a)
        prime4Packet([0x9F, 30, 127, 30, 0], to: input)
        values.removeAll()
        prime4Packet([0xB4, 31, 127], to: input)
        #expect(values.isEmpty)
        prime4Packet([0xB4, 75, 0, 31, 64], to: input)
        prime4Packet([0xB4, 31, 127, 75, 127], to: input)
        #expect(values.last?.1 == 0 && values.last?.0 == .c)
    }
}

@Test @MainActor func controllerCataloguePrime4ManualProtocolPersistsWithoutTransientDeckOrPadMode() throws {
    try withPrime4 { input, preferences in
        prime4Packet([0x9F, 30, 127, 30, 0, 0x94, 12, 127, 12, 0, 28, 127], to: input)
        let restored = ControllerMIDIConnection(preferences: preferences)
        restored.sources = input.sources
        restored.select(10)
        var actions: [ControllerActionTarget] = []
        restored.onTargetAction = { target, _ in if !target.action.isJog { actions.append(target) } }
        prime4Packet([0x94, 15, 127, 15, 0], to: restored)
        #expect(actions == [.init(.hotcue1A, deck: .a)])
        #expect(restored.receiveBytes([0x94, 10, 127], source: 10, limit: 0) == nil)
        #expect(!restored.enabled && restored.sources.isEmpty)
        for name in ["PRIME 2", "PRIME GO", "SC LIVE 4", "PRIME 4 G2"] {
            #expect(ControllerFactoryProfile.matching([name])?.definition?.inputProtocol != .denonPrime4)
        }
        #expect(ControllerFactoryProfile.matching(["PRIME 4"]) != ControllerFactoryProfile.matching(["PRIME 4+"]))
    }
}

@Test @MainActor func controllerCataloguePrime4RejectsOversizedManualReplacementWithoutLosingSavedMappings() throws {
    try withPrime4 { input, preferences in
        #expect(input.bindingCount == 244)
        input.select(11)
        input.applyFactoryProfile(try #require(ControllerFactoryProfile.matching(["PRIME 4"])))
        #expect(input.bindingCount == 244)
        #expect(input.status == "The controller mapping is full. Remove a mapping before applying this profile.")
        let restored = ControllerMIDIConnection(preferences: preferences)
        #expect(restored.bindingCount == 244)
        restored.sources = input.sources
        var actions: [ControllerActionTarget] = []
        restored.onTargetAction = { target, value in
            if target.action == .cuePreviewA && value > 0 { actions.append(target) }
        }
        prime4Packet([0x90, 2, 127], to: restored, source: 11)
        #expect(actions == [.init(.cuePreviewA, deck: .a)])
    }
}
