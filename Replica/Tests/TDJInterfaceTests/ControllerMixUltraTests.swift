import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withMixUltra(_ body: (ControllerMIDIConnection) throws -> Void) throws {
    let suite = "mix-ultra-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences)
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id + 100), name: "DJControl Mix Ultra",
            identity: .init(id: id, device: UInt32(id), names: ["DJControl Mix Ultra"]))
    }
    input.reconcileFactoryProfiles()
    #expect(input.isInputActive(10) && input.isInputActive(11))
    try body(input)
}

@MainActor private func ultraPacket(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source)
    input.flushPendingActions()
}

@Test func controllerCatalogueUltraKeepsIndependentIdentityAndSetReturnCueSemantics() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["DJControl Mix Ultra"], automaticOnly: true))
    let definition = try #require(profile.definition)
    #expect(
        definition.inputs.count == 48 && definition.outputs.isEmpty && definition.startup.isEmpty
            && definition.shutdown.isEmpty)
    #expect(definition.audioOutput == nil && definition.inputProtocol == nil)
    #expect(definition.inputs.filter { [.cueReturnA, .cueReturnB].contains($0.action) }.count == 2)
    #expect(
        !definition.inputs.contains { [.cuePreviewA, .cuePreviewB, .syncA, .syncB, .cueA, .cueB].contains($0.action) })
    for name in ["DJControl Mix", "DJControl Starlight", "DJControl Inpulse 200 MK2"] {
        #expect(ControllerFactoryProfile.matching([name]) != profile)
    }
}

@Test @MainActor func controllerCatalogueUltraCapturedButtonsAndBothHotCueBanksKeepWireAndReleaseForms() throws {
    try withMixUltra { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
        for channel: UInt8 in [1, 2] {
            let deck: DeckID = channel == 1 ? .a : .b
            for (number, action): (UInt8, ControllerAction) in [(7, .playA), (6, .cueReturnA), (13, .loadA)] {
                events.removeAll()
                ultraPacket([0x90 + channel, number, 127, number, 127, 0x80 + channel, number, 127], input)
                #expect(events.count == 1 && events.first?.0 == .init(action.assigned(to: deck), deck: deck))
            }
            for slot: UInt8 in 0..<8 {
                for velocity: UInt8 in [1, 127] {
                    for off: UInt8 in [0x80, 0x90] {
                        events.removeAll()
                        ultraPacket(
                            [
                                0x95 + channel, slot, velocity, slot, velocity, off + 5 + channel, slot,
                                off == 0x80 ? 127 : 0,
                            ], input)
                        #expect(
                            events.count == 1 && events.first?.0.action.hotcueSlot == Int(slot)
                                && events.first?.0.deck == deck)
                    }
                }
            }
        }
    }
}

@Test @MainActor func controllerCatalogueUltraGlobalShiftGuardKeepsTwoKeysAndSourcesIndependent() throws {
    try withMixUltra { input in
        var touches: [Double] = [], plays: [ControllerAction] = []
        input.onAction = { action, value in
            if action == .jogTouchA { touches.append(value) }
            if action == .playA { plays.append(action) }
        }
        ultraPacket([0x91, 8, 127], input)
        ultraPacket([0x91, 8, 127], input, source: 11)
        ultraPacket([0x91, 4, 127, 0x92, 4, 127], input)
        #expect(touches == [1])
        ultraPacket([0x81, 8, 127], input, source: 11)
        #expect(touches == [1, 0])
        ultraPacket([0x81, 4, 127, 0x91, 7, 127, 7, 0], input)
        #expect(plays.isEmpty)
        ultraPacket([0x91, 7, 127, 7, 0], input, source: 11)
        #expect(plays == [.playA])
        plays.removeAll()
        ultraPacket([0x82, 4, 127, 0x91, 7, 127, 7, 0], input)
        #expect(plays == [.playA])
    }
}

