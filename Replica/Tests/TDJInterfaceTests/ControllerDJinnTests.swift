import Foundation
import TDJCore
import Testing

@testable import TDJInterface

private let djinnNames = ["Audiophony DJINN", "Audiophony DJINN (MIDI mode 3)"]

@MainActor private func withDJinn(manual: Bool = false, _ body: (ControllerMIDIConnection) throws -> Void) throws {
    let suite = "djinn-\(UUID().uuidString)"; let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { _, _ in
            Issue.record("DJinn input must not configure hardware."); return false
        }, factoryInputConnector: { _ in true })
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id), name: "DJinn", identity: .init(id: id, device: UInt32(id), names: ["DJinn"]))
    }
    input.reconcileFactoryProfiles(); #expect(input.isInputActive(10) && input.isInputActive(11))
    if manual {
        let p = try #require(ControllerFactoryProfile.matching([djinnNames[1]]))
        for source: Int32 in [10, 11] { input.select(source); input.applyFactoryProfile(p) }
        #expect(input.bindingCount == 180)
    }
    try body(input)
}

@MainActor private func djinnPacket(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source); input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueDJinnOwnIdentitySeparatesCommonPlayersFromManualMode3() throws {
    for (index, name) in djinnNames.enumerated() {
        let p = try #require(ControllerFactoryProfile.matching([name])); let d = try #require(p.definition)
        #expect(p.rawValue == name && d.isValid && d.inputs.count == (index == 0 ? 64 : 90) && d.outputs.count == 14)
        #expect(
            p.selectsAutomatically == (index == 0) && d.startup.isEmpty && d.shutdown.isEmpty && d.audioOutput == nil)
        #expect(ControllerFactoryProfile.matching([name], automaticOnly: true) == (index == 0 ? p : nil))
        for lamp in p.feedback(destination: 20) {
            #expect([0, 2].contains(lamp.channel) && [8, 9, 10, 11, 29, 31, 32].contains(lamp.number))
            #expect(lamp.message(value: 1) == [0x90 + lamp.channel, lamp.number, 127])
            #expect(lamp.message(value: 0) == [0x90 + lamp.channel, lamp.number, 0])
        }
        try withDJinn(manual: index == 1) { _ in }
    }
    #expect(ControllerFactoryProfile.matching(["VOXOA S70"])?.rawValue != djinnNames[0])
}

@Test @MainActor func controllerCatalogueDJinnNormalTransportLoopsLoadAndGroupEntryRearmThroughTAPAliases() throws {
    for manual in [false, true] {
        try withDJinn(manual: manual) { input in
            var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
            for (ch, deck): (UInt8, DeckID) in [(0, .a), (2, .b)] {
                for (action, n): (ControllerAction, UInt8) in [
                    (.playA, 32), (.keylockA, 29), (.loopInA, 2), (.loopOutOrExitA, 3), (.reloopA, 4), (.loadA, 1),
                ] {
                    for off: UInt8 in [0x80, 0x90] {
                        events.removeAll(); djinnPacket([0x90 + ch, n + 63, 127, n + 63, 0], input);
                        #expect(events.isEmpty)
                        djinnPacket(
                            [
                                0x90 + ch, n, 127, n, 127, off + ch, n + 63, off == 0x80 ? 127 : 0, 0x90 + ch, n, 1, n,
                                0,
                            ], input)
                        #expect(events == Array(repeating: .init(action.assigned(to: deck), deck: deck), count: 2))
                    }
                }
                events.removeAll();
                djinnPacket([0x90 + ch, 5, 127, 5, 127, 0x80 + ch, 68, 127, 0x90 + ch, 5, 1, 5, 0], input)
                #expect(events == [.init(.openGroup), .init(.openGroup)])
            }
        }
    }
}

@Test @MainActor func controllerCatalogueDJinnHeldCueAndBendsKeepBothReleaseFormsAndThreeVelocities() throws {
    for manual in [false, true] {
        try withDJinn(manual: manual) { input in
            var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
            for (ch, deck): (UInt8, DeckID) in [(0, .a), (2, .b)] {
                for (action, n): (ControllerAction, UInt8) in [
                    (.cuePreviewA, 31), (.pitchBendDownA, 34), (.pitchBendUpA, 35),
                ] {
                    for velocity: UInt8 in [1, 64, 127] {
                        for off: UInt8 in [0x80, 0x90] {
                            events.removeAll();
                            djinnPacket(
                                [0x90 + ch, n, velocity, n, 127, off + ch, n + 63, off == 0x80 ? 127 : 0], input)
                            #expect(
                                events.map(\.1) == [Double(velocity) / 127, 0]
                                    && events.allSatisfy { $0.0 == .init(action.assigned(to: deck), deck: deck) })
                        }
                    }
                }
            }
        }
    }
}

