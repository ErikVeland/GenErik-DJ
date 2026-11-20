import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withCMX(decks: [DeckID] = DeckID.allCases, _ body: (ControllerMIDIConnection) throws -> Void)
    throws
{
    let suite = "cmx-\(UUID().uuidString)"; let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { _, _ in
            Issue.record("Manual CMX input must not configure hardware."); return false
        }, deckAvailability: { decks }, factoryInputConnector: { _ in true })
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id), name: "CMX-2000",
            identity: .init(id: id, device: UInt32(id), names: ["CMX-2000"]))
    }
    input.reconcileFactoryProfiles(); #expect(!input.isInputActive(10) && !input.isInputActive(11))
    let p = try #require(ControllerFactoryProfile.matching(["CMX2000"]))
    for source: Int32 in [10, 11] { input.select(source); input.applyFactoryProfile(p) }
    #expect(input.bindingCount == 238 && input.isInputActive(10) && input.isInputActive(11))
    try body(input)
}

@MainActor private func cmxPacket(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source); input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueCMXManualNativeIdentityHasNoSetupOrOutputs() throws {
    let p = try #require(ControllerFactoryProfile.matching(["CMX-2000"])); let d = try #require(p.definition)
    #expect(d.isValid && !p.selectsAutomatically && d.inputs.count == 119 && d.outputs.isEmpty)
    #expect(d.startup.isEmpty && d.shutdown.isEmpty && d.audioOutput == nil)
    #expect(ControllerFactoryProfile.matching(["CMX-2000"], automaticOnly: true) == nil)
    #expect(ControllerFactoryProfile.matching(["DDC-2000"]) != p)
    try withCMX { _ in }
}

@Test @MainActor func controllerCatalogueCMXNormalTransportLoadAndLoopAliasesKeepBothBanks() throws {
    try withCMX { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        for (ch, decks): (UInt8, [DeckID]) in [(0, [.a, .c]), (1, [.b, .d])] {
            for deck in decks {
                for (action, n): (ControllerAction, UInt8) in [
                    (.playA, 38), (.syncA, 35), (.keylockA, 30), (.cueA, 16), (.loopA, 28), (.loopInA, 31),
                    (.loopOutOrExitA, 32), (.loadA, 1 + ch * 2),
                ] {
                    let channel: UInt8 = action == .loadA ? 0 : ch
                    for off: UInt8 in [0x80, 0x90] {
                        events.removeAll(); cmxPacket([0x90 + channel, n + 50, 127, n + 50, 0], input);
                        #expect(events.isEmpty)
                        cmxPacket(
                            [
                                0x90 + channel, n, 127, n, 127, off + channel, n + 50, off == 0x80 ? 127 : 0,
                                0x90 + channel, n, 1, n, 0,
                            ], input)
                        #expect(events == Array(repeating: .init(action.assigned(to: deck), deck: deck), count: 2))
                    }
                }
                cmxPacket([0x90 + ch, 25, 127, 25, 0], input)
            }
        }
    }
}

@Test @MainActor func controllerCatalogueCMXCueAndBendsKeepVelocitiesAndShiftedReleaseForms() throws {
    try withCMX { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        for (ch, decks): (UInt8, [DeckID]) in [(0, [.a, .c]), (1, [.b, .d])] {
            for deck in decks {
                for (action, n): (ControllerAction, UInt8) in [
                    (.cuePreviewA, 37), (.pitchBendDownA, 26), (.pitchBendUpA, 27),
                ] {
                    for velocity: UInt8 in [1, 64, 127] {
                        for off: UInt8 in [0x80, 0x90] {
                            events.removeAll();
                            cmxPacket([0x90 + ch, n, velocity, n, 127, off + ch, n + 50, off == 0x80 ? 127 : 0], input)
                            #expect(
                                events.map(\.1) == [Double(velocity) / 127, 0]
                                    && events.allSatisfy { $0.0 == .init(action.assigned(to: deck), deck: deck) })
                        }
                    }
                }
                cmxPacket([0x90 + ch, 25, 127, 25, 0], input)
            }
        }
    }
}

