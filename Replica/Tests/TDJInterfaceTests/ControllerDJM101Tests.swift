import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withDJM101(_ body: (ControllerMIDIConnection) throws -> Void) rethrows {
    let suite = "djm101-core-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    let name = "DJ-Tech DJM-101"
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    #expect(input.isInputActive(10))
    try body(input)
}

@MainActor private func djm101Packet(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueDJM101SelectsOnlyItsOwnMIDIMixerCore() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["DJM-101"], automaticOnly: true))
    let data = try #require(profile.definition)
    #expect(data.role == "accessory")
    #expect(data.inputs.count == 16 && data.outputs.count == 2)
    #expect(!profile.hasAutomaticSplitOutput)
    #expect(ControllerFactoryProfile.matching(["DJ-Tech VTT-101"], automaticOnly: true) == nil)
    #expect(ControllerFactoryProfile.matching(["DJ-Tech MIX-101"], automaticOnly: true) != profile)
    #expect(ControllerFactoryProfile.matching(["DJ-Tech Mixer One"], automaticOnly: true) != profile)
    #expect(
        !data.inputs.contains { $0.action.isJog || [.playA, .playB, .cuePreviewA, .cuePreviewB].contains($0.action) })
}

@Test @MainActor func controllerCatalogueDJM101RetainsAsymmetricGainAndEQAddresses() {
    withDJM101 { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        djm101Packet([0xB0, 72, 1, 74, 2, 78, 3, 76, 4, 79, 5, 77, 6, 75, 7, 73, 8], to: input)
        let expected: [(ControllerAction, Double)] = [
            (.gainA, 1), (.highA, 2), (.midA, 3), (.lowA, 4), (.gainB, 5), (.highB, 6), (.midB, 7), (.lowB, 8),
        ]
        #expect(events.count == expected.count)
        for (action, raw) in expected { #expect(events.first { $0.0.action == action }?.1 == raw / 127) }
        events.removeAll()
        djm101Packet([0xB0, 65, 9, 66, 10, 64, 11, 67, 12, 68, 13, 69, 14], to: input)
        #expect(Set(events.map { $0.0.action }) == [.levelA, .levelB, .crossfader, .master, .cueMix, .monitor])
    }
}

@Test @MainActor func controllerCatalogueDJM101PickupAndPFLStaySeparateFromMeterSelection() {
    withDJM101 { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        input.currentTargetValue = { $0.action == .levelA ? 0.5 : nil }
        djm101Packet([0xB0, 65, 0], to: input)
        #expect(events.isEmpty)
        djm101Packet([0xB0, 65, 64], to: input)
        #expect(events.last?.0.action == .levelA)
        events.removeAll()
        djm101Packet([0x90, 33, 127, 33, 127, 33, 0, 33, 127, 34, 127], to: input)
        #expect(events.map { $0.0.action } == [.cueA, .cueA, .cueB])
        #expect(events.allSatisfy { $0.1 == 1 })
        events.removeAll()
        djm101Packet([0x90, 35, 127, 36, 127, 0x91, 33, 127, 0xB1, 65, 127], to: input)
        #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueDJM101ClearsBothMeterBanksAndPFLAtEachLifecycleBoundary() throws {
    let suite = "djm101-lifecycle-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    var packets: [[UInt8]] = []
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { bytes, _ in
            packets.append(bytes); return true
        })
    let name = "DJ-Tech DJM-101"
    let source = ControllerMIDIConnection.Source(
        id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))
    input.sources = [source]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    let profile = try #require(ControllerFactoryProfile.matching([name]))
    let expected: [[UInt8]] = [
        [0xB0, 80, 0], [0xB0, 81, 0], [0xB0, 82, 0], [0xB0, 83, 0], [0x90, 33, 0], [0x90, 34, 0],
    ]
    #expect(packets == expected)
    let pfl = try #require(profile.feedback(destination: 20).first { $0.action == .cueB })
    #expect(pfl.message(value: 1) == [0x90, 34, 127])
    #expect(pfl.message(value: 0) == [0x90, 34, 0])
    packets.removeAll()
    input.sources = []
    input.reconcileFactoryProfiles()
    #expect(packets == expected)
    packets.removeAll()
    input.sources = [source]
    input.reconcileFactoryProfiles()
    #expect(packets == expected)
}
