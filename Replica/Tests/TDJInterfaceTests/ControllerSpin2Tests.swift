import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withSpin2(_ name: String, _ body: (ControllerMIDIConnection) throws -> Void) throws {
    let suite = "spin2-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences)
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id + 100), name: name, identity: .init(id: id, device: UInt32(id), names: [name]))
    }
    input.reconcileFactoryProfiles()
    #expect(!input.isInputActive(10) && !input.isInputActive(11))
    let profile = try #require(ControllerFactoryProfile.matching([name]))
    for source: Int32 in [10, 11] { input.select(source); input.applyFactoryProfile(profile) }
    #expect(input.bindingCount == 60)
    try body(input)
}

@MainActor private func spin2Packet(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source)
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueSpin2SharedTransportRetainsEdgesAndBothCueReleaseForms() throws {
    for name in ["Vestax Spin2", "Casio XW-J1"] {
        try withSpin2(name) { input in
            var events: [(ControllerActionTarget, Double)] = []
            input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
            for (channel, deck) in DeckID.primary.enumerated() {
                for off: UInt8 in [0x80, 0x90] {
                    events.removeAll()
                    spin2Packet(
                        [0x90 + UInt8(channel), 47, 127, 47, 127, off + UInt8(channel), 47, off == 0x80 ? 127 : 0],
                        input)
                    #expect(events.map(\.1) == [1, 0] && events.allSatisfy { $0.0.deck == deck })
                }
                for (number, action): (UInt8, ControllerAction) in [
                    (46, .playA), (49, .syncA), (50, .cueA), (36, .loopA), (35, .loopDownA), (37, .loopUpA),
                    (43, .hotcue2A), (44, .hotcue3A),
                ] {
                    events.removeAll()
                    spin2Packet([0x90 + UInt8(channel), number, 127, number, 127, number, 0], input)
                    #expect(events.count == 1 && events.first?.0 == .init(action.assigned(to: deck), deck: deck))
                }
            }
        }
    }
}

@Test @MainActor func controllerCatalogueSpin2ShiftLoadsOnceAndModeReleasePreservesNewContact() throws {
    for name in ["Vestax Spin2", "Casio XW-J1"] {
        try withSpin2(name) { input in
            var events: [(ControllerActionTarget, Double)] = []
            input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
            spin2Packet([0x92, 35, 127, 35, 0, 36, 127, 36, 0, 32, 127], input)
            spin2Packet([0x90, 46, 127, 46, 0, 47, 127, 47, 0, 0x91, 43, 127, 43, 0], input)
            #expect(events.map(\.0.action) == [.browsePreviousGroup, .openGroup])
            spin2Packet([0x92, 35, 127, 35, 127, 35, 0, 36, 127, 36, 127, 36, 0], input)
            #expect(events.suffix(2).map(\.0.action) == [.loadA, .loadB])
            #expect(events.count == 4)
            spin2Packet([0x82, 32, 127, 0x90, 59, 127, 0x91, 59, 127], input)
            spin2Packet([0x90, 59, 127], input, source: 11)
            events.removeAll()
            spin2Packet([0x90, 45, 127], input)
            #expect(events.isEmpty)
            spin2Packet([0x80, 59, 127], input, source: 11)
            #expect(events.last?.0.deck == .a && events.last?.1 == 0)
            spin2Packet([0x90, 59, 127, 0x80, 45, 127], input)
            #expect(events.last?.0.deck == .a && events.last?.1 == 1)
            spin2Packet([0x92, 32, 127], input)
            #expect(events.suffix(2).allSatisfy { $0.1 == 0 })
        }
    }
}

@Test @MainActor func controllerCatalogueSpin2JogsContactsAndCrossfaderKeepDistinctChannels() throws {
    for name in ["Vestax Spin2", "Casio XW-J1"] {
        try withSpin2(name) { input in
            var jogs: [(ControllerActionTarget, Double)] = []
            input.onJogAction = { target, value in if case .relative(let count) = value { jogs.append((target, count)) }
            }
            for (index, deck) in DeckID.primary.enumerated() {
                jogs.removeAll()
                for value: UInt8 in [65, 63, 127, 0, 64] { spin2Packet([0xB2, 16 + UInt8(index), value], input) }
                #expect(jogs.map(\.1) == [1, -1, 63, -64])
                #expect(jogs.allSatisfy { $0.0.deck == deck && $0.0.argument == 375 })
            }
            var events: [(ControllerActionTarget, Double)] = []
            input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
            spin2Packet([0x90, 59, 127, 59, 64, 0x91, 59, 127, 0x81, 59, 127], input)
            #expect(events.map(\.1) == [1, 0, 1, 0])
            events.removeAll()
            input.currentTargetValue = { _ in 0.5 }
            spin2Packet([0xB4, 16, 64], input)
            spin2Packet([0xB4, 16, 127], input)
            #expect(events.map(\.0.action) == [.crossfader, .crossfader] && events.last?.1 == 1)
        }
    }
}

@Test @MainActor func controllerCatalogueSpin2ConflictingMixerUndefinedCueAndSiblingProtocolsStayInactive() throws {
    for name in ["Vestax Spin2", "Casio XW-J1"] {
        let profile = try #require(ControllerFactoryProfile.matching([name]))
        let definition = try #require(profile.definition)
        #expect(!profile.selectsAutomatically && definition.inputs.count == 30)
        #expect(
            definition.outputs.isEmpty && definition.startup.isEmpty && definition.shutdown.isEmpty
                && definition.audioOutput == nil)
        try withSpin2(name) { input in
            var actions: [ControllerAction] = []
            input.onAction = { action, _ in if !action.isJog { actions.append(action) } }
            for channel: UInt8 in 0...1 {
                spin2Packet(
                    [
                        0x90 + channel, 42, 127, 42, 0, 34, 127, 34, 0, 0xB0 + channel, 17, 127, 18, 127, 19, 127, 20,
                        127, 21, 127, 22, 127, 27, 127, 28, 127, 29, 127,
                    ], input)
            }
            #expect(actions.isEmpty)
        }
        for sibling in ["Spin", "Typhoon", "Casio XW-DJ1", "Spin2 clone"] {
            #expect(ControllerFactoryProfile.matching([sibling]) != profile)
        }
    }
}
