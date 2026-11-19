import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withAIRPlus(_ body: (ControllerMIDIConnection) throws -> Void) throws {
    let suite = "air-plus-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id + 100), name: "DJControl AIR+",
            identity: .init(id: id, device: UInt32(id), names: ["DJControl AIR+"]))
    }
    input.reconcileFactoryProfiles()
    #expect(input.isInputActive(10) && input.isInputActive(11))
    try body(input)
}

@MainActor private func airPlusPacket(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source)
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueAIRPlusKeepsTransportAndVelocityHotCuesIndependent() throws {
    try withAIRPlus { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
        for (side, deck) in DeckID.primary.enumerated() {
            let base = UInt8(side * 27)
            for (number, action): (UInt8, ControllerAction) in [(17, .playA), (19, .syncA), (25, .cueA), (26, .loadA)] {
                events.removeAll()
                airPlusPacket([0x90, number + base, 127, number + base, 127, 0x80, number + base, 127], input)
                #expect(events.count == 1 && events.first?.0 == .init(action.assigned(to: deck), deck: deck))
            }
            for off: UInt8 in [0x80, 0x90] {
                events.removeAll()
                airPlusPacket([0x90, 18 + base, 127, 18 + base, 127, off, 18 + base, off == 0x80 ? 127 : 0], input)
                #expect(events.map(\.1) == [1, 0])
                #expect(
                    events.allSatisfy { $0.0 == .init(ControllerAction.cuePreviewA.assigned(to: deck), deck: deck) })
                for slot: UInt8 in 0..<4 {
                    events.removeAll()
                    let number = 68 + UInt8(side * 8) + slot
                    airPlusPacket([0x90, number, 1, number, 127, off, number, off == 0x80 ? 127 : 0], input)
                    #expect(
                        events.count == 1 && events.first?.0.action.hotcueSlot == Int(slot)
                            && events.first?.0.deck == deck)
                }
            }
        }
    }
}

@Test @MainActor func controllerCatalogueAIRPlusScratchShiftStateAndBankReleaseKeepOwnedContacts() throws {
    try withAIRPlus { input in
        var touches: [Double] = [], plays: [ControllerAction] = [], counts: [Double] = []
        input.onAction = { action, value in
            if action == .jogTouchA { touches.append(value) }
            if [.playA, .playB].contains(action) { plays.append(action) }
        }
        input.onJogAction = { _, value in if case .relative(let count) = value { counts.append(count) } }
        airPlusPacket([0xB0, 104, 1], input)
        #expect(counts.isEmpty)
        airPlusPacket([0x90, 27, 1, 0xB0, 104, 1], input)
        #expect(counts.isEmpty)
        airPlusPacket([0x90, 27, 127, 0xB0, 104, 1], input)
        airPlusPacket([0xB0, 104, 63], input)
        airPlusPacket([0xB0, 104, 64], input)
        airPlusPacket([0xB0, 104, 127], input)
        #expect(counts == [1, 63, -64, -1])
        airPlusPacket([0x90, 27, 127], input, source: 11)
        airPlusPacket([0x90, 20, 127, 84, 127], input)
        #expect(touches == [1])
        airPlusPacket([0x80, 27, 127], input, source: 11)
        #expect(touches == [1, 0])
        airPlusPacket([0x90, 20, 0, 17, 127, 17, 0, 44, 127, 44, 0], input)
        #expect(plays == [.playB])
        airPlusPacket([0x90, 17, 127, 17, 0], input, source: 11)
        #expect(plays == [.playB, .playA])
        airPlusPacket([0x90, 84, 0, 17, 127, 17, 0, 27, 127, 21, 127, 27, 127, 0x80, 21, 127], input)
        #expect(plays == [.playB, .playA, .playA])
        #expect(touches == [1, 0, 1, 0, 1])
        airPlusPacket([0x90, 57, 127, 57, 0], input)
        #expect(touches == [1, 0, 1, 0, 1, 0])
        counts.removeAll()
        airPlusPacket([0xB0, 104, 1, 102, 127], input)
        #expect(counts == [-1])
    }
}

@Test @MainActor func controllerCatalogueAIRPlusPairsFactoryMixerAndPitchWithCorroboratedKnobPolarity() throws {
    try withAIRPlus { input in
        input.currentTargetValue = { _ in 0.5 }
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
        for (side, deck) in DeckID.primary.enumerated() {
            for (number, action): (UInt8, ControllerAction) in [
                (UInt8(4 + side * 6), .tempoA), (UInt8(2 + side * 7), .levelA), (UInt8(5 + side * 6), .highA),
                (UInt8(6 + side * 6), .midA), (UInt8(7 + side * 6), .lowA), (UInt8(8 + side * 6), .gainA),
            ] {
                events.removeAll()
                airPlusPacket([0xB0, number + 32, 127], input)
                #expect(events.isEmpty)
                airPlusPacket([0xB0, number, 64], input)
                airPlusPacket([0xB0, number, 127, number + 32, 127], input)
                #expect(events.first?.1 == (action == .tempoA ? 1 - 8192.0 / 16383 : 8192.0 / 16383))
                #expect(events.last?.1 == (action == .tempoA ? 0 : 1))
                #expect(events.allSatisfy { $0.0 == .init(action.assigned(to: deck), deck: deck) })
            }
        }
        events.removeAll()
        airPlusPacket([0xB0, 1, 64, 33, 0], input)
        airPlusPacket([0xB0, 1, 127, 33, 127], input)
        #expect(events.first?.0.action == .crossfader && events.last?.1 == 1)
        events.removeAll()
        airPlusPacket([0xB0, 106, 1], input)
        airPlusPacket([0xB0, 106, 127], input)
        #expect(events.map(\.1) == [0.5 + 1.0 / 126, 0.5 - 1.0 / 126])
        airPlusPacket([0x90, 67, 127, 67, 0], input)
        #expect(events.last?.0.action == .openGroup)
    }
}

@Test @MainActor func controllerCatalogueAIRPlusOwnsOnlyQualifiedFeedbackAndNeverQueriesAllControls() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["DJControl AIR+"], automaticOnly: true))
    let definition = try #require(profile.definition)
    #expect(definition.inputs.count == 47 && definition.outputs.count == 16 && profile.hasAutomaticSplitOutput)
    #expect(definition.startup.isEmpty && definition.shutdown.count == 16)
    for output in profile.feedback(destination: 20) {
        #expect(output.message(value: 1) == [0x90, output.number, 127])
        #expect(output.message(value: 0) == [0x90, output.number, 0])
    }
    #expect(definition.shutdown.allSatisfy { $0.count == 3 && $0[0] == 0x90 && $0[2] == 0 })
    for name in ["DJControl AIR", "DJControl Mix", "DJControl Mix Ultra"] {
        #expect(ControllerFactoryProfile.matching([name]) != profile)
    }
    try withAIRPlus { input in
        var actions: [ControllerAction] = []
        input.onAction = { action, _ in if !action.isJog { actions.append(action) } }
        for number: UInt8 in Array(1...16) + Array(28...43) + [
            23, 50, 55, 56, 57, 64, 65, 66, 72, 73, 74, 75, 80, 81, 82, 83, 85, 86, 88, 89,
        ] {
            airPlusPacket([0x90, number, 127, number, 0], input)
        }
        for number: UInt8 in [15, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 127] {
            airPlusPacket([0xB0, number, 127, number, 0], input)
        }
        airPlusPacket([0x91, 17, 127, 17, 0, 0xB1, 102, 1], input)
        #expect(actions.isEmpty)
    }
}