@Test @MainActor func controllerCatalogueUltraTopJogRequiresContactAndModeReleasePreservesNewTouch() throws {
    try withMixUltra { input in
        var counts: [Double] = [], touches: [Double] = []
        input.onJogAction = { _, value in if case .relative(let count) = value { counts.append(count) } }
        input.onAction = { action, value in if action == .jogTouchA { touches.append(value) } }
        ultraPacket([0xB1, 10, 1], input)
        #expect(counts.isEmpty)
        ultraPacket([0x91, 8, 127, 0xB1, 10, 1], input)
        ultraPacket([0xB1, 10, 127], input)
        #expect(counts == [1, -1])
        ultraPacket([0x91, 15, 127, 8, 127, 0x81, 15, 127], input)
        #expect(touches == [1, 0, 1])
        ultraPacket([0x91, 4, 127, 0x94, 8, 0, 0xB4, 10, 1], input)
        #expect(touches == [1, 0, 1, 0])
        #expect(counts == [1, -1])
        ultraPacket([0x91, 4, 0, 0xB1, 9, 1], input)
        #expect(counts.last == 1)
    }
}

@Test @MainActor func controllerCatalogueUltraPairsOnlyQualifiedFadersAndKeepsAbsoluteKnobMSBs() throws {
    try withMixUltra { input in
        input.currentTargetValue = { _ in 0.5 }
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
        for channel: UInt8 in [1, 2] {
            let deck: DeckID = channel == 1 ? .a : .b
            for (number, action): (UInt8, ControllerAction) in [(0, .levelA), (8, .tempoA)] {
                events.removeAll()
                ultraPacket([0xB0 + channel, number + 32, 127], input)
                #expect(events.isEmpty)
                ultraPacket([0xB0 + channel, number, 64], input)
                ultraPacket([0xB0 + channel, number, 127, number + 32, 127], input)
                #expect(events.first?.1 == 8192.0 / 16383 && events.last?.1 == 1)
                #expect(events.allSatisfy { $0.0 == .init(action.assigned(to: deck), deck: deck) })
            }
            for (number, action): (UInt8, ControllerAction) in [(1, .filterKnobA), (2, .lowA), (3, .midA), (4, .highA)]
            {
                events.removeAll()
                ultraPacket([0xB0 + channel, number + 32, 127], input)
                #expect(events.isEmpty)
                ultraPacket([0xB0 + channel, number, 64], input)
                ultraPacket([0xB0 + channel, number, 127], input)
                #expect(events.map(\.1) == [64.0 / 127, 1])
                #expect(events.allSatisfy { $0.0 == .init(action.assigned(to: deck), deck: deck) })
            }
        }
        events.removeAll()
        ultraPacket([0xB0, 0, 64, 32, 0], input)
        ultraPacket([0xB0, 0, 127, 32, 127], input)
        #expect(events.first?.0.action == .crossfader && events.last?.1 == 1)
        events.removeAll()
        ultraPacket([0xB0, 3, 64], input)
        #expect(events.first?.0.action == .master && events.first?.1 == 64.0 / 127)
    }
}

@Test @MainActor func controllerCatalogueUltraBrowserAndInactiveStateCopiesDoNotInventSyncOrPFL() throws {
    try withMixUltra { input in
        var events: [(ControllerAction, Double)] = []
        input.onAction = { action, value in if !action.isJog { events.append((action, value)) } }
        ultraPacket([0xB0, 1, 1], input)
        ultraPacket([0xB0, 1, 127], input)
        #expect(events.map(\.0) == [.browse, .browse] && events.map(\.1) == [0.5 + 1.0 / 126, 0.5 - 1.0 / 126])
        events.removeAll()
        ultraPacket([0x90, 0, 127, 0, 0], input)
        #expect(events.map(\.0) == [.openGroup])
        events.removeAll()
        for channel: UInt8 in [1, 2, 4, 5] { ultraPacket([0x90 + channel, 5, 0, 5, 127, 5, 0, 12, 127, 12, 0], input) }
        for channel: UInt8 in [6, 7] {
            ultraPacket([0x90 + channel, 8, 127, 8, 0, 16, 127, 16, 0, 32, 127, 32, 0], input)
        }
        #expect(events.isEmpty)
    }
}
