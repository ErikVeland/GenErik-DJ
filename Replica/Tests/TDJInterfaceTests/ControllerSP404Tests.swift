import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withSP404(_ body: (ControllerMIDIConnection) throws -> Void) throws {
    let suite = "sp404-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let name = "SP-404MKII"
    let input = ControllerMIDIConnection(preferences: preferences)
    input.sources = [
        .init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name])),
        .init(id: 11, reference: 101, name: name, identity: .init(id: 11, device: 2, names: [name])),
    ]
    input.reconcileFactoryProfiles()
    #expect(!input.isInputActive(10))
    let profile = try #require(ControllerFactoryProfile.matching([name]))
    #expect(!profile.selectsAutomatically)
    for source: Int32 in [10, 11] { input.select(source); input.applyFactoryProfile(profile) }
    try body(input)
}

@MainActor private func sp404Packet(_ bytes: [UInt8], to input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source)
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueSP404DirectStatesKeepEveryOnOffWithoutPickupOrTogglePriming() throws {
    try withSP404 { input in
        input.currentTargetValue = { _ in 1 }
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
        for (channel, deck) in DeckID.primary.enumerated() {
            for (number, raw): (UInt8, String) in [(22, "syncState"), (23, "cueState")] {
                events.removeAll()
                let action = try #require(ControllerAction(rawValue: raw + deck.rawValue.uppercased()))
                for value: UInt8 in [0, 0, 127, 127, 0, 127] {
                    sp404Packet([0xB0 + UInt8(channel), number, value], to: input)
                }
                #expect(events.map(\.1) == [0, 0, 1, 1, 0, 1])
                #expect(events.allSatisfy { $0.0 == .init(action, deck: deck) })
                #expect(action.isDirectState && !action.isButton && !action.isMomentary)
            }
        }
        #expect(!ControllerAction.syncStateA.isLearnable && !ControllerAction.syncStateB.isLearnable)
        #expect(ControllerAction.syncStateA.assigned(to: .d) == .syncStateB)
    }
}

@Test @MainActor func controllerCatalogueSP404LevelsAndCrossfaderKeepManufacturerChannelsAndPolarity() throws {
    try withSP404 { input in
        input.currentTargetValue = { _ in 0.5 }
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
        for channel: UInt8 in 0...1 {
            events.removeAll()
            sp404Packet([0xB0 + channel, 7, 64], to: input)
            sp404Packet([0xB0 + channel, 7, 127], to: input)
            #expect(events.map(\.1) == [64.0 / 127, 1])
            #expect(events.allSatisfy { $0.0.action == (channel == 0 ? .levelA : .levelB) })
        }
        events.removeAll()
        for value: UInt8 in [64, 0, 127] { sp404Packet([0xB0, 8, value], to: input) }
        #expect(events.map(\.1) == [64.0 / 127, 0, 1])
        #expect(events.allSatisfy { $0.0.action == .crossfader })
    }
}

@Test @MainActor func controllerCatalogueSP404BendsKeepFirstPressAndLastSourceRelease() throws {
    try withSP404 { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
        for channel: UInt8 in 0...1 {
            for number: UInt8 in [24, 25] {
                events.removeAll()
                let bytes: [UInt8] = [0xB0 + channel, number]
                sp404Packet(bytes + [127], to: input)
                sp404Packet(bytes + [127], to: input, source: 11)
                sp404Packet(bytes + [0], to: input)
                #expect(events.map(\.1) == [1])
                sp404Packet(bytes + [0], to: input, source: 11)
                #expect(events.map(\.1) == [1, 0])
                let action: ControllerAction = number == 24 ? .pitchBendUpA : .pitchBendDownA
                let deck: DeckID = channel == 0 ? .a : .b
                #expect(events.allSatisfy { $0.0 == .init(action.assigned(to: deck), deck: deck) })
            }
        }
    }
}

@Test @MainActor func controllerCatalogueSP404OtherModesAndStateValuedPlayStayInactive() throws {
    try withSP404 { input in
        var actions: [ControllerAction] = []
        input.onAction = { action, _ in if !action.isJog { actions.append(action) } }
        for channel: UInt8 in 0...2 {
            for number: UInt8 in [16, 17, 18, 19, 20, 21, 26, 27, 80, 81, 82, 83, 85, 86, 87, 88, 89, 90, 91] {
                sp404Packet([0xB0 + channel, number, 127, number, 0], to: input)
            }
            sp404Packet([0x90 + channel, 36, 127, 36, 0, 48, 127, 48, 0, 0xC0 + channel, 0], to: input)
        }
        sp404Packet([0xB1, 8, 127, 0xB2, 7, 127, 22, 127, 23, 127, 24, 127, 25, 127, 0xFA, 0xF8, 0xFC], to: input)
        #expect(actions.isEmpty)
    }
    let profile = try #require(ControllerFactoryProfile.matching(["SP-404MK2"]))
    #expect(profile.definition?.outputs.isEmpty == true && profile.definition?.startup.isEmpty == true)
    #expect(profile.definition?.shutdown.isEmpty == true && profile.definition?.audioOutput == nil)
    for name in ["SP-404", "SP-404SX", "SP-404A"] { #expect(ControllerFactoryProfile.matching([name]) != profile) }
}
