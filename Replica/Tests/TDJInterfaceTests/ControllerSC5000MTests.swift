import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withSC5000M(
    name: String = "SC5000M PRIME", _ body: (ControllerMIDIConnection, UserDefaults) throws -> Void
) throws {
    let suite = "sc5000m-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences)
    input.sources = [
        .init(id: 10, reference: 100, name: "SC5000M", identity: .init(id: 10, device: 1, names: [name])),
        .init(id: 11, reference: 101, name: "SC5000M", identity: .init(id: 11, device: 2, names: [name])),
    ]
    let profile = try #require(ControllerFactoryProfile.matching([name]))
    #expect(!profile.selectsAutomatically)
    #expect(profile.definition?.startup.isEmpty == true && profile.definition?.outputs.isEmpty == true)
    #expect(profile.definition?.shutdown.isEmpty == true && profile.definition?.audioOutput == nil)
    for source: Int32 in [10, 11] {
        input.select(source)
        input.applyFactoryProfile(profile)
        #expect(input.isInputActive(source))
    }
    try body(input, preferences)
}

@MainActor private func sc5000Packet(_ bytes: [UInt8], to input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source)
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueSC5000MManualTransportRoutesEveryNormalAddressThroughNativeLayers() throws {
    try withSC5000M { input, _ in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
        for deck in DeckID.primary {
            if deck == .b { sc5000Packet([0x90, 11, 127, 11, 0], to: input) }
            for (number, action): (UInt8, ControllerAction) in [
                (1, .playA), (2, .cuePreviewA), (20, .syncA), (22, .keylockA), (24, .pitchBendDownA),
                (25, .pitchBendUpA), (3, .jumpBackA), (4, .jumpForwardA), (18, .loadA),
                (8, .loopInA), (9, .loopOutOrExitA), (10, .loopA),
            ] {
                events.removeAll()
                sc5000Packet([0x90, number, 127, 0x80, number, 127], to: input)
                #expect(events.count == (action.isMomentary ? 2 : 1))
                #expect(events.allSatisfy { $0.0 == .init(action.assigned(to: deck), deck: deck) })
            }
            events.removeAll()
            sc5000Packet([0xB0, 3, 1, 6, 127], to: input)
            #expect(events.contains { $0.0 == .init(ControllerAction.loopSizeA.assigned(to: deck), deck: deck) })
            #expect(events.contains { $0.0.action == .browse })
        }
    }
}

@Test @MainActor func controllerCatalogueSC5000MManualPadModesAndShiftReleaseAliasesKeepEveryPadSafe() throws {
    try withSC5000M { input, _ in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in if !target.action.isJog { events.append(target) } }
        for deck in DeckID.primary {
            if deck == .b { sc5000Packet([0x90, 11, 127, 11, 0], to: input) }
            for slot: UInt8 in 0..<8 {
                events.removeAll()
                sc5000Packet([0x90, 32 + slot, 127, 32 + slot, 0], to: input)
                #expect(events.count == 1 && events.first?.action.hotcueSlot == Int(slot) && events.first?.deck == deck)
            }
            for mode: UInt8 in [28, 29] {
                sc5000Packet([0x90, mode, 127, mode, 0], to: input)
                events.removeAll()
                for note: UInt8 in 32...39 { sc5000Packet([0x90, note, 127, note, 0], to: input) }
                #expect(events.isEmpty)
            }
            sc5000Packet([0x90, 30, 127, 30, 0], to: input)
            for (slot, beats) in [0.0625, 0.125, 0.25, 0.5, 1, 2, 4, 8].enumerated() {
                events.removeAll()
                sc5000Packet([0x90, 32 + UInt8(slot), 127, 32 + UInt8(slot), 0], to: input)
                #expect(
                    events == [.init(ControllerAction.toggleFixedLoopA.assigned(to: deck), deck: deck, argument: beats)]
                )
            }
            sc5000Packet([0x90, 27, 127, 27, 0, 1, 127, 26, 127, 1, 0, 26, 0], to: input)
            events.removeAll()
            sc5000Packet([0x90, 1, 127, 1, 0], to: input)
            #expect(events == [.init(ControllerAction.playA.assigned(to: deck), deck: deck)])
        }
    }
}

@Test @MainActor func controllerCatalogueSC5000MBoundariesReleaseOnlyOwnedCueAndPreserveSharedShift() throws {
    try withSC5000M { input, _ in
        var cueValues: [(DeckID?, Double)] = []
        input.onTargetAction = { target, value in
            if target.action == .cuePreviewA || target.action == .cuePreviewB { cueValues.append((target.deck, value)) }
        }
        sc5000Packet([0x90, 2, 127], to: input)
        sc5000Packet([0x90, 2, 127], to: input, source: 11)
        sc5000Packet([0x90, 11, 127, 11, 0], to: input)
        #expect(cueValues.map(\.1) == [1])
        sc5000Packet([0x80, 2, 127], to: input, source: 11)
        #expect(cueValues.map(\.1) == [1, 0])
        sc5000Packet([0x80, 2, 127], to: input)
        sc5000Packet([0x90, 2, 127, 28, 127, 28, 0], to: input)
        #expect(cueValues.map(\.1) == [1, 0, 1, 0])
        #expect(cueValues.suffix(2).allSatisfy { $0.0 == .b })
        sc5000Packet([0x90, 26, 127, 11, 127, 11, 0, 2, 127], to: input)
        #expect(cueValues.count == 4)
        sc5000Packet([0x80, 26, 127, 2, 0, 0x90, 2, 127, 2, 0], to: input)
        #expect(cueValues.map(\.1) == [1, 0, 1, 0, 1, 0])
    }
}

