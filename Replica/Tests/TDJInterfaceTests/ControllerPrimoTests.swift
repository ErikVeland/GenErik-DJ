import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withPrimo(_ body: (ControllerMIDIConnection) throws -> Void) throws {
    let suite = "primo-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, deckAvailability: { DeckID.allCases })
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id + 100), name: "Mixars PRIMO",
            identity: .init(id: id, device: UInt32(id), names: ["Mixars PRIMO"]))
    }
    input.reconcileFactoryProfiles()
    #expect(!input.isInputActive(10) && !input.isInputActive(11))
    let profile = try #require(ControllerFactoryProfile.matching(["Mixars PRIMO"]))
    for source: Int32 in [10, 11] { input.select(source); input.applyFactoryProfile(profile) }
    #expect(input.bindingCount == 126)
    try body(input)
}

@MainActor private func primoPacket(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source)
    input.flushPendingActions()
}

@Test @MainActor func controllerCataloguePrimoSeparatesNormalTransportAndOtherFunctionLoopChannels() throws {
    try withPrimo { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
        for (channel, deck) in DeckID.allCases.enumerated() {
            for (number, action): (UInt8, ControllerAction) in [(0, .playA), (2, .syncA), (13, .keylockA)] {
                events.removeAll()
                primoPacket([0x90 + UInt8(channel), number, 127, number, 127, number, 0], input)
                #expect(events.count == 1 && events.first?.0 == .init(action.assigned(to: deck), deck: deck))
            }
            for (number, action): (UInt8, ControllerAction) in [(50, .loopA), (52, .loopDownA), (53, .loopUpA)] {
                events.removeAll()
                primoPacket([0x94 + UInt8(channel), number, 127, number, 127, number, 0], input)
                #expect(events.count == 1 && events.first?.0 == .init(action.assigned(to: deck), deck: deck))
            }
            for off: UInt8 in [0x80, 0x90] {
                events.removeAll()
                primoPacket(
                    [0x90 + UInt8(channel), 12, 127, 12, 127, off + UInt8(channel), 12, off == 0x80 ? 127 : 0], input)
                #expect(events.map(\.1) == [1, 0] && events.allSatisfy { $0.0.deck == deck })
            }
        }
    }
}

@Test @MainActor func controllerCataloguePrimoSourceReportsAndGlobalShiftRetireOwnedBends() throws {
    try withPrimo { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
        primoPacket([0x90, 12, 127, 0x92, 12, 127, 0x91, 12, 127], input)
        primoPacket([0x90, 12, 127], input, source: 11)
        primoPacket([0xB2, 34, 0], input)
        #expect(events.map(\.0.deck) == [.a, .c, .b, .c])
        primoPacket([0x80, 12, 127], input, source: 11)
        #expect(events.last?.0.deck == .a && events.last?.1 == 0)
        primoPacket([0xB3, 50, 127], input)
        #expect(events.last?.0.deck == .b && events.last?.1 == 0)
        primoPacket([0x90, 12, 127, 0x9F, 0, 127], input)
        #expect(events.last?.0.deck == .a && events.last?.1 == 0)
        events.removeAll()
        primoPacket([0x90, 0, 127, 0, 0, 0x94, 50, 127, 50, 0, 0x9F, 6, 127, 6, 0, 7, 127, 7, 127, 7, 0], input)
        #expect(events.count == 1 && events.first?.0.action == .browsePreviousGroup)
        primoPacket([0x8F, 0, 127, 0x9F, 6, 127, 6, 0], input)
        #expect(events.last?.0.action == .openGroup)
    }
}

@Test @MainActor func controllerCataloguePrimoMixerUsesNChannelsWhileGlobalSoundUsesChannel16() throws {
    try withPrimo { input in
        input.currentTargetValue = { _ in 0.5 }
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
        for (channel, deck) in DeckID.allCases.enumerated() {
            for (number, action): (UInt8, ControllerAction) in [
                (22, .gainA), (23, .highA), (24, .midA), (25, .lowA), (26, .filterKnobA), (28, .levelA), (9, .tempoA),
            ] {
                events.removeAll()
                primoPacket([0xB0 + UInt8(channel), number, 64], input)
                primoPacket([0xB0 + UInt8(channel), number, 127], input)
                #expect(events.count == 2 && events.allSatisfy { $0.0 == .init(action.assigned(to: deck), deck: deck) })
                #expect(events.last?.1 == (action == .tempoA ? 0 : 1))
            }
        }
        for (number, action): (UInt8, ControllerAction) in [
            (8, .crossfader), (10, .master), (12, .monitor), (13, .cueMix),
        ] {
            events.removeAll()
            primoPacket([0xBF, number, 64], input)
            primoPacket([0xBF, number, 127], input)
            #expect(events.map(\.0.action) == [action, action] && events.last?.1 == 1)
        }
    }
}

@Test @MainActor func controllerCataloguePrimoConflictingNotesAndUnspecifiedEncodersStayInactive() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["Mixars PRIMO"]))
    let definition = try #require(profile.definition)
    #expect(!profile.selectsAutomatically && definition.inputs.count == 63)
    #expect(
        definition.outputs.isEmpty && definition.startup.isEmpty && definition.shutdown.isEmpty
            && definition.audioOutput == nil)
    try withPrimo { input in
        var actions: [ControllerAction] = []
        input.onAction = { action, _ in if !action.isJog { actions.append(action) } }
        for channel: UInt8 in 0...3 {
            for number: UInt8 in [
                1, 7, 9, 11, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 35, 39, 40, 41, 42, 43, 49,
            ] {
                primoPacket([0x90 + channel, number, 127, number, 0], input)
            }
            primoPacket([0xB0 + channel, 6, 65, 41, 127, 43, 127, 0x90 + channel, 6, 127, 6, 0], input)
        }
        primoPacket([0xBF, 0, 1, 0, 127, 1, 1, 1, 127, 0x9F, 4, 127, 4, 0, 5, 127, 5, 0], input)
        #expect(actions.isEmpty)
    }
}