@Test @MainActor func controllerCatalogueCMXAsymmetricHotCuesAndFixedJumpsKeepUncorroboratedPadsInactive() throws {
    try withCMX { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        for (ch, deck): (UInt8, DeckID) in [(0, .a), (1, .b)] {
            let numbers: [UInt8] = ch == 0 ? [43, 48, 49, 50, 44, 45, 46, 47] : [43, 48, 46, 47, 44, 45]
            for (slot, n) in numbers.enumerated() {
                events.removeAll();
                cmxPacket(
                    [0x90 + ch, n + 50, 127, n + 50, 0, n, 127, n, 127, 0x80 + ch, n + 50, 127, 0x90 + ch, n, 1, n, 0],
                    input)
                #expect(events.count == 2 && events.allSatisfy { $0.deck == deck && $0.action.hotcueSlot == slot })
            }
            for (n, amount): (UInt8, Double) in [(36, -4), (33, 4)] {
                events.removeAll();
                cmxPacket([0x90 + ch, n, 127, n, 127, n + 50, 0, n, 1, n, 0, n + 50, 127, n + 50, 0], input)
                #expect(
                    events
                        == Array(
                            repeating: .init(.fixedJumpA.assigned(to: deck), deck: deck, argument: amount), count: 2))
            }
        }
        events.removeAll(); cmxPacket([0x91, 49, 127, 49, 0, 50, 127, 50, 0, 99, 127, 99, 0, 100, 127, 100, 0], input);
        #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueCMXBankChangesResetOwnedMixerPickupAndShiftLoopSize() throws {
    try withCMX { input in
        input.currentTargetValue = { _ in 0.5 }
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        for (ch, decks): (UInt8, [DeckID]) in [(0, [.a, .c]), (1, [.b, .d])] {
            for deck in decks {
                for shifted in [false, true] {
                    cmxPacket([0x90, 9, shifted ? 127 : 0], input)
                    for (action, n): (ControllerAction, UInt8) in [
                        (.gainA, 14), (.highA, 15), (.midA, 16), (.lowA, 17), (.filterKnobA, 18), (.levelA, 19),
                    ] {
                        let number = n + (shifted ? 40 : 0)
                        events.removeAll(); cmxPacket([0xB0 + ch, number, 0], input); #expect(events.isEmpty)
                        cmxPacket([0xB0 + ch, number, 64], input); cmxPacket([0xB0 + ch, number, 127], input)
                        #expect(
                            events.count == 2
                                && events.allSatisfy { $0.0 == .init(action.assigned(to: deck), deck: deck) }
                                && events.last?.1 == 1)
                    }
                }
                events.removeAll(); cmxPacket([0xB0 + ch, 25, 65, 65, 65], input); #expect(events.isEmpty)
                cmxPacket([0x90, 9, 0, 0xB0 + ch, 25, 64], input); #expect(events.isEmpty)
                cmxPacket([0xB0 + ch, 25, 65], input);
                #expect(events.count == 1 && events[0].0 == .init(.loopSizeA.assigned(to: deck), deck: deck))
                cmxPacket([0x90 + ch, 25, 127, 25, 0], input)
            }
        }
    }
}

@Test @MainActor func controllerCatalogueCMXGlobalMixerAndBrowseRetainOwnAddresses() throws {
    try withCMX { input in
        input.currentTargetValue = { _ in 0.5 }
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        for (action, n): (ControllerAction, UInt8) in [(.master, 5), (.cueMix, 1), (.monitor, 2), (.crossfader, 11)] {
            for number in [n, n + 40] {
                events.removeAll(); cmxPacket([0xB0, number, 0], input); #expect(events.isEmpty)
                cmxPacket([0xB0, number, 64], input); cmxPacket([0xB0, number, 127], input)
                #expect(events.count == 2 && events.allSatisfy { $0.0 == .init(action) } && events.last?.1 == 1)
            }
        }
        for (n, action): (UInt8, ControllerAction) in [(3, .browse), (43, .browseGroups)] {
            events.removeAll(); cmxPacket([0xB0, n, 64], input); #expect(events.isEmpty)
            cmxPacket([0xB0, n, 65], input); cmxPacket([0xB0, n, 63], input)
            #expect(events.map(\.0) == [.init(action), .init(action)] && events[0].1 > 0.5 && events[1].1 < 0.5)
        }
        events.removeAll(); cmxPacket([0x90, 52, 127, 52, 0, 2, 127, 2, 127, 0x80, 52, 127, 0x90, 2, 1, 2, 0], input)
        #expect(events.map(\.0) == [.init(.openGroup), .init(.openGroup)])
    }
}