@Test @MainActor func controllerCatalogueSC5000MManualProtocolRestoresWithoutModesAndRejectsMotorNoiseAndOverload()
    throws
{
    try withSC5000M { input, preferences in
        sc5000Packet([0x90, 11, 127, 11, 0, 30, 127, 30, 0, 26, 127], to: input)
        let restored = ControllerMIDIConnection(preferences: preferences)
        restored.sources = input.sources
        restored.select(10)
        var events: [ControllerActionTarget] = []
        restored.onTargetAction = { target, _ in if !target.action.isJog { events.append(target) } }
        sc5000Packet([0x90, 32, 127, 32, 0], to: restored)
        #expect(events == [.init(.hotcue1A, deck: .a)])
        events.removeAll()
        sc5000Packet(
            [
                0xB0, 17, 64, 49, 127, 54, 1, 55, 0, 8, 64, 40, 127, 64, 127, 65, 0, 66, 0, 0xE0, 127, 127, 0x90, 40,
                127, 56, 127, 5, 127, 6, 127,
            ], to: restored)
        #expect(events.isEmpty)
        #expect(restored.receiveBytes([0x90, 1, 127], source: 10, limit: 0) == nil)
        #expect(!restored.enabled && restored.sources.isEmpty && restored.destinations.isEmpty)
        #expect(restored.status == "Controller input overload. Reconnect to continue.")
    }
}

@Test @MainActor func controllerCataloguePrimePlayersKeepEveryIndependentNormalAddressAndIgnoreDifferentHardware()
    throws
{
    for name in ["SC6000 PRIME", "SC6000M PRIME", "SC5000 PRIME"] {
        try withSC5000M(name: name) { input, _ in
            var events: [(ControllerActionTarget, Double)] = []
            input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
            for deck in DeckID.primary {
                if deck == .b { sc5000Packet([0x90, 11, 127, 11, 127, 11, 0], to: input) }
                for (number, action): (UInt8, ControllerAction) in [
                    (1, .playA), (2, .cuePreviewA), (20, .syncA), (22, .keylockA), (24, .pitchBendDownA),
                    (25, .pitchBendUpA), (3, .jumpBackA), (4, .jumpForwardA), (18, .loadA),
                    (8, .loopInA), (9, .loopOutOrExitA), (10, .loopA),
                ] {
                    events.removeAll()
                    sc5000Packet([0x90, number, 127, 0x80, number, 127], to: input)
                    #expect(events.count == (action.isMomentary ? 2 : 1))
                    #expect(events.allSatisfy { $0.0 == .init(action.assigned(to: deck), deck: deck) })
                }
                events.removeAll()
                sc5000Packet([0xB0, 3, 1, 6, 127], to: input)
                #expect(events.contains { $0.0 == .init(ControllerAction.loopSizeA.assigned(to: deck), deck: deck) })
                #expect(events.contains { $0.0.action == .browse })
                for slot: UInt8 in 0..<8 {
                    events.removeAll()
                    sc5000Packet([0x90, 32 + slot, 127, 32 + slot, 0], to: input)
                    #expect(
                        events.count == 1 && events.first?.0.action.hotcueSlot == Int(slot)
                            && events.first?.0.deck == deck)
                }
                for mode: UInt8 in [28, 29, 30] {
                    sc5000Packet([0x90, mode, 127, mode, 0], to: input)
                    events.removeAll()
                    for note: UInt8 in 32...39 { sc5000Packet([0x90, note, 127, note, 0], to: input) }
                    #expect(events.isEmpty)
                }
                sc5000Packet([0x90, 27, 127, 27, 0], to: input)
                events.removeAll()
                sc5000Packet(
                    [
                        0xB0, 17, 64, 49, 127, 54, 1, 55, 0, 8, 64, 40, 127, 0xE0, 127, 127,
                        0x90, 40, 127, 19, 127, 52, 127, 53, 127, 5, 127, 6, 127,
                    ], to: input)
                #expect(events.isEmpty)
                sc5000Packet([0x90, 26, 127, 1, 127, 1, 0, 26, 0], to: input)
                #expect(events.isEmpty)
            }
        }
    }
}

@Test @MainActor func controllerCataloguePrimePlayerManualProtocolPersistsWithoutTransientStateOrSiblingMatch() throws {
    for name in ["SC6000 PRIME", "SC6000M PRIME", "SC5000 PRIME"] {
        try withSC5000M(name: name) { input, preferences in
            let profile = try #require(ControllerFactoryProfile.matching([name]))
            #expect(profile.definition?.inputProtocol == .denonPrimePlayer && profile.definition?.inputs.count == 79)
            for other in ["SC6000 PRIME", "SC6000M PRIME", "SC5000 PRIME", "SC5000M PRIME", "LC6000 PRIME"]
            where other != name {
                #expect(ControllerFactoryProfile.matching([other]) != profile)
            }
            sc5000Packet([0x90, 11, 127, 11, 0, 28, 127, 28, 0, 26, 127], to: input)
            let restored = ControllerMIDIConnection(preferences: preferences)
            restored.sources = input.sources
            restored.select(10)
            var actions: [ControllerActionTarget] = []
            restored.onTargetAction = { target, _ in if !target.action.isJog { actions.append(target) } }
            sc5000Packet([0x90, 32, 127, 32, 0], to: restored)
            #expect(actions == [.init(.hotcue1A, deck: .a)])
            sc5000Packet([0x90, 2, 127, 11, 127, 11, 0], to: restored)
            #expect(actions.suffix(2) == [.init(.cuePreviewA, deck: .a), .init(.cuePreviewA, deck: .a)])
        }
    }
}