@Test @MainActor func controllerCatalogueDJinnFourNormalHotCuesKeepShiftedClearsInactive() throws {
    try withDJinn { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        for (ch, deck): (UInt8, DeckID) in [(0, .a), (2, .b)] {
            for slot: UInt8 in 0..<4 {
                events.removeAll();
                djinnPacket(
                    [
                        0x90 + ch, 71 + slot, 127, 71 + slot, 0, 8 + slot, 127, 8 + slot, 127, 0x80 + ch, 71 + slot,
                        127, 0x90 + ch, 8 + slot, 1, 8 + slot, 0,
                    ], input)
                #expect(events.count == 2 && events.allSatisfy { $0.deck == deck && $0.action.hotcueSlot == Int(slot) })
            }
        }
    }
}

@Test @MainActor func controllerCatalogueDJinnOwnRelativeBrowserPairsKeepBothDecksAndTAPFamilies() throws {
    for manual in [false, true] {
        try withDJinn(manual: manual) { input in
            var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
            for ch: UInt8 in [0, 2] {
                for (action, n): (ControllerAction, UInt8) in [
                    (.browse, ch == 0 ? 22 : 38), (.browseGroups, ch == 0 ? 23 : 39),
                ] {
                    for number in [n, n + 63] {
                        events.removeAll(); djinnPacket([0xB0 + ch, number, 64], input); #expect(events.isEmpty)
                        djinnPacket([0xB0 + ch, number, 67], input); djinnPacket([0xB0 + ch, number, 49], input)
                        #expect(
                            events.map(\.0) == [.init(action), .init(action)] && events[0].1 > 0.5 && events[1].1 < 0.5)
                    }
                }
            }
        }
    }
}

@Test @MainActor func controllerCatalogueDJinnMode3TwentySixMixerRowsKeepExactOwnershipAndPickup() throws {
    let p = try #require(ControllerFactoryProfile.matching([djinnNames[1]]))
    let controls = p.bindings(source: 10).filter { $0.kind == .control && $0.mode == .absolute };
    #expect(controls.count == 26)
    try withDJinn(manual: true) { input in
        input.currentTargetValue = { _ in 0.5 }
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        for b in controls {
            events.removeAll(); djinnPacket([0xB0 + b.channel, b.number, 0], input); #expect(events.isEmpty)
            djinnPacket([0xB0 + b.channel, b.number, 64], input); djinnPacket([0xB0 + b.channel, b.number, 127], input)
            #expect(events.count == 2 && events.allSatisfy { $0.0 == b.target } && events.last?.1 == 1)
        }
        events.removeAll(); djinnPacket([0xB0, 16, 0], input, source: 11); #expect(events.isEmpty)
        djinnPacket([0xB0, 16, 64], input, source: 11);
        #expect(events.count == 1 && events[0].0 == .init(.levelA, deck: .a))
    }
    try withDJinn { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        for b in controls { djinnPacket([0xB0 + b.channel, b.number, 64], input) }
        #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueDJinnTAPCleanupRetiresOnlySourceOwnedDeckHolds() throws {
    for manual in [false, true] {
        try withDJinn(manual: manual) { input in
            var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
            djinnPacket([0x90, 31, 127, 0x92, 31, 127], input); djinnPacket([0x90, 31, 127], input, source: 11);
            events.removeAll()
            djinnPacket([0x90, 33, 127, 33, 0], input); #expect(events.isEmpty)
            djinnPacket([0x80, 94, 127], input, source: 11)
            #expect(events.map(\.0) == [.init(.cuePreviewA, deck: .a)] && events.map(\.1) == [0])
            events.removeAll(); djinnPacket([0x92, 33, 127, 33, 0], input)
            #expect(events.map(\.0) == [.init(.cuePreviewB, deck: .b)] && events.map(\.1) == [0])
        }
    }
}

@Test @MainActor func controllerCatalogueDJinnUnsupportedChannelsJogPitchCuePanAndFunctionsStayInactive() throws {
    for manual in [false, true] {
        try withDJinn(manual: manual) { input in
            var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
            for ch: UInt8 in [0, 2] {
                djinnPacket(
                    [
                        0x90 + ch, 6, 127, 7, 127, 12, 127, 13, 127, 14, 127, 15, 127, 16, 127, 17, 127, 18, 127, 19,
                        127, 20, 127, 21, 127, 22, 127, 23, 127, 24, 127, 25, 127, 26, 127, 27, 127, 28, 127, 30, 127,
                        39, 127, 36, 127, 37, 127, 38, 127, 0xB0 + ch, 24, 65, 40, 65, 87, 65, 103, 65, 0xE0 + ch, 0,
                        64,
                    ], input)
            }
            djinnPacket(
                [
                    0xB1, 50, 127, 52, 127, 53, 127, 54, 127, 113, 127, 115, 127, 116, 127, 117, 127, 0x91, 1, 127, 2,
                    127, 3, 127, 4, 127, 5, 127, 6, 127, 7, 127, 55, 127, 56, 127,
                ], input)
            for ch: UInt8 in 3..<16 { djinnPacket([0x90 + ch, 32, 127, 31, 127, 8, 127, 0xB0 + ch, 22, 65], input) }
            djinnPacket([0x90, 32, 127], input, source: 999)
            input.receive(.init(kind: .note, group: 1, channel: 0, number: 32, value: 127), source: 10);
            input.flushPendingActions()
            #expect(events.isEmpty)
        }
    }
}
