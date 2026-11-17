import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func attachMixerOne(_ input: ControllerMIDIConnection) {
    let name = "MIXER1"
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
}

@MainActor private func mixerOnePacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@MainActor private func withMixerOne(_ body: (ControllerMIDIConnection) throws -> Void) rethrows {
    let suite = "mixer-one-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences, factoryPacketSender: { _, _ in true }, deckAvailability: { DeckID.allCases })
    attachMixerOne(input)
    try body(input)
}

@Test @MainActor func controllerCatalogueMixerOneHasExplicitFourTargetSideAddresses() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["MIXER1"], automaticOnly: true))
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 32 && data.outputs.count == 4)
    #expect(data.startup.count == 20 && data.shutdown.count == 12)
    #expect(!profile.hasAutomaticSplitOutput)
    withMixerOne { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        mixerOnePacket([0xB5, 20, 127, 0xB6, 25, 127, 0xB7, 20, 127, 0xB8, 25, 127], to: input)
        #expect(
            Set(events.map { $0.0 }) == [
                .init(.levelA, deck: .a), .init(.levelB, deck: .b), .init(.levelA, deck: .c), .init(.levelB, deck: .d),
            ])
        events.removeAll()
        mixerOnePacket([0x95, 7, 127, 0x96, 3, 127, 0x97, 7, 127, 0x98, 3, 127], to: input)
        #expect(
            events.map { $0.0 } == [
                .init(.cueA, deck: .a), .init(.cueB, deck: .b), .init(.cueA, deck: .c), .init(.cueB, deck: .d),
            ])
        events.removeAll()
        mixerOnePacket([0xB5, 21, 127, 0xB6, 20, 127, 0x95, 5, 127, 8, 127, 0xB5, 14, 127], to: input)
        #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueMixerOneDuplicatedGlobalStripKeepsOneNativeTarget() {
    withMixerOne { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        mixerOnePacket([0xB5, 11, 0], to: input)
        mixerOnePacket([0xB7, 11, 127], to: input)
        #expect(events.map { $0.0 } == [.init(.master), .init(.master)] && events.map { $0.1 } == [0, 1])
    }
}

@Test @MainActor func controllerCatalogueMixerOneClearReportRearmsAcquiredDeckPickup() {
    withMixerOne { input in
        var current = 0.5
        var values: [Double] = []
        input.currentTargetValue = { $0.action == .levelA && $0.deck == .a ? current : nil }
        input.onTargetAction = { target, value in
            if target == .init(.levelA, deck: .a) { current = value; values.append(value) }
        }
        mixerOnePacket([0xB5, 20, 0], to: input)
        #expect(values.isEmpty)
        mixerOnePacket([0xB5, 20, 64], to: input)
        mixerOnePacket([0xB5, 20, 127], to: input)
        #expect(values.count == 2 && current == 1)
        mixerOnePacket([0x95, 10, 127, 0xB5, 20, 0], to: input)
        #expect(values.count == 2 && current == 1)
        mixerOnePacket([0xB5, 20, 127], to: input)
        #expect(values.count == 3)
    }
}

@Test @MainActor func controllerCatalogueMixerOneKeepsUnavailableCAndDInactive() {
    let suite = "mixer-one-two-deck-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences, factoryPacketSender: { _, _ in true }, deckAvailability: { [.a, .b] })
    attachMixerOne(input)
    var targets: [ControllerActionTarget] = []
    input.onTargetAction = { target, _ in targets.append(target) }
    mixerOnePacket([0xB7, 20, 127, 0xB8, 25, 127, 0x97, 7, 127, 0x98, 3, 127], to: input)
    #expect(targets.isEmpty)
}

@Test @MainActor func controllerCatalogueMixerOneLifecycleClearsOnlyKnownIndicatorsWithinBudget() throws {
    let suite = "mixer-one-lights-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    var packets: [[UInt8]] = []
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { bytes, _ in
            packets.append(bytes); return true
        })
    attachMixerOne(input)
    let profile = try #require(ControllerFactoryProfile.matching(["MIXER1"]))
    let data = try #require(profile.definition)
    #expect(packets == data.startup)
    input.sources = []
    input.reconcileFactoryProfiles()
    #expect(packets == data.startup + data.shutdown && packets.count == 32)
    for output in profile.feedback(destination: 20) {
        #expect(output.message(value: 1) == [0x90 + output.channel, output.number, 127])
        #expect(output.message(value: 0) == [0x90 + output.channel, output.number, 0])
    }
}