@Test @MainActor func controllerCatalogueCMXShiftedDeckReleasesRearmWithoutRetargetingOrForeignCleanup() throws {
    try withCMX { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        cmxPacket([0x90, 37, 127, 0x91, 37, 127], input); cmxPacket([0x90, 37, 127], input, source: 11);
        events.removeAll()
        cmxPacket([0x90, 25, 127, 25, 127, 9, 127, 75, 127, 0x80, 75, 127], input); #expect(events.isEmpty)
        cmxPacket([0x90, 9, 0, 38, 127, 38, 0], input); #expect(events.last?.0 == .init(.playA, deck: .c))
        events.removeAll(); cmxPacket([0x90, 25, 127, 75, 0, 38, 127, 38, 0], input);
        #expect(events.map(\.0) == [.init(.playA, deck: .a)])
        events.removeAll(); cmxPacket([0x80, 37, 127], input, source: 11)
        #expect(events.map(\.0) == [.init(.cuePreviewA, deck: .a)] && events.map(\.1) == [0])
        events.removeAll(); cmxPacket([0x91, 25, 127, 25, 0], input)
        #expect(events.map(\.0) == [.init(.cuePreviewB, deck: .b)] && events.map(\.1) == [0])
        cmxPacket([0x90, 38, 127, 38, 0], input, source: 11); #expect(events.last?.0 == .init(.playA, deck: .a))
        cmxPacket([0x90, 25, 64, 38, 127, 38, 0], input); #expect(events.last?.0 == .init(.playA, deck: .a))
    }
}

@Test @MainActor func controllerCatalogueCMXKeepsCDOptInAndReconnectsOnAB() throws {
    try withCMX(decks: [.a, .b]) { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        cmxPacket([0x90, 25, 127, 25, 0, 38, 127, 38, 0, 1, 127, 1, 0, 43, 127, 43, 0, 0xB0, 19, 64], input);
        #expect(events.isEmpty)
        input.setInputActive(10, active: false); input.setInputActive(10, active: true)
        cmxPacket([0x90, 38, 127, 38, 0], input); #expect(events == [.init(.playA, deck: .a)])
    }
}

@Test @MainActor func controllerCatalogueCMXUnsupportedHardwareModesAndForeignGroupsStayInactive() throws {
    try withCMX { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        for ch: UInt8 in 2..<16 { cmxPacket([0x90 + ch, 38, 127, 37, 127, 43, 127, 0xB0 + ch, 19, 64], input) }
        for ch: UInt8 in 0..<2 {
            cmxPacket(
                [
                    0x90 + ch, 12, 127, 15, 127, 17, 127, 18, 127, 19, 127, 20, 127, 21, 127, 22, 127, 23, 127, 24, 127,
                    29, 127, 34, 127, 39, 127, 40, 127, 41, 127, 42, 127, 65, 127, 74, 127, 75, 127, 76, 127, 77, 127,
                    79, 127, 84, 127, 0xB0 + ch, 12, 127, 21, 127, 22, 127, 23, 127, 24, 127, 31, 127, 32, 127, 33, 127,
                    34, 127, 65, 65, 0xE0 + ch, 0, 64,
                ], input)
        }
        cmxPacket(
            [
                0xB0, 4, 127, 6, 127, 7, 127, 8, 65, 13, 127, 26, 127, 44, 127, 46, 127, 47, 127, 48, 65, 53, 127, 66,
                127, 0x90, 4, 127, 5, 127, 6, 127, 7, 127, 8, 127, 13, 127, 14, 127,
            ], input)
        cmxPacket([0x90, 38, 127], input, source: 999)
        input.receive(.init(kind: .note, group: 1, channel: 0, number: 38, value: 127), source: 10);
        input.flushPendingActions()
        #expect(events.isEmpty)
    }
}
