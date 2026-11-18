import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withIgnite(_ body: (ControllerMIDIConnection) throws -> Void) throws {
    let suite = "ignite-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences)
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id + 100), name: "RMX-IGNITE",
            identity: .init(id: id, device: UInt32(id), names: ["RMX-IGNITE"]))
    }
    input.reconcileFactoryProfiles()
    #expect(!input.isInputActive(10) && !input.isInputActive(11))
    let profile = try #require(ControllerFactoryProfile.matching(["RMX-IGNITE"]))
    for source: Int32 in [10, 11] { input.select(source); input.applyFactoryProfile(profile) }
    #expect(input.bindingCount == 44)
    try body(input)
}

@MainActor private func ignitePacket(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source)
    input.flushPendingActions()
}

@Test func controllerCatalogueIgniteKeepsManualNativeLayoutAndHardwareFXBoundaries() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["RMX-IGNITE"]))
    let definition = try #require(profile.definition)
    #expect(!profile.selectsAutomatically && definition.inputs.count == 22 && definition.role == "accessory")
    #expect(
        definition.outputs.isEmpty && definition.startup.isEmpty && definition.shutdown.isEmpty
            && definition.audioOutput == nil)
    #expect(definition.inputs.allSatisfy { $0.channel == 0 && ($0.targetDeck == nil || $0.targetDeck == .a) })
    for name in ["RMX-500", "RMX-1000"] { #expect(ControllerFactoryProfile.matching([name]) != profile) }
}

@Test @MainActor func controllerCatalogueIgnitePadsKeepExplicitNativeHotCuesAndLatchedLoopArguments() throws {
    try withIgnite { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
        for (number, action, argument): (UInt8, ControllerAction, Double?) in [
            (12, .hotcue1A, nil), (13, .hotcue2A, nil), (14, .hotcue3A, nil), (15, .hotcue4A, nil),
            (52, .toggleFixedLoopA, 0.125), (53, .toggleFixedLoopA, 0.25), (54, .toggleFixedLoopA, 0.5),
            (55, .toggleFixedLoopA, 1), (56, .toggleFixedLoopA, 2), (61, .toggleFixedLoopA, 4), (7, .syncA, nil),
        ] {
            for velocity: UInt8 in [1, 127] {
                for off: UInt8 in [0x80, 0x90] {
                    events.removeAll()
                    ignitePacket([0x90, number, velocity, number, velocity, off, number, off == 0x80 ? 127 : 0], input)
                    #expect(events.count == 1 && events.first?.0 == .init(action, deck: .a, argument: argument))
                }
            }
        }
        events.removeAll()
        ignitePacket(
            [0x90, 57, 127, 57, 0, 58, 127, 58, 0, 59, 127, 59, 0, 60, 127, 60, 0, 36, 127, 36, 0, 0xF8], input)
        ignitePacket([0x91, 12, 127, 12, 0], input)
        #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueIgniteKnobsAndBrowserKeepPickupDirectionAndSeparateAmounts() throws {
    try withIgnite { input in
        input.currentTargetValue = { _ in 0.5 }
        var events: [(ControllerAction, Double)] = []
        input.onAction = { action, value in if !action.isJog { events.append((action, value)) } }
        for (number, action): (UInt8, ControllerAction) in [
            (21, .lowA), (22, .midA), (23, .highA), (24, .levelA), (25, .filterKnobA), (29, .fxA),
        ] {
            events.removeAll()
            ignitePacket([0xB0, number, 0], input)
            #expect(events.isEmpty)
            ignitePacket([0xB0, number, 64], input)
            ignitePacket([0xB0, number, 127], input)
            #expect(events.map(\.0) == [action, action] && events.map(\.1) == [64.0 / 127, 1])
        }
        events.removeAll()
        ignitePacket([0xB0, 63, 1], input)
        ignitePacket([0xB0, 63, 127], input)
        #expect(events.map(\.0) == [.browse, .browse] && events.map(\.1) == [0.5 + 1.0 / 126, 0.5 - 1.0 / 126])
        events.removeAll()
        ignitePacket([0x90, 81, 127, 81, 0, 9, 127, 9, 0], input)
        #expect(events.map(\.0) == [.openGroup, .browsePreviousGroup])
    }
}

@Test @MainActor func controllerCatalogueIgniteHeldBendsKeepBothReleaseFormsAndOtherSources() throws {
    try withIgnite { input in
        var values: [Double] = []
        input.onAction = { action, value in if action == .pitchBendDownA { values.append(value) } }
        for off: UInt8 in [0x80, 0x90] {
            values.removeAll()
            ignitePacket([0x90, 3, 127, 3, 127, off, 3, off == 0x80 ? 127 : 0], input)
            #expect(values == [1, 0])
        }
        values.removeAll()
        ignitePacket([0x90, 3, 127], input)
        ignitePacket([0x90, 3, 127], input, source: 11)
        ignitePacket([0x80, 3, 127], input)
        #expect(values == [1])
        input.stop()
        #expect(values == [1, 0])
    }
}
